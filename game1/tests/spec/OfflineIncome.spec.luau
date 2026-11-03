--!strict
local harness = require("./harness")
local OfflineIncome = require("../../src/shared/Retention/OfflineIncome")

harness.test("income under the cap is kept", function()
	harness.assertEq(OfflineIncome.Cap(100, 3600, 1), 100)
end)

harness.test("the hourly cap and the 8 hour ceiling both apply", function()
	harness.assertEq(OfflineIncome.Cap(100000, 2 * 3600, 1), 800)
	harness.assertEq(OfflineIncome.Cap(100000, 10 * 3600, 1), 3200)
	harness.assertEq(OfflineIncome.Cap(100000, 3600, 2), 1200)
	harness.assertEq(OfflineIncome.Cap(100000, 3600, 3), 4000)
end)

harness.test("bad inputs pay nothing and unknown tiers clamp", function()
	harness.assertEq(OfflineIncome.Cap(-5, 3600, 1), 0)
	harness.assertEq(OfflineIncome.Cap(500, 0, 1), 0)
	harness.assertEq(OfflineIncome.Cap(100000, 3600, 0), 400)
	harness.assertEq(OfflineIncome.Cap(100000, 3600, 9), 4000)
end)
