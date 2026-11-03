--!strict
-- DoorDash shift. UTC day numbers (floor(os.time() / 86400)).
-- Missing a day resets to 1. After day 7 the next day starts a new week.
-- The sock is once per account, not a tradable Roblox Limited.

local Streak = {}

Streak.Rewards = { 200, 400, 600, 800, 1000, 1400, 2200 }

export type State = {
	lastClaimDay: number,
	streak: number,
	bestStreak: number,
	sockGranted: boolean,
}

export type Reward = {
	day: number,
	cash: number,
	sock: boolean,
}

function Streak.Fresh(): State
	return { lastClaimDay = 0, streak = 0, bestStreak = 0, sockGranted = false }
end

local function nextDay(state: State, today: number): number?
	if state.lastClaimDay == 0 then
		return 1
	end
	local gap = today - state.lastClaimDay
	if gap <= 0 then
		return nil
	end
	if gap == 1 then
		if state.streak >= 7 then
			return 1
		end
		return state.streak + 1
	end
	return 1
end

function Streak.Claim(state: State, today: number): (boolean, State, Reward?, string?)
	if type(today) ~= "number" then
		return false, state, nil, "bad_day"
	end
	local day = nextDay(state, today)
	if not day then
		return false, state, nil, "already_claimed"
	end
	local grantSock = day == 7 and state.sockGranted ~= true
	local newState: State = {
		lastClaimDay = today,
		streak = day,
		bestStreak = math.max(state.bestStreak or 0, day),
		sockGranted = state.sockGranted == true or grantSock,
	}
	local reward: Reward = {
		day = day,
		cash = Streak.Rewards[day],
		sock = grantSock,
	}
	return true, newState, reward, nil
end

return Streak
