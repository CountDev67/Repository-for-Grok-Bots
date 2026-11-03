--!strict
-- Daily DoorDash shift and the offline-income cap hook.
-- GrantOfflineIncome is for the base team: call it once per join.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CourseLayout = require(ReplicatedStorage.Shared.CourseLayout)
local Streak = require(ReplicatedStorage.Shared.Retention.Streak)
local OfflineIncome = require(ReplicatedStorage.Shared.Retention.OfflineIncome)
local Economy = require(ReplicatedStorage.Shared.Economy)

local Parts = require(script.Parent.Parts)
local PlayerLock = require(script.Parent.PlayerLock)
local Saves = require(script.Parent.Saves)

local Retention = {}

type Memory = {
	streak: Streak.State,
	lastSeen: number,
	settled: number,
}

local state: { [number]: Memory } = {}
local economy = Economy
local notify: any = nil
local base: any = nil
local onDress: ((Player) -> ())? = nil

local function memoryOf(player: Player): Memory
	local found = state[player.UserId]
	if not found then
		found = { streak = Streak.Fresh(), lastSeen = 0, settled = 0 }
		state[player.UserId] = found
	end
	return found
end

local function today(): number
	return math.floor(os.time() / 86400)
end

function Retention.HasSock(player: Player): boolean
	local found = state[player.UserId]
	return found ~= nil and found.streak.sockGranted == true
end

function Retention.Load(player: Player, streakData: any, offlineData: any)
	local streak = Streak.Fresh()
	if type(streakData) == "table" then
		streak.lastClaimDay = if type(streakData.lastClaimDay) == "number"
			then streakData.lastClaimDay
			else 0
		streak.streak = if type(streakData.streak) == "number" then streakData.streak else 0
		streak.bestStreak = if type(streakData.bestStreak) == "number"
			then streakData.bestStreak
			else 0
		streak.sockGranted = streakData.sockGranted == true
	end
	local lastSeen = 0
	local settled = 0
	if type(offlineData) == "table" then
		if type(offlineData.lastSeen) == "number" then
			lastSeen = offlineData.lastSeen
		end
		if type(offlineData.settledLogoutAt) == "number" then
			settled = offlineData.settledLogoutAt
		end
	end
	state[player.UserId] = { streak = streak, lastSeen = lastSeen, settled = settled }
end

function Retention.Export(player: Player)
	local memory = memoryOf(player)
	return {
		lastClaimDay = memory.streak.lastClaimDay,
		streak = memory.streak.streak,
		bestStreak = memory.streak.bestStreak,
		sockGranted = memory.streak.sockGranted,
	}
end

function Retention.ExportOffline(player: Player)
	local memory = memoryOf(player)
	return { lastSeen = memory.lastSeen, settledLogoutAt = memory.settled }
end

function Retention.GetOfflineSeconds(player: Player): number
	local memory = memoryOf(player)
	if memory.lastSeen <= 0 then
		return 0
	end
	return math.max(0, os.time() - memory.lastSeen)
end

function Retention.ClaimShift(player: Player): (boolean, string)
	if not Saves.IsLoaded(player) then
		return false, "loading"
	end
	local message = "Still on the clock."
	local ok = false
	local ran = PlayerLock.Try(player, function()
		local memory = memoryOf(player)
		local claimed, newState, reward, err = Streak.Claim(memory.streak, today())
		if not claimed or not newState or not reward then
			message = if err == "already_claimed"
				then "Shift already worked today."
				else "Can't clock in."
			return
		end
		local previousStreak = memory.streak
		local cashBefore = economy.GetCash(player)
		memory.streak = newState
		economy.AddCash(player, reward.cash, economy.Reasons.DailyShift)
		if reward.sock and onDress then
			onDress(player)
		end
		if Saves.Save(player) then
			ok = true
			message = "Day "
				.. tostring(reward.day)
				.. " shift. +"
				.. tostring(reward.cash)
				.. " cash."
			if reward.sock then
				message ..= " The other sock is yours."
			end
		else
			memory.streak = previousStreak
			economy.Hydrate(player, cashBefore)
			if onDress then
				onDress(player)
			end
			message = "Clock-in didn't save. Try again."
		end
	end)
	if not ran then
		return false, "Busy. Try the shift again."
	end
	if notify then
		notify.Say(player, message)
	end
	return ok, message
end

function Retention.GrantOfflineIncome(
	player: Player,
	rawAccrued: number,
	elapsedSeconds: number?
): number
	if not Saves.IsLoaded(player) then
		return 0
	end
	local granted = 0
	PlayerLock.Try(player, function()
		local memory = memoryOf(player)
		if memory.lastSeen <= 0 then
			return
		end
		if memory.settled == memory.lastSeen then
			return
		end
		local elapsed = elapsedSeconds
		if type(elapsed) ~= "number" then
			elapsed = math.max(0, os.time() - memory.lastSeen)
		end
		local tier = if base then base.GetTier(player) else 1
		local amount = OfflineIncome.Cap(rawAccrued, elapsed, tier)
		local previous = memory.settled
		local cashBefore = economy.GetCash(player)
		if amount > 0 then
			economy.AddCash(player, amount, economy.Reasons.OfflineTycoon)
		end
		memory.settled = memory.lastSeen
		if Saves.Save(player) then
			granted = amount
		else
			memory.settled = previous
			economy.Hydrate(player, cashBefore)
		end
	end)
	return granted
end

function Retention.Forget(player: Player)
	state[player.UserId] = nil
end

function Retention.Start(deps: {
	folder: Folder,
	notify: any,
	base: any,
	onDress: (Player) -> (),
})
	notify = deps.notify
	base = deps.base
	onDress = deps.onDress
	local pad = Parts.block({
		name = "ShiftClock",
		size = Vector3.new(8, 1, 8),
		position = Vector3.new(24, CourseLayout.BASE_TOP + 0.5, -22),
		color = Color3.fromRGB(226, 48, 42),
		parent = deps.folder,
		material = Enum.Material.Neon,
	})
	Parts.billboard(pad, "DOOR DASH SHIFT\n7-day streak\nDay 7: a sock", Vector3.new(0, 5, 0), 240)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Clock in"
	prompt.ObjectText = "Daily shift"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad
	prompt.Triggered:Connect(function(player)
		Retention.ClaimShift(player)
	end)
end

return Retention
