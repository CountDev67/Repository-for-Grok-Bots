--!strict
-- Server-authoritative cash. The module is shared so the API is one place;
-- each VM has its own table. Mutations throw on the client.
-- Changed:Fire(player, cash, delta, reason)

local Signal
if script ~= nil then
	Signal = require(script.Parent.Signal)
else
	Signal = require("./Signal")
end

local Economy = {}
Economy.Changed = Signal.new()

Economy.Reasons = {
	StageClear = "stage_clear",
	Checkpoint = "checkpoint",
	TimerBonus = "timer_bonus",
	DailyShift = "daily_shift",
	DevProduct = "dev_product",
	OfflineTycoon = "offline_tycoon",
	BasePad = "base_pad",
	Hydrate = "hydrate",
	Admin = "admin",
}

local MULTIPLIED: { [string]: boolean } = {
	stage_clear = true,
	checkpoint = true,
	timer_bonus = true,
	daily_shift = true,
	offline_tycoon = true,
}

local cashByUser: { [number]: number } = {}
local multiplierByUser: { [number]: number } = {}
local authorityOverride: boolean? = nil

local function userIdOf(player: any): number
	local userId = player and player.UserId
	if type(userId) ~= "number" then
		error("expected a player with a numeric UserId", 3)
	end
	return userId
end

local function isAuthoritative(): boolean
	if authorityOverride ~= nil then
		return authorityOverride
	end
	local ok, server = pcall(function()
		return game:GetService("RunService"):IsServer()
	end)
	if not ok then
		return true
	end
	return server == true
end

local function assertServer()
	if not isAuthoritative() then
		error("Economy mutations are server-authoritative", 2)
	end
end

local function assertReason(reason: any)
	if type(reason) ~= "string" or reason == "" then
		error("cash reason must be a non-empty string", 3)
	end
end

local function assertPositiveInt(amount: any, name: string)
	if
		type(amount) ~= "number"
		or amount ~= amount
		or amount == math.huge
		or amount <= 0
		or amount ~= math.floor(amount)
	then
		error(name .. " expects a positive integer", 3)
	end
end

local function assertNonNegativeInt(amount: any, name: string)
	if
		type(amount) ~= "number"
		or amount ~= amount
		or amount == math.huge
		or amount < 0
		or amount ~= math.floor(amount)
	then
		error(name .. " expects a non-negative integer", 3)
	end
end

function Economy.GetCash(player: any): number
	return cashByUser[userIdOf(player)] or 0
end

function Economy.GetEarnMultiplier(player: any): number
	return multiplierByUser[userIdOf(player)] or 1
end

function Economy.SetEarnMultiplier(player: any, multiplier: number)
	assertServer()
	if
		type(multiplier) ~= "number"
		or multiplier ~= multiplier
		or multiplier < 1
		or multiplier == math.huge
	then
		error("earn multiplier must be a finite number >= 1", 2)
	end
	multiplierByUser[userIdOf(player)] = multiplier
end

function Economy.AddCash(player: any, amount: number, reason: string)
	assertServer()
	assertPositiveInt(amount, "AddCash")
	assertReason(reason)
	local userId = userIdOf(player)
	local multiplier = 1
	if MULTIPLIED[reason] then
		multiplier = multiplierByUser[userId] or 1
	end
	local applied = math.floor(amount * multiplier + 1e-6)
	local nextCash = (cashByUser[userId] or 0) + applied
	cashByUser[userId] = nextCash
	Economy.Changed:Fire(player, nextCash, applied, reason)
end

function Economy.TrySpend(player: any, amount: number, reason: string): boolean
	assertServer()
	assertPositiveInt(amount, "TrySpend")
	assertReason(reason)
	local userId = userIdOf(player)
	local current = cashByUser[userId] or 0
	if current < amount then
		return false
	end
	local nextCash = current - amount
	cashByUser[userId] = nextCash
	Economy.Changed:Fire(player, nextCash, -amount, reason)
	return true
end

function Economy.Hydrate(player: any, amount: number)
	assertServer()
	assertNonNegativeInt(amount, "Hydrate")
	local userId = userIdOf(player)
	local previous = cashByUser[userId] or 0
	cashByUser[userId] = amount
	if amount == previous then
		return
	end
	Economy.Changed:Fire(player, amount, amount - previous, Economy.Reasons.Hydrate)
end

function Economy.Forget(player: any)
	local userId = userIdOf(player)
	cashByUser[userId] = nil
	multiplierByUser[userId] = nil
end

function Economy._setAuthority(value: boolean?)
	authorityOverride = value
end

function Economy._reset()
	table.clear(cashByUser)
	table.clear(multiplierByUser)
	authorityOverride = nil
end

return Economy
