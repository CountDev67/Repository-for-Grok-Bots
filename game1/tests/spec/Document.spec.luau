--!strict
local harness = require("./harness")
local Document = require("../../src/server/Saves/Document")

harness.test("nil data becomes the template", function()
	local doc = Document.Reconcile(nil)
	harness.assertEq(doc.cash, 0)
	harness.assertEq(doc.streak.streak, 0)
	harness.assertEq(doc.base.tier, nil)
	harness.assertEq(doc.purchases.passes.doubleCash, false)
end)

harness.test("bad cash is dropped and base is preserved whole", function()
	local doc = Document.Reconcile({
		cash = "lots",
		base = { tier = 1, pads = { bench = true }, motto = "sore feet" },
		note = "keep-me",
		session = { jobId = "job-a", lockedAt = 12 },
	})
	harness.assertEq(doc.cash, 0)
	harness.assertEq(doc.base.tier, 1)
	harness.assertEq(doc.base.pads.bench, true)
	harness.assertEq(doc.base.motto, "sore feet")
	harness.assertEq(doc.note, "keep-me")
	harness.assertEq(doc.session.jobId, "job-a")
	harness.assertEq(doc.session.lockedAt, 12)
end)

harness.test("a non-table base becomes empty and receipts keep shape", function()
	local doc = Document.Reconcile({
		cash = 40.9,
		base = "nope",
		purchases = {
			passes = { vip = true, speedCoil = "yes" },
			receipts = { abc = { productId = 5, at = 9 } },
		},
		stages = { checkpoint = "suburbs", clears = { suburbs = 3 } },
	})
	harness.assertEq(doc.cash, 40)
	harness.assertEq(next(doc.base), nil)
	harness.assertEq(doc.purchases.passes.vip, true)
	harness.assertEq(doc.purchases.passes.speedCoil, false)
	harness.assertEq(doc.purchases.receipts.abc.productId, 5)
	harness.assertEq(doc.stages.checkpoint, "suburbs")
	harness.assertEq(doc.stages.clears.suburbs, 3)
end)
