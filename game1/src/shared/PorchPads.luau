--!strict
-- Placeholder porch purchases. The base team replaces the pads;
-- the prices here are the playable slice, not the later tycoon curve.

local PorchPads = {}

export type PadDef = {
	id: string,
	name: string,
	cost: number,
	kind: string,
	blurb: string,
}

export type OwnedMap = { [string]: boolean }

export type Preview = {
	ok: boolean,
	reason: string,
	cost: number?,
	owned: OwnedMap?,
	tier: number?,
}

local DEFS: { PadDef } = {
	{
		id = "bench",
		name = "Porch Bench",
		cost = 50,
		kind = "bench",
		blurb = "Sit down. The Count's feet filed a complaint.",
	},
	{
		id = "icebath",
		name = "Ice Bath",
		cost = 100,
		kind = "icebath",
		blurb = "For sore rugby feet. Water not included, the look is.",
	},
	{
		id = "shrine",
		name = "DoorDash Bag Shrine",
		cost = 150,
		kind = "shrine",
		blurb = "A red delivery bag on a pedestal. Reverence, then tips.",
	},
}

local BY_ID: { [string]: PadDef } = {}
for _, def in DEFS do
	BY_ID[def.id] = def
end

PorchPads.Defs = DEFS

function PorchPads.Get(id: string): PadDef?
	return BY_ID[id]
end

function PorchPads.OwnsAll(owned: OwnedMap): boolean
	for _, def in DEFS do
		if owned[def.id] ~= true then
			return false
		end
	end
	return true
end

function PorchPads.Preview(owned: OwnedMap, padId: string, cash: number): Preview
	local def = BY_ID[padId]
	if not def then
		return { ok = false, reason = "unknown" }
	end
	if owned[padId] == true then
		return { ok = false, reason = "already", cost = def.cost }
	end
	if type(cash) ~= "number" or cash < def.cost then
		return { ok = false, reason = "poor", cost = def.cost }
	end
	local nextOwned: OwnedMap = table.clone(owned)
	nextOwned[padId] = true
	local tier = if PorchPads.OwnsAll(nextOwned) then 1 else 0
	return {
		ok = true,
		reason = "ok",
		cost = def.cost,
		owned = nextOwned,
		tier = tier,
	}
end

return PorchPads
