--!strict
local harness = require("./harness")
local Catalog = require("../../src/shared/Shop/Catalog")

harness.test("placeholder ids are zero and bundle value rises with price", function()
	for _, pass in Catalog.Passes do
		harness.assertEq(pass.id, 0, pass.key)
		harness.assertTrue(pass.price > 0, pass.key)
	end
	local previous = 0
	for _, product in Catalog.Products do
		harness.assertEq(product.id, 0, product.key)
		if product.kind == "cash" then
			local rate = (product.cash :: number) / product.price
			harness.assertTrue(rate > previous, product.key)
			previous = rate
		end
	end
	harness.assertEq(Catalog.ProductById(0), nil)
	harness.assertEq(Catalog.PassByKey("foamBlaster").name, "Foam Fangs")
end)
