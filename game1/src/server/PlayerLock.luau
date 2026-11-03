--!strict
-- One mutating critical section per player. Re-entrant on the same coroutine
-- so a claim can save without deadlocking. A different coroutine gets "busy".

local PlayerLock = {}

local owner: { [number]: thread } = {}

function PlayerLock.IsBusy(player: Player): boolean
	local current = owner[player.UserId]
	return current ~= nil and current ~= coroutine.running()
end

function PlayerLock.Try(player: Player, fn: () -> ()): (boolean, string?)
	local userId = player.UserId
	local thread = coroutine.running()
	if owner[userId] ~= nil and owner[userId] ~= thread then
		return false, "busy"
	end
	local nested = owner[userId] == thread
	if not nested then
		owner[userId] = thread
	end
	local ok, err = pcall(fn)
	if not nested and owner[userId] == thread then
		owner[userId] = nil
	end
	if not ok then
		warn("[CountCrackula] " .. tostring(err))
		return false, "error"
	end
	return true, nil
end

function PlayerLock.Forget(player: Player)
	owner[player.UserId] = nil
end

return PlayerLock
