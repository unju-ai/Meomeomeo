--!strict

-- Bridge to the hosted claim service that actually signs / mints on-chain.
-- Roblox must NEVER hold MEO404_MINTER_PRIVATE_KEY.
--
-- Mock mode records a fake tx hash so Studio playtests work.
-- Http mode POSTs { userId, purchaseId, nonce, wallet } to Config.Nft404.ClaimApiUrl.

local HttpService = game:GetService("HttpService")

local Config = require(script.Parent.Parent.Config)
local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

export type ClaimResponse = {
	ok: boolean,
	txHash: string?,
	error: string?,
}

local ClaimApi = {}

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
		return { ok = false, error = "Claim API URL is empty; staying on mock would hide misconfig." }
	end
	if Config.Nft404.ClaimApiSecret == "" then
		return { ok = false, error = "Claim API secret missing. Do not embed a chain key here." }
	end

	local body = HttpService:JSONEncode({
		robloxUserId = entitlement.userId,
		purchaseId = entitlement.purchaseId,
		productId = entitlement.productId,
		nonce = entitlement.nonce,
		wallet = wallet,
	})

	local ok, response = pcall(function()
		return HttpService:RequestAsync({
			Url = Config.Nft404.ClaimApiUrl,
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json",
				["Authorization"] = `Bearer {Config.Nft404.ClaimApiSecret}`,
			},
			Body = body,
		})
	end)

	if not ok or typeof(response) ~= "table" or (response :: any).Success ~= true then
		return { ok = false, error = "Claim API request failed. Entitlement stays Granted for retry." }
	end

	local decodedOk, decoded = pcall(function()
		return HttpService:JSONDecode((response :: any).Body)
	end)
	if decodedOk and typeof(decoded) == "table" and typeof((decoded :: any).txHash) == "string" then
		return { ok = true, txHash = (decoded :: any).txHash }
	end
	return { ok = false, error = "Claim API returned no txHash." }
end

return ClaimApi
