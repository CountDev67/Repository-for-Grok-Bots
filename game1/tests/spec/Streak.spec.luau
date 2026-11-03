--!strict
local harness = require("./harness")
local Streak = require("../../src/shared/Retention/Streak")

harness.test("the first shift is day 1 and the same day cannot be claimed twice", function()
	local ok, state, reward = Streak.Claim(Streak.Fresh(), 1000)
	harness.assertTrue(ok)
	harness.assertEq(state.streak, 1)
	harness.assertEq(reward.cash, 200)
	harness.assertFalse(reward.sock)
	local again, _, _, err = Streak.Claim(state, 1000)
	harness.assertFalse(again)
	harness.assertEq(err, "already_claimed")
end)

harness.test("a missed day resets and day 7 grants the sock once", function()
	local state = Streak.Fresh()
	for day = 1, 6 do
		local ok, nextState = Streak.Claim(state, 1000 + day - 1)
		harness.assertTrue(ok)
		state = nextState
	end
	harness.assertEq(state.streak, 6)
	local skipped, reset = Streak.Claim(state, 1000 + 8)
	harness.assertTrue(skipped)
	harness.assertEq(reset.streak, 1)

	state = Streak.Fresh()
	for day = 1, 7 do
		local ok, nextState, reward = Streak.Claim(state, 2000 + day - 1)
		harness.assertTrue(ok, "day " .. tostring(day))
		if day == 7 then
			harness.assertTrue(reward.sock)
			harness.assertEq(reward.cash, 2200)
		end
		state = nextState
	end
	harness.assertTrue(state.sockGranted)
	local _, week2 = Streak.Claim(state, 2007)
	harness.assertEq(week2.streak, 1)
	harness.assertTrue(week2.sockGranted)
	state = week2
	local sockAgain = true
	for step = 1, 6 do
		local _, nextState, reward = Streak.Claim(state, 2007 + step)
		if reward.day == 7 then
			sockAgain = reward.sock
		end
		state = nextState
	end
	harness.assertEq(state.streak, 7)
	harness.assertFalse(sockAgain)
end)

harness.test("a backwards clock does not reset the streak", function()
	local _, state = Streak.Claim(Streak.Fresh(), 50)
	local ok, same, _, err = Streak.Claim(state, 49)
	harness.assertFalse(ok)
	harness.assertEq(err, "already_claimed")
	harness.assertEq(same.streak, 1)
end)
