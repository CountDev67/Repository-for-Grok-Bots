--!strict
-- TODO(base-team): Replace these placeholder tiers with the real tycoon.
-- Tier 1's price matches the three porch pads (50 + 100 + 150). The slice
-- charges those pads, then sets BaseService tier to 1. Tier 2 and 3 prices
-- are stubs for droppers you have not built yet — the obby alone is not
-- meant to pay them. See docs/PAYOUT_CURVE.md before retuning.

local BaseConfig = {
	tiers = {
		{
			tier = 1,
			id = "porch",
			name = "Porch",
			price = 300,
			blurb = "Bench, ice bath, and a delivery-bag shrine.",
		},
		{
			tier = 2,
			id = "walkup",
			name = "Walk-up",
			price = 12000,
			blurb = "TODO(base-team): stairs, droppers, and a real price.",
		},
		{
			tier = 3,
			id = "keep",
			name = "Castle Keep",
			price = 80000,
			blurb = "TODO(base-team): endgame base. Placeholder price only.",
		},
	},
}

function BaseConfig.Get(tier: number)
	for _, entry in BaseConfig.tiers do
		if entry.tier == tier then
			return entry
		end
	end
	return nil
end

return BaseConfig
