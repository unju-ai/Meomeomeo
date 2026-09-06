--!strict

-- Integration point for a future hosted LLM.
-- This file never ships a real key. If ApiKey/Endpoint are empty, we
-- fall back to the mock so the game always runs in Studio.

local HttpService = game:GetService("HttpService")

local Config = require(script.Parent.Parent.Config)
local MockAiProvider = require(script.Parent.MockAiProvider)

export type ChatContext = MockAiProvider.ChatContext

local HttpAiProvider = {}

function HttpAiProvider.complete(message: string, context: ChatContext): string
	if Config.Ai.ApiKey == "" or Config.Ai.Endpoint == "" then
		return MockAiProvider.complete(message, context)
	end

	local body = HttpService:JSONEncode({
		model = Config.Ai.Model,
		messages = {
			{
				role = "system",
				content = `You are {context.npc.name}, a {context.npc.role} in the Roblox cat MOBA Meo Meo Meo. {context.npc.personality} Keep replies under 2 sentences. Player={context.playerName} champion={context.championName or "unknown"} phase={context.phase} score={context.scoreline}.`,
			},
			{ role = "user", content = message },
		},
	})

	local ok, response = pcall(function()
		return HttpService:RequestAsync({
			Url = Config.Ai.Endpoint,
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json",
				["Authorization"] = `Bearer {Config.Ai.ApiKey}`,
			},
			Body = body,
		})
	end)

	if not ok or typeof(response) ~= "table" or response.Success ~= true then
		return MockAiProvider.complete(message, context)
	end

	local decodedOk, decoded = pcall(function()
		return HttpService:JSONDecode(response.Body)
	end)
	if decodedOk and typeof(decoded) == "table" then
		local choices = (decoded :: any).choices
		if typeof(choices) == "table" and choices[1] and choices[1].message then
			local content = choices[1].message.content
			if typeof(content) == "string" and content ~= "" then
				return content
			end
		end
	end

	return MockAiProvider.complete(message, context)
end

return HttpAiProvider
