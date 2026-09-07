--!strict

-- Bridge to the hosted claim service that actually signs / mints on-chain.
-- Roblox must NEVER hold MEO404_MINTER_PRIVATE_KEY.
--
-- Mock mode records a fake tx hash so Studio playtests work.
-- Http mode POSTs to Config.Nft404.ClaimApiUrl (claim) and sibling /v1/siwe/* routes.

local HttpService = game:GetService("HttpService")

local Config = require(script.Parent.Parent.Config)
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

export type ClaimResponse = {
	ok: boolean,
	txHash: string?,
	error: string?,
}

export type ChallengeResponse = {
	ok: boolean,
	nonce: string?,
	message: string?,
	expiresAt: number?,
	error: string?,
}

export type VerifyResponse = {
	ok: boolean,
	address: string?,
	error: string?,
}

local ClaimApi = {}

local function snippet(body: string): string
	local trimmed = string.gsub(body, "%s+", " ")
	if #trimmed > 120 then
		return string.sub(trimmed, 1, 117) .. "..."
	end
	return trimmed
end

local function isoUtc(unix: number): string
	return os.date("!%Y-%m-%dT%H:%M:%SZ", unix) :: string
end

local function apiRoot(): string
	local url = Config.Nft404.ClaimApiUrl
	url = string.gsub(url, "/+$", "")
	url = string.gsub(url, "/v1/meo404$", "")
	return url
end

local function parseSiweAddress(message: string): string?
	for line in string.gmatch(message, "[^\n]+") do
		local trimmed = string.gsub(line, "%s+", "")
		if string.match(trimmed, "^0[xX][0-9a-fA-F]+$") and #trimmed == 42 then
			return trimmed
		end
	end
	return nil
end

local function parseSiweNonce(message: string): string?
	local nonce = string.match(message, "Nonce:%s*(%S+)")
	return nonce
end

local function buildSiweMessage(userId: number, address: string, nonce: string, issuedAt: number, expiresAt: number): string
	local domain = Config.Nft404.SiweDomain
	local uri = Config.Nft404.SiweUri
	local chainId = Config.Nft404.SiweChainId
	return table.concat({
		`{domain} wants you to sign in with your Ethereum account:`,
		address,
		"",
		`Link this wallet to Roblox user {userId} for Meo 404. This is not a transaction.`,
		"",
		`URI: {uri}`,
		"Version: 1",
		`Chain ID: {chainId}`,
		`Nonce: {nonce}`,
		`Issued At: {isoUtc(issuedAt)}`,
		`Expiration Time: {isoUtc(expiresAt)}`,
	}, "\n")
end

local function postJson(url: string, payload: any): (boolean, any, string?)
	if Config.Nft404.ClaimApiSecret == "" then
		return false, nil, "Claim API secret missing. Use a shared Bearer secret — never a minter private key."
	end
	local body = HttpService:JSONEncode(payload)
	local ok, response = pcall(function()
		return HttpService:RequestAsync({
			Url = url,
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json",
				["Authorization"] = `Bearer {Config.Nft404.ClaimApiSecret}`,
			},
			Body = body,
		})
	end)
	if not ok then
		return false, nil, `Claim API request error: {snippet(tostring(response))}`
	end
	if typeof(response) ~= "table" then
		return false, nil, "Claim API returned a non-table response."
	end
	local http = response :: any
	if http.Success ~= true then
		local status = if typeof(http.StatusCode) == "number" then tostring(http.StatusCode) else "?"
		local detail = if typeof(http.Body) == "string" and http.Body ~= "" then snippet(http.Body) else (http.StatusMessage or "no body")
		return false, nil, `Claim API HTTP {status}: {detail}`
	end
	local decodedOk, decoded = pcall(function()
		return HttpService:JSONDecode(http.Body)
	end)
	if not decodedOk or typeof(decoded) ~= "table" then
		local preview = if typeof(http.Body) == "string" then snippet(http.Body) else "unreadable body"
		return false, nil, `Claim API returned no JSON ({preview})`
	end
	return true, decoded, nil
end

function ClaimApi.requestChallenge(userId: number, address: string): ChallengeResponse
	if Config.Nft404.Provider == "http" then
		return ClaimApi._httpChallenge(userId, address)
	end
	return ClaimApi._mockChallenge(userId, address)
end

function ClaimApi.verifySiwe(message: string, signature: string, expectedNonce: string): VerifyResponse
	if Config.Nft404.Provider == "http" then
		return ClaimApi._httpVerify(message, signature)
	end
	return ClaimApi._mockVerify(message, signature, expectedNonce)
end

function ClaimApi._mockChallenge(userId: number, address: string): ChallengeResponse
	local ttl = Config.Nft404.SiweNonceTtlSec
	if typeof(ttl) ~= "number" or ttl < 30 then
		ttl = 600
	end
	local issuedAt = os.time()
	local expiresAt = issuedAt + ttl
	local nonce = string.lower(string.gsub(HttpService:GenerateGUID(false), "%-", ""))
	nonce = string.sub(nonce, 1, 16)
	return {
		ok = true,
		nonce = nonce,
		message = buildSiweMessage(userId, address, nonce, issuedAt, expiresAt),
		expiresAt = expiresAt,
	}
end

function ClaimApi._mockVerify(message: string, signature: string, expectedNonce: string): VerifyResponse
	local address = parseSiweAddress(message)
	if not address then
		return { ok = false, error = "SIWE message is missing a 0x address." }
	end
	local nonce = parseSiweNonce(message)
	if not nonce or nonce ~= expectedNonce then
		return { ok = false, error = "SIWE nonce does not match the pending challenge." }
	end
	if not Config.Nft404.AllowSiweMockBypass then
		return {
			ok = false,
			error = "Mock SIWE cannot recover ECDSA. Enable AllowSiweMockBypass (Studio) or set Provider=http.",
		}
	end
	local trimmed = string.gsub(signature, "%s+", "")
	local mockSig = string.lower(trimmed) == "studio-bypass"
		or string.match(trimmed, "^0[xX][0-9a-fA-F]+$") ~= nil and #trimmed == 132
	if not mockSig then
		return {
			ok = false,
			error = "Studio verify: paste studio-bypass or a 132-char 0x signature (65-byte stub).",
		}
	end
	return { ok = true, address = address }
end

function ClaimApi._httpChallenge(userId: number, address: string): ChallengeResponse
	local root = apiRoot()
	if root == "" then
		return {
			ok = false,
			error = "Claim API URL is empty. Set Nft404.ClaimApiUrl or keep Provider=mock.",
		}
	end
	local ok, decoded, err = postJson(`{root}/v1/siwe/challenge`, {
		robloxUserId = userId,
		address = address,
	})
	if not ok then
		return { ok = false, error = err }
	end
	local row = decoded :: any
	if typeof(row.nonce) == "string" and typeof(row.message) == "string" then
		local expiresAt = if typeof(row.expiresAt) == "number" then row.expiresAt else os.time() + 600
		return {
			ok = true,
			nonce = row.nonce,
			message = row.message,
			expiresAt = expiresAt,
		}
	end
	return { ok = false, error = "SIWE challenge response missing nonce/message." }
end

function ClaimApi._httpVerify(message: string, signature: string): VerifyResponse
	local root = apiRoot()
	if root == "" then
		return {
			ok = false,
			error = "Claim API URL is empty. Set Nft404.ClaimApiUrl or keep Provider=mock.",
		}
	end
	local ok, decoded, err = postJson(`{root}/v1/siwe/verify`, {
		message = message,
		signature = signature,
	})
	if not ok then
		return { ok = false, error = err }
	end
	local row = decoded :: any
	if typeof(row.address) == "string" then
		return { ok = true, address = row.address }
	end
	return { ok = false, error = "SIWE verify response missing recovered address." }
end

function ClaimApi.submit(entitlement: Types.Entitlement, wallet: string): ClaimResponse
	if Config.Nft404.Provider == "http" then
		return ClaimApi._http(entitlement, wallet)
	end
	return ClaimApi._mock(entitlement, wallet)
end

function ClaimApi._mock(entitlement: Types.Entitlement, _wallet: string): ClaimResponse
	-- Deterministic fake hash so Studio retries look idempotent.
	local seed = string.lower((string.gsub(entitlement.purchaseId, "[^%w]", "")))
	if seed == "" then
		seed = "purchase"
	end
	if #seed > 56 then
		seed = string.sub(seed, 1, 56)
	end
	return {
		ok = true,
		txHash = `0xMOCK{string.rep("0", 56 - #seed)}{seed}`,
	}
end

function ClaimApi._http(entitlement: Types.Entitlement, wallet: string): ClaimResponse
	if Config.Nft404.ClaimApiUrl == "" then
		return {
			ok = false,
			error = "Claim API URL is empty. Set Nft404.ClaimApiUrl or keep Provider=mock. Do not put a chain key in the place.",
		}
	end
	local ok, decoded, err = postJson(Config.Nft404.ClaimApiUrl, {
		robloxUserId = entitlement.userId,
		purchaseId = entitlement.purchaseId,
		productId = entitlement.productId,
		nonce = entitlement.nonce,
		wallet = wallet,
	})
	if not ok then
		return { ok = false, error = `{err}. Entitlement stays retryable.` }
	end
	local row = decoded :: any
	if typeof(row.txHash) == "string" then
		return { ok = true, txHash = row.txHash }
	end
	return { ok = false, error = "Claim API returned no txHash. Entitlement stays retryable." }
end

return ClaimApi
