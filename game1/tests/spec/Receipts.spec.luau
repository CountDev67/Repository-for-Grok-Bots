--!strict
local harness = require("./harness")
local Receipts = require("../../src/shared/Shop/Receipts")

local function callbacks(grants: { number }, saved: { boolean })
	return {
		grant = function()
			grants[1] += 1
			return true
		end,
		save = function()
			return saved[1]
		end,
		now = function()
			return 50
		end,
	}
end

harness.test("a failed save does not grant twice on retry", function()
	local receipts = {}
	local grants = { 0 }
	local saved = { false }
	local receipt = { PurchaseId = "order-1", ProductId = 11 }
	local first = Receipts.Process(receipts, receipt, callbacks(grants, saved))
	harness.assertEq(first, "NotProcessedYet")
	harness.assertEq(grants[1], 1)
	harness.assertEq(receipts["order-1"].productId, 11)

	saved[1] = true
	local second = Receipts.Process(receipts, receipt, callbacks(grants, saved))
	harness.assertEq(second, "PurchaseGranted")
	harness.assertEq(grants[1], 1)

	local third = Receipts.Process(receipts, receipt, callbacks(grants, saved))
	harness.assertEq(third, "PurchaseGranted")
	harness.assertEq(grants[1], 1)
end)

harness.test("a refused grant is not recorded", function()
	local receipts = {}
	local result = Receipts.Process(receipts, { PurchaseId = "order-2", ProductId = 4 }, {
		grant = function()
			return false
		end,
		save = function()
			return true
		end,
		now = function()
			return 1
		end,
	})
	harness.assertEq(result, "NotProcessedYet")
	harness.assertEq(receipts["order-2"], nil)
end)

harness.test("different purchase ids both grant", function()
	local receipts = {}
	local grants = { 0 }
	local saved = { true }
	Receipts.Process(receipts, { PurchaseId = "a", ProductId = 1 }, callbacks(grants, saved))
	Receipts.Process(receipts, { PurchaseId = "b", ProductId = 2 }, callbacks(grants, saved))
	harness.assertEq(grants[1], 2)
	harness.assertEq(receipts.a.productId, 1)
	harness.assertEq(receipts.b.productId, 2)
end)

harness.test("a blank purchase id is not processed", function()
	local result = Receipts.Process({}, { PurchaseId = "", ProductId = 1 }, {
		grant = function()
			error("should not grant")
		end,
		save = function()
			return true
		end,
		now = function()
			return 1
		end,
	})
	harness.assertEq(result, "NotProcessedYet")
end)
