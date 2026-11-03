--!strict
local harness = require("./harness")
local PorchPads = require("../../src/shared/PorchPads")
local BaseConfig = require("../../src/shared/BaseConfig")

harness.test("pad prices are 50, 100, and 150", function()
	harness.assertEq(#PorchPads.Defs, 3)
	harness.assertEq(PorchPads.Defs[1].id, "bench")
	harness.assertEq(PorchPads.Defs[1].cost, 50)
	harness.assertEq(PorchPads.Defs[2].id, "icebath")
	harness.assertEq(PorchPads.Defs[2].cost, 100)
	harness.assertEq(PorchPads.Defs[3].id, "shrine")
	harness.assertEq(PorchPads.Defs[3].cost, 150)
end)

harness.test("tier 1 price matches the three pads", function()
	local total = 0
	for _, def in PorchPads.Defs do
		total += def.cost
	end
	local tier = BaseConfig.Get(1)
	harness.assertTrue(tier ~= nil)
	harness.assertEq(tier.price, total)
	harness.assertEq(tier.price, 300)
end)

harness.test("buying all three sets tier to 1 and rejects doubles", function()
	local owned = {}
	local cash = 300
	local tier = 0
	for _, def in PorchPads.Defs do
		local preview = PorchPads.Preview(owned, def.id, cash)
		harness.assertTrue(preview.ok, def.id)
		harness.assertEq(preview.cost, def.cost)
		cash -= preview.cost :: number
		owned = preview.owned :: any
		tier = preview.tier :: number
	end
	harness.assertEq(cash, 0)
	harness.assertEq(tier, 1)
	harness.assertTrue(PorchPads.OwnsAll(owned))
	local again = PorchPads.Preview(owned, "bench", 50)
	harness.assertFalse(again.ok)
	harness.assertEq(again.reason, "already")
end)

harness.test("partial porch stays tier 0 and poor buys fail", function()
	local owned = {}
	local first = PorchPads.Preview(owned, "bench", 50)
	harness.assertTrue(first.ok)
	harness.assertEq(first.tier, 0)
	local poor = PorchPads.Preview(first.owned :: any, "icebath", 40)
	harness.assertFalse(poor.ok)
	harness.assertEq(poor.reason, "poor")
	local unknown = PorchPads.Preview({}, "moat", 999)
	harness.assertEq(unknown.reason, "unknown")
end)
