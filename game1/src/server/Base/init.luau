--!strict
-- TODO(base-team): Replace this stub with the tycoon.
-- Keep these calls working:
--   GetTier(player) -> number
--   TierChanged:Fire(player, tier)
--   ExportState(player) -> plain table   (stored at profile.base untouched by Saves)
--   ImportState(player, blob)
-- The slice's blob is { tier = number, pads = { [padId] = true } } plus any
-- extra keys you put in the table. Extra keys round-trip.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Shared.Signal)
local JsonCopy = require(ReplicatedStorage.Shared.JsonCopy)

local BaseService = {}
BaseService.TierChanged = Signal.new()
BaseService.Loaded = Signal.new()

local tiers: { [number]: number } = {}
local pads: { [number]: { [string]: boolean } } = {}
local rawBlob: { [number]: { [string]: any } } = {}

local function userIdOf(player: Player): number
	return player.UserId
end

function BaseService.GetTier(player: Player): number
	return tiers[userIdOf(player)] or 0
end

function BaseService.SetTier(player: Player, tier: number)
	if type(tier) ~= "number" then
		error("tier must be a number", 2)
	end
	local stored = math.max(0, math.floor(tier))
	local userId = userIdOf(player)
	if tiers[userId] == stored then
		return
	end
	tiers[userId] = stored
	BaseService.TierChanged:Fire(player, stored)
end

function BaseService.GetPads(player: Player): { [string]: boolean }
	return table.clone(pads[userIdOf(player)] or {})
end

function BaseService.SetPad(player: Player, padId: string, owned: boolean)
	local userId = userIdOf(player)
	local map = pads[userId]
	if not map then
		map = {}
		pads[userId] = map
	end
	if owned then
		map[padId] = true
	else
		map[padId] = nil
	end
end

function BaseService.ExportState(player: Player): { [string]: any }
	local userId = userIdOf(player)
	local data = JsonCopy(rawBlob[userId] or {})
	if type(data) ~= "table" then
		data = {}
	end
	data.tier = BaseService.GetTier(player)
	data.pads = BaseService.GetPads(player)
	data.session = nil
	return data
end

function BaseService.ImportState(player: Player, blob: any)
	local userId = userIdOf(player)
	if type(blob) ~= "table" then
		blob = {}
	end
	rawBlob[userId] = JsonCopy(blob) or {}
	local tier = blob.tier
	if type(tier) ~= "number" then
		tier = 0
	end
	tiers[userId] = math.clamp(math.floor(tier), 0, 100)
	local owned: { [string]: boolean } = {}
	if type(blob.pads) == "table" then
		for key, value in blob.pads do
			if type(key) == "string" and value == true then
				owned[key] = true
			end
		end
	end
	pads[userId] = owned
	BaseService.TierChanged:Fire(player, tiers[userId])
	BaseService.Loaded:Fire(player)
end

function BaseService.Forget(player: Player)
	local userId = userIdOf(player)
	tiers[userId] = nil
	pads[userId] = nil
	rawBlob[userId] = nil
end

return BaseService
