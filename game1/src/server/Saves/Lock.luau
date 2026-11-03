--!strict
-- Session-lock decision. Pure: the DataStore wrapper does the retries.
-- A lock older than ttl can be stolen. A live lock owned by someone else is busy.

local Lock = {}

export type Session = {
	jobId: string,
	lockedAt: number,
}

export type ClaimStatus = "acquired" | "refreshed" | "stolen" | "busy"

function Lock.Claim(session: any, jobId: string, now: number, ttl: number): (Session?, ClaimStatus)
	if type(jobId) ~= "string" or jobId == "" then
		return nil, "busy"
	end
	if type(session) ~= "table" or type(session.jobId) ~= "string" or session.jobId == "" then
		return { jobId = jobId, lockedAt = now }, "acquired"
	end
	if session.jobId == jobId then
		return { jobId = jobId, lockedAt = now }, "refreshed"
	end
	local lockedAt = if type(session.lockedAt) == "number" then session.lockedAt else 0
	local age = now - lockedAt
	if age < ttl then
		return nil, "busy"
	end
	return { jobId = jobId, lockedAt = now }, "stolen"
end

function Lock.Owns(session: any, jobId: string): boolean
	return type(session) == "table" and session.jobId == jobId
end

return Lock
