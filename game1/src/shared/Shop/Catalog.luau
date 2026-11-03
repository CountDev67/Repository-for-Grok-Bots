--!strict
-- Placeholder Creator Dashboard ids are 0.
-- A live receipt with product id 0 is ignored. Replace the zeros before shipping.
-- Prices are the draft in docs/PRICING.md. 2× tips does not multiply these bundles.

local Catalog = {}

export type PassDef = {
	key: string,
	id: number,
	name: string,
	price: number,
	blurb: string,
}

export type ProductDef = {
	key: string,
	id: number,
	name: string,
	price: number,
	kind: string,
	cash: number?,
	blurb: string,
}

local PASSES: { PassDef } = {
	{
		key = "doubleCash",
		id = 0,
		name = "2× DoorDash Tips",
		price = 249,
		blurb = "Doubles earned cash: routes, checkpoints, the daily shift, offline income. Not Robux bundles.",
	},
	{
		key = "speedCoil",
		id = 0,
		name = "Rugby Cleats",
		price = 99,
		blurb = "WalkSpeed 16 to 22. The Count's feet stay sore. He is just faster about it.",
	},
	{
		key = "vip",
		id = 0,
		name = "Ice-Bath VIP",
		price = 199,
		blurb = 'The lounge is the base team\'s room. Check Shop.OwnsPass(player, "vip").',
	},
	{
		key = "foamBlaster",
		id = 0,
		name = "Foam Fangs",
		price = 149,
		blurb = "A toy foam dart launcher shaped like fangs. It does not damage players.",
	},
}

local PRODUCTS: { ProductDef } = {
	{
		key = "stageSkip",
		id = 0,
		name = "Skip this porch",
		price = 35,
		kind = "skip",
		blurb = "Pays the route you're on, without the timer. No route? 50 cash instead.",
	},
	{
		key = "revive",
		id = 0,
		name = "Ice the ankles",
		price = 25,
		kind = "revive",
		blurb = "Back to your checkpoint. The run stays armed.",
	},
	{
		key = "cashSmall",
		id = 0,
		name = "Snack run",
		price = 79,
		kind = "cash",
		cash = 3500,
		blurb = "A fixed tip pile. The 2× pass does not multiply it.",
	},
	{
		key = "cashMedium",
		id = 0,
		name = "Dinner rush",
		price = 349,
		kind = "cash",
		cash = 18000,
		blurb = "A bigger fixed pile. Still not multiplied by 2×.",
	},
	{
		key = "cashLarge",
		id = 0,
		name = "Catering contract",
		price = 799,
		kind = "cash",
		cash = 70000,
		blurb = "The whale pile. Face value only.",
	},
}

Catalog.Passes = PASSES
Catalog.Products = PRODUCTS

function Catalog.PassByKey(key: string): PassDef?
	for _, pass in PASSES do
		if pass.key == key then
			return pass
		end
	end
	return nil
end

function Catalog.ProductById(productId: number): ProductDef?
	if productId == 0 then
		return nil
	end
	for _, product in PRODUCTS do
		if product.id == productId then
			return product
		end
	end
	return nil
end

return Catalog
