--!strict
-- Profile shape for the one player DataStore.
-- `base` is stored as the base team handed it over. We do not interpret it here.

local JsonCopy
if script ~= nil then
	JsonCopy = require(game:GetService("ReplicatedStorage").Shared.JsonCopy)
else
	JsonCopy = require("../../shared/JsonCopy")
end

local Document = {}

local KNOWN = {
	cash = true,
	stages = true,
	streak = true,
	purchases = true,
	offline = true,
	base = true,
	session = true,
}

local PASS_KEYS = { "doubleCash", "speedCoil", "vip", "foamBlaster" }

function Document.Template()
	return {
		cash = 0,
		stages = { checkpoint = "", clears = {} },
		streak = { lastClaimDay = 0, streak = 0, bestStreak = 0, sockGranted = false },
		purchases = {
			receipts = {},
			passes = {
				doubleCash = false,
				speedCoil = false,
				vip = false,
				foamBlaster = false,
			},
		},
		offline = { lastSeen = 0, settledLogoutAt = 0 },
		base = {},
	}
end

local function nonNegativeInt(value: any): number?
	if type(value) == "number" and value == value and value >= 0 and value ~= math.huge then
		return math.floor(value)
	end
	return nil
end

function Document.Reconcile(saved: any)
	local doc = Document.Template()
	if type(saved) ~= "table" then
		return doc
	end

	local cash = nonNegativeInt(saved.cash)
	if cash then
		doc.cash = cash
	end

	if type(saved.stages) == "table" then
		if type(saved.stages.checkpoint) == "string" then
			doc.stages.checkpoint = saved.stages.checkpoint
		end
		if type(saved.stages.clears) == "table" then
			for key, value in saved.stages.clears do
				local count = nonNegativeInt(value)
				if type(key) == "string" and count then
					doc.stages.clears[key] = count
				end
			end
		end
	end

	if type(saved.streak) == "table" then
		local day = nonNegativeInt(saved.streak.lastClaimDay)
		local streak = nonNegativeInt(saved.streak.streak)
		local best = nonNegativeInt(saved.streak.bestStreak)
		if day then
			doc.streak.lastClaimDay = day
		end
		if streak then
			doc.streak.streak = streak
		end
		if best then
			doc.streak.bestStreak = best
		end
		doc.streak.sockGranted = saved.streak.sockGranted == true
	end

	if type(saved.purchases) == "table" then
		if type(saved.purchases.passes) == "table" then
			for _, key in PASS_KEYS do
				doc.purchases.passes[key] = saved.purchases.passes[key] == true
			end
		end
		if type(saved.purchases.receipts) == "table" then
			for key, value in saved.purchases.receipts do
				local productId = if type(value) == "table"
					then nonNegativeInt(value.productId)
					else nil
				local at = if type(value) == "table" then nonNegativeInt(value.at) else nil
				if type(key) == "string" and productId and at then
					doc.purchases.receipts[key] = { productId = productId, at = at }
				end
			end
		end
	end

	if type(saved.offline) == "table" then
		local lastSeen = nonNegativeInt(saved.offline.lastSeen)
		local settled = nonNegativeInt(saved.offline.settledLogoutAt)
		if lastSeen then
			doc.offline.lastSeen = lastSeen
		end
		if settled then
			doc.offline.settledLogoutAt = settled
		end
	end

	if type(saved.base) == "table" then
		doc.base = JsonCopy(saved.base)
	end

	if type(saved.session) == "table" and type(saved.session.jobId) == "string" then
		doc.session = {
			jobId = saved.session.jobId,
			lockedAt = nonNegativeInt(saved.session.lockedAt) or 0,
		}
	end

	for key, value in saved do
		if type(key) == "string" and not KNOWN[key] then
			local cloned = JsonCopy(value)
			if cloned ~= nil then
				doc[key] = cloned
			end
		end
	end

	return doc
end

return Document
