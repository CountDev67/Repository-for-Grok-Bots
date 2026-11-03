--!strict
-- Cap hook for the base team's offline tycoon math.
-- Call Retention.GrantOfflineIncome once per join; this function is the pure cap.
-- Tier < 1 uses the tier-1 rate. Tier > 3 uses the tier-3 rate.
-- Nothing accrues past MaxHours.

local OfflineIncome = {}

OfflineIncome.PerHour = { 400, 1200, 4000 }
OfflineIncome.MaxHours = 8

function OfflineIncome.Cap(raw: any, elapsedSeconds: any, tier: any): number
	if type(raw) ~= "number" or raw ~= raw or raw <= 0 or raw == math.huge then
		return 0
	end
	if
		type(elapsedSeconds) ~= "number"
		or elapsedSeconds ~= elapsedSeconds
		or elapsedSeconds <= 0
	then
		return 0
	end
	local tierIndex = if type(tier) == "number" then math.floor(tier) else 1
	if tierIndex < 1 then
		tierIndex = 1
	end
	if tierIndex > #OfflineIncome.PerHour then
		tierIndex = #OfflineIncome.PerHour
	end
	local hours = math.min(elapsedSeconds / 3600, OfflineIncome.MaxHours)
	local cap = math.floor(OfflineIncome.PerHour[tierIndex] * hours + 1e-6)
	return math.min(math.floor(raw), cap)
end

return OfflineIncome
