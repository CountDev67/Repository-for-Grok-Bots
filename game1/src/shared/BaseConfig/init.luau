--!strict
-- TODO(base-team): Replace these placeholder tiers with the real tycoon.
-- Tier 1's price matches the three porch pads (50 + 100 + 150). The slice
-- charges those pads, then sets BaseService tier to 1. Tier 2 is the porch's
-- Crypt Key (PorchPads.Upgrade, 1500 = 10 Graveyard Rugby Rush runs) and opens
-- Sore Foot Lava Crypt. Tier 3 is still a stub for droppers you have not built
-- yet. See docs/PAYOUT_CURVE.md before retuning.

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
			id = "cryptkey",
			name = "Crypt Key",
			price = 1500,
			blurb = "Opens Sore Foot Lava Crypt. TODO(base-team): droppers can raise this.",
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
