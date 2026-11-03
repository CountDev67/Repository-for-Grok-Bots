--!strict
local harness = require("./harness")
local Lock = require("../../src/server/Saves/Lock")

local TTL = 100

harness.test("a missing session is acquired", function()
	local session, status = Lock.Claim(nil, "job-a", 1000, TTL)
	harness.assertEq(status, "acquired")
	harness.assertEq(session.jobId, "job-a")
	harness.assertEq(session.lockedAt, 1000)
end)

harness.test("the same job refreshes and a live other job is busy", function()
	local session = { jobId = "job-a", lockedAt = 1000 }
	local refreshed, refreshedStatus = Lock.Claim(session, "job-a", 1010, TTL)
	harness.assertEq(refreshedStatus, "refreshed")
	harness.assertEq(refreshed.lockedAt, 1010)
	local blocked, blockedStatus = Lock.Claim(session, "job-b", 1050, TTL)
	harness.assertEq(blockedStatus, "busy")
	harness.assertEq(blocked, nil)
	harness.assertTrue(Lock.Owns(session, "job-a"))
	harness.assertFalse(Lock.Owns(session, "job-b"))
end)

harness.test("an expired lock can be stolen", function()
	local session = { jobId = "job-a", lockedAt = 1000 }
	local stolen, status = Lock.Claim(session, "job-b", 1000 + TTL, TTL)
	harness.assertEq(status, "stolen")
	harness.assertEq(stolen.jobId, "job-b")
end)

harness.test("an empty job id does not take the lock", function()
	local session, status = Lock.Claim(nil, "", 10, TTL)
	harness.assertEq(status, "busy")
	harness.assertEq(session, nil)
end)
