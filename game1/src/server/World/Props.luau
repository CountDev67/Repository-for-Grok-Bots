--!strict
-- Spooky-cute props built from Parts. Every builder takes a CFrame at ground
-- level whose LookVector is the prop's "front", and returns a Model.
-- Decorative pieces use Parts.block{decor = true}: no touch, no query, no shadow.

local Parts = require(script.Parent.Parent.Parts)

local Props = {}

local rgb = Color3.fromRGB
local M = Enum.Material

local IRON = rgb(28, 26, 34)
local BARK = rgb(52, 40, 38)
local STONE = rgb(118, 116, 128)
local PUMPKIN = rgb(255, 128, 28)
local FLAME = rgb(255, 196, 90)
local VAN_RED = rgb(235, 48, 26)

local function model(name: string, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function piece(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	solid: boolean?,
	shape: Enum.PartType?
): Part
	return Parts.block({
		name = name,
		size = size,
		cframe = cf,
		color = color,
		parent = parent,
		material = material,
		decor = not solid,
		canCollide = if solid then true else false,
		shape = shape,
	})
end


function Props.jackOLantern(parent: Instance, cf: CFrame, scale: number?): Model
	local s = scale or 1
	local m = model("JackOLantern", parent)
	piece(m, "Pumpkin", Vector3.new(2.6, 2.6, 2.6) * s, cf * CFrame.new(0, 1.3 * s, 0), PUMPKIN, M.SmoothPlastic, true, Enum.PartType.Ball)
	piece(m, "Stem", Vector3.new(0.35, 0.6, 0.35) * s, cf * CFrame.new(0, 2.45 * s, 0), rgb(70, 110, 40), M.Wood)
	-- Friendly face: two eyes and a smile, glowing.
	for _, x in { -0.5, 0.5 } do
		piece(m, "Eye", Vector3.new(0.45, 0.45, 0.2) * s, cf * CFrame.new(x * s, 1.45 * s, -1.22 * s), FLAME, M.Neon)
	end
	piece(m, "Smile", Vector3.new(1.2, 0.25, 0.2) * s, cf * CFrame.new(0, 0.75 * s, -1.2 * s), FLAME, M.Neon)
	return m
end

function Props.tombstone(parent: Instance, cf: CFrame, text: string?, tall: number?): Model
	local m = model("Tombstone", parent)
	local h = tall or 3.2
	local slab = piece(m, "Stone", Vector3.new(2.6, h, 0.8), cf * CFrame.new(0, h / 2, 0), STONE, M.Slate, true)
	piece(m, "Cap", Vector3.new(0.8, 2.6, 2.6), cf * CFrame.new(0, h, 0) * CFrame.Angles(0, math.rad(90), 0), STONE, M.Slate, false, Enum.PartType.Cylinder)
	piece(m, "Mound", Vector3.new(3, 0.5, 4.5), cf * CFrame.new(0, 0.25, 2.4), rgb(46, 52, 40), M.Ground)
	if text then
		Parts.decal(slab, Enum.NormalId.Front, text, rgb(30, 24, 40))
	end
	return m
end

function Props.coffin(parent: Instance, cf: CFrame, standing: boolean?): Model
	local m = model("Coffin", parent)
	local base = if standing then cf * CFrame.new(0, 3.2, 0) * CFrame.Angles(math.rad(-90), 0, 0) else cf * CFrame.new(0, 0.6, 0)
	piece(m, "Box", Vector3.new(2.6, 1.2, 6.2), base, rgb(70, 40, 34), M.Wood, true)
	piece(m, "Lid", Vector3.new(2.8, 0.3, 6.4), base * CFrame.new(0, 0.7, 0), rgb(92, 54, 44), M.Wood)
	piece(m, "Trim", Vector3.new(2.9, 0.12, 0.5), base * CFrame.new(0, 0.9, -1.4), rgb(180, 80, 255), M.Neon)
	return m
end

function Props.fence(parent: Instance, from: Vector3, to: Vector3, height: number?): Model
	local m = model("IronFence", parent)
	local h = height or 4
	local delta = to - from
	local length = delta.Magnitude
	if length < 0.5 then
		return m
	end
	local mid = (from + to) / 2
	local frame = CFrame.lookAt(mid, mid + delta)
	-- Rails are solid so players do not fall off the plaza by accident.
	piece(m, "RailTop", Vector3.new(0.3, 0.3, length), frame * CFrame.new(0, h - 0.4, 0), IRON, M.Metal, true)
	piece(m, "RailLow", Vector3.new(0.3, 0.3, length), frame * CFrame.new(0, 0.8, 0), IRON, M.Metal, true)
	local posts = math.max(2, math.floor(length / 2.5))
	for i = 0, posts do
		local t = (i / posts - 0.5) * length
		piece(m, "Bar", Vector3.new(0.22, h, 0.22), frame * CFrame.new(0, h / 2, t), IRON, M.Metal)
		piece(m, "Spike", Vector3.new(0.35, 0.35, 0.35), frame * CFrame.new(0, h + 0.15, t) * CFrame.Angles(0, 0, math.rad(45)) * CFrame.Angles(math.rad(45), 0, 0), IRON, M.Metal)
	end
	return m
end

function Props.deadTree(parent: Instance, cf: CFrame, height: number?): Model
	local m = model("DeadTree", parent)
	local h = height or 14
	piece(m, "Trunk", Vector3.new(1.6, h, 1.6), cf * CFrame.new(0, h / 2, 0), BARK, M.Wood, true)
	local branches = {
		{ 0.55, 35, 0, 6 },
		{ 0.7, -40, 90, 5 },
		{ 0.8, 30, 200, 4.5 },
		{ 0.9, -25, 300, 3.5 },
	}
	for _, b in branches do
		local y = h * b[1]
		local len = b[4]
		local branchCf = cf
			* CFrame.new(0, y, 0)
			* CFrame.Angles(0, math.rad(b[3]), 0)
			* CFrame.Angles(0, 0, math.rad(b[2]))
			* CFrame.new(0, len / 2, 0)
		piece(m, "Branch", Vector3.new(0.6, len, 0.6), branchCf, BARK, M.Wood)
	end
	return m
end

function Props.candelabra(parent: Instance, cf: CFrame, lit: boolean?): Model
	local m = model("Candelabra", parent)
	local gold = rgb(196, 150, 70)
	piece(m, "Foot", Vector3.new(2, 0.4, 2), cf * CFrame.new(0, 0.2, 0), gold, M.Metal, true)
	piece(m, "Stem", Vector3.new(0.35, 4.5, 0.35), cf * CFrame.new(0, 2.45, 0), gold, M.Metal, true)
	piece(m, "Arm", Vector3.new(3.4, 0.3, 0.3), cf * CFrame.new(0, 4.2, 0), gold, M.Metal)
	for _, x in { -1.6, 0, 1.6 } do
		local yBase = if x == 0 then 4.9 else 4.5
		piece(m, "Candle", Vector3.new(0.4, 1, 0.4), cf * CFrame.new(x, yBase, 0), rgb(248, 240, 226), M.SmoothPlastic)
		local flame = piece(m, "Flame", Vector3.new(0.3, 0.5, 0.3), cf * CFrame.new(x, yBase + 0.75, 0), FLAME, M.Neon)
		if lit and x == 0 then
			Parts.light(flame, rgb(255, 170, 90), 16, 1.6)
		end
	end
	return m
end

function Props.mailbox(parent: Instance, cf: CFrame): Model
	local m = model("Mailbox", parent)
	piece(m, "Post", Vector3.new(0.4, 3.4, 0.4), cf * CFrame.new(0, 1.7, 0), rgb(60, 44, 36), M.Wood, true)
	piece(m, "Box", Vector3.new(1.2, 1.1, 2), cf * CFrame.new(0, 3.9, 0), rgb(40, 40, 56), M.Metal, true)
	piece(m, "Flag", Vector3.new(0.1, 0.8, 0.4), cf * CFrame.new(0.65, 4.4, 0.5), VAN_RED, M.SmoothPlastic)
	return m
end

function Props.lampPost(parent: Instance, cf: CFrame, color: Color3?): Model
	local m = model("LampPost", parent)
	piece(m, "Pole", Vector3.new(0.5, 9, 0.5), cf * CFrame.new(0, 4.5, 0), IRON, M.Metal, true)
	piece(m, "Cap", Vector3.new(1.4, 0.4, 1.4), cf * CFrame.new(0, 10.5, 0), IRON, M.Metal)
	local bulb = piece(m, "Lantern", Vector3.new(1, 1.4, 1), cf * CFrame.new(0, 9.7, 0), color or rgb(190, 120, 255), M.Neon)
	Parts.light(bulb, color or rgb(190, 120, 255), 22, 1.4)
	return m
end

-- A two-story haunted house with a porch. Front faces cf.LookVector.
function Props.house(parent: Instance, cf: CFrame, wall: Color3, glow: Color3): Model
	local m = model("HauntedHouse", parent)
	local w, d, h = 16, 14, 14
	-- Body sits behind the porch; the porch is at local -Z (front).
	local body = cf * CFrame.new(0, h / 2, 3)
	piece(m, "Body", Vector3.new(w, h, d), body, wall, M.WoodPlanks, true)
	-- Gable roof from two wedges.
	local roofH = 6
	local roofBase = cf * CFrame.new(0, h + roofH / 2, 3)
	Parts.wedge("RoofL", Vector3.new(d + 1, roofH, w / 2 + 0.5), roofBase * CFrame.new(-w / 4, 0, 0) * CFrame.Angles(0, math.rad(90), 0), rgb(46, 30, 52), m, Parts.material("RoofShingles", M.Slate))
	Parts.wedge("RoofR", Vector3.new(d + 1, roofH, w / 2 + 0.5), roofBase * CFrame.new(w / 4, 0, 0) * CFrame.Angles(0, math.rad(-90), 0), rgb(46, 30, 52), m, Parts.material("RoofShingles", M.Slate))
	piece(m, "Chimney", Vector3.new(2, 6, 2), cf * CFrame.new(w / 3, h + 4, 6), rgb(80, 46, 46), M.Brick, true)
	-- Windows glow (no lights, neon reads fine with bloom).
	for _, x in { -4.5, 4.5 } do
		for _, y in { 4.5, 10.5 } do
			piece(m, "Window", Vector3.new(3, 3, 0.2), cf * CFrame.new(x, y, 3 - d / 2 - 0.1), glow, M.Neon)
			piece(m, "Mullion", Vector3.new(0.25, 3.1, 0.25), cf * CFrame.new(x, y, 3 - d / 2 - 0.25), rgb(20, 16, 24), M.Wood)
		end
	end
	piece(m, "Attic", Vector3.new(2, 2, 0.2), cf * CFrame.new(0, h + 2, 3 - d / 2 + 0.4), glow, M.Neon)
	piece(m, "Door", Vector3.new(3.4, 6, 0.3), cf * CFrame.new(0, 3, 3 - d / 2 - 0.15), rgb(60, 24, 30), M.Wood)
	-- Porch deck, steps, roof on posts.
	local porchDepth = 5
	local porchZ = 3 - d / 2 - porchDepth / 2
	piece(m, "PorchDeck", Vector3.new(w, 0.8, porchDepth), cf * CFrame.new(0, 0.4, porchZ), rgb(86, 58, 44), M.WoodPlanks, true)
	piece(m, "PorchRoof", Vector3.new(w + 1, 0.5, porchDepth + 1), cf * CFrame.new(0, 7.2, porchZ), rgb(46, 30, 52), Parts.material("RoofShingles", M.Slate), true)
	for _, x in { -w / 2 + 0.5, w / 2 - 0.5 } do
		piece(m, "PorchPost", Vector3.new(0.5, 6.6, 0.5), cf * CFrame.new(x, 3.8, porchZ - porchDepth / 2 + 0.4), rgb(230, 222, 210), M.Wood, true)
	end
	Props.jackOLantern(m, cf * CFrame.new(-3.5, 0.8, porchZ - 1) * CFrame.Angles(0, math.rad(180), 0), 0.8)
	Props.jackOLantern(m, cf * CFrame.new(3.5, 0.8, porchZ - 1) * CFrame.Angles(0, math.rad(180), 0), 0.8)
	return m
end

-- DoorDash-red delivery van. Front faces cf.LookVector.
function Props.van(parent: Instance, cf: CFrame): Model
	local m = model("DeliveryVan", parent)
	local body = piece(m, "Body", Vector3.new(7, 6, 14), cf * CFrame.new(0, 4.2, 1), VAN_RED, M.SmoothPlastic, true)
	piece(m, "Hood", Vector3.new(7, 3.4, 3.4), cf * CFrame.new(0, 2.9, -7.7), VAN_RED, M.SmoothPlastic, true)
	piece(m, "Windshield", Vector3.new(6.4, 2.4, 0.2), cf * CFrame.new(0, 6, -5.6), rgb(120, 160, 220), M.Glass)
	piece(m, "Stripe", Vector3.new(7.1, 0.6, 14.1), cf * CFrame.new(0, 3.2, 1), rgb(255, 245, 235), M.SmoothPlastic)
	for _, x in { -3.6, 3.6 } do
		for _, z in { -6.5, 5 } do
			piece(m, "Wheel", Vector3.new(1.2, 3, 3), cf * CFrame.new(x, 1.5, z), rgb(24, 22, 26), M.SmoothPlastic, true, Enum.PartType.Cylinder)
		end
	end
	for _, x in { -2.5, 2.5 } do
		piece(m, "Headlight", Vector3.new(1.2, 0.8, 0.2), cf * CFrame.new(x, 3.2, -9.45), rgb(255, 246, 200), M.Neon)
	end
	-- Delivery bag on the roof, with a vampire-fang logo made of two white wedges.
	piece(m, "RoofBag", Vector3.new(3, 2.2, 3), cf * CFrame.new(0, 8.3, 2), rgb(200, 36, 30), M.Fabric)
	Parts.decal(body, Enum.NormalId.Right, "CRACKULA DASH", rgb(255, 250, 240))
	Parts.decal(body, Enum.NormalId.Left, "CRACKULA DASH", rgb(255, 250, 240))
	return m
end

-- Rugby goal posts (H shape). Posts straddle the path along cf.RightVector.
function Props.goalPosts(parent: Instance, cf: CFrame, span: number, padColor: Color3): Model
	local m = model("RugbyPosts", parent)
	local postH = 24
	for _, x in { -span / 2, span / 2 } do
		piece(m, "Post", Vector3.new(0.9, postH, 0.9), cf * CFrame.new(x, postH / 2, 0), rgb(240, 240, 240), M.SmoothPlastic, true)
		piece(m, "Pad", Vector3.new(2, 5, 2), cf * CFrame.new(x, 2.5, 0), padColor, M.Fabric, true)
	end
	piece(m, "Crossbar", Vector3.new(span, 0.8, 0.8), cf * CFrame.new(0, 10, 0), rgb(240, 240, 240), M.SmoothPlastic, true)
	return m
end

-- Gothic manor gate: two towers, a wall, and an arch the path runs through.
function Props.manorGate(parent: Instance, cf: CFrame, opening: number): Model
	local m = model("ManorGate", parent)
	local stone = rgb(64, 58, 74)
	local towerX = opening / 2 + 3
	for _, x in { -towerX, towerX } do
		piece(m, "Tower", Vector3.new(6, 24, 6), cf * CFrame.new(x, 12, 0), stone, M.Cobblestone, true)
		piece(m, "Spire", Vector3.new(4.5, 6, 4.5), cf * CFrame.new(x, 27, 0), rgb(40, 28, 50), Parts.material("RoofShingles", M.Slate))
		piece(m, "Tip", Vector3.new(1.4, 3, 1.4), cf * CFrame.new(x, 31.5, 0), rgb(40, 28, 50), M.Slate)
		for _, y in { 9, 16 } do
			piece(m, "Slit", Vector3.new(1, 2.4, 0.2), cf * CFrame.new(x, y, -3.1), rgb(255, 60, 80), M.Neon)
		end
		for _, mx in { -2.2, 0, 2.2 } do
			piece(m, "Merlon", Vector3.new(1.2, 1.4, 6), cf * CFrame.new(x + mx, 24.7, 0), stone, M.Cobblestone)
		end
	end
	piece(m, "Lintel", Vector3.new(opening, 5, 4), cf * CFrame.new(0, 19.5, 0), stone, M.Cobblestone, true)
	-- Iron portcullis teeth, raised (decor only, path stays open).
	for i = -3, 3 do
		piece(m, "Tooth", Vector3.new(0.3, 2.5, 0.3), cf * CFrame.new(i * (opening / 8), 15.8, -1.6), IRON, M.Metal)
	end
	for _, side in { -1, 1 } do
		piece(m, "Wall", Vector3.new(14, 10, 2), cf * CFrame.new(side * (towerX + 10), 5, 0), stone, M.Cobblestone, true)
	end
	return m
end

-- Big moon in the sky from parts: a glowing disc with a halo and craters.
function Props.moon(parent: Instance, position: Vector3, size: number): Model
	local m = model("Moon", parent)
	local face = CFrame.lookAt(position, Vector3.new(0, position.Y * 0.2, 0))
	piece(m, "MoonBall", Vector3.new(size, size, size), face, rgb(255, 244, 210), M.Neon, false, Enum.PartType.Ball)
	local halo = piece(m, "Halo", Vector3.new(size * 1.35, size * 1.35, size * 1.35), face, rgb(200, 170, 255), M.Neon, false, Enum.PartType.Ball)
	halo.Transparency = 0.85
	for _, c in { { -0.2, 0.15, 0.16 }, { 0.18, -0.1, 0.12 }, { 0.05, 0.25, 0.08 }, { -0.1, -0.25, 0.1 } } do
		local craterSize = size * c[3]
		piece(m, "Crater", Vector3.new(craterSize, craterSize, craterSize), face * CFrame.new(c[1] * size, c[2] * size, -size * 0.44), rgb(232, 214, 180), M.SmoothPlastic, false, Enum.PartType.Ball)
	end
	return m
end

-- A cute bat: body, two wings, two red eyes. The client flaps and circles it.
function Props.bat(parent: Instance, cf: CFrame): Model
	local m = model("Bat", parent)
	local body = piece(m, "Body", Vector3.new(0.9, 0.9, 1.3), cf, rgb(24, 18, 30), M.SmoothPlastic, false, Enum.PartType.Ball)
	m.PrimaryPart = body
	for _, side in { -1, 1 } do
		local wing = piece(m, if side < 0 then "WingL" else "WingR", Vector3.new(1.8, 0.12, 1), cf * CFrame.new(side * 1.25, 0, 0), rgb(36, 24, 44), M.SmoothPlastic)
		wing:SetAttribute("Side", side)
		piece(m, "Eye", Vector3.new(0.16, 0.16, 0.1), cf * CFrame.new(side * 0.2, 0.15, -0.62), rgb(255, 60, 70), M.Neon)
	end
	return m
end

function Props.streetLine(parent: Instance, from: Vector3, to: Vector3, color: Color3): Part
	local delta = to - from
	local mid = (from + to) / 2
	return piece(parent, "Line", Vector3.new(0.6, 0.06, delta.Magnitude), CFrame.lookAt(mid, mid + delta), color, M.Neon)
end

return Props
