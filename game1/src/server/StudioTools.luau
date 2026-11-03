--!strict
-- Studio-only chat helpers so a playtest can reach the porch without six laps.
-- Not connected in a published server.

local RunService = game:GetService("RunService")

local StudioTools = {}

function StudioTools.Start(economy: any, notify: any, shop: any)
	if not RunService:IsStudio() then
		return
	end
	local function hook(player: Player)
		player.Chatted:Connect(function(message)
			if not RunService:IsStudio() then
				return
			end
			local amount = string.match(message, "^/cash%s+(%d+)$")
			if amount then
				local granted = tonumber(amount)
				if granted and granted > 0 then
					economy.AddCash(player, granted, economy.Reasons.Admin)
					notify.Say(player, "Studio grant +" .. amount .. " cash.")
				end
				return
			end
			local passKey = string.match(message, "^/pass%s+([%w_]+)$")
			if passKey and shop then
				local granted = shop.DebugGrantPass(player, passKey)
				notify.Say(
					player,
					if granted then "Studio pass " .. passKey .. "." else "Unknown pass."
				)
			end
		end)
	end
	local players = game:GetService("Players")
	players.PlayerAdded:Connect(hook)
	for _, player in players:GetPlayers() do
		hook(player)
	end
end

return StudioTools
