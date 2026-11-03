--!strict
-- Builds the whole map at runtime from CourseLayout: the moonlit lobby plaza,
-- one approach + entrance sign per course, the courses, kill floors, gates,
-- graveyard scatter, a moon, and bats. Gameplay reads CourseLayout and the
-- CourseId / Role attributes (start, checkpoint, finish, kill, gate, rescue).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CourseLayout = require(ReplicatedStorage.Shared.CourseLayout)
local Parts = require(script.Parent.Parts)
local Props = require(script.Props)
local Obstacles = require(script.Obstacles)

local World = {}

export type CourseParts = {
	id: string,
	displayName: string,
	payout: number,
	requiredTier: number,
	lockHint: string,
	startPart: BasePart,
	checkpointPart: BasePart,
	checkpointParts: { BasePart },
	finishPart: BasePart,
	gate: BasePart?,
}

local rgb = Color3.fromRGB
local M = Enum.Material
local TOP = CourseLayout.BASE_TOP

local PLAZA = rgb(62, 56, 72)
local PATH = rgb(92, 84, 100)
local WOOD = rgb(96, 64, 50)
local PURPLE = rgb(170, 80, 255)
local RED = rgb(255, 50, 70)

local function placeAabb(name: string, bounds: any, color: Color3, parent: Instance, material: Enum.Material?): Part
	return Parts.block({
		name = name,
		size = Vector3.new(bounds.sx, bounds.sy, bounds.sz),
		position = Vector3.new(bounds.x, bounds.y, bounds.z),
		color = color,
		parent = parent,
		material = material,
	})
end

local function foundation(name: string, bounds: any, color: Color3, parent: Instance, material: Enum.Material)
	local bottom = CourseLayout.GROUND_TOP
	local top = bounds.y - bounds.sy / 2
	Parts.block({
		name = name,
		size = Vector3.new(bounds.sx - 0.2, top - bottom, bounds.sz - 0.2),
		position = Vector3.new(bounds.x, bottom + (top - bottom) / 2, bounds.z),
		color = color,
		parent = parent,
		material = material,
	})
end

local function facingCf(x: number, y: number, z: number, lookX: number, lookZ: number): CFrame
	local pos = Vector3.new(x, y, z)
	return CFrame.lookAt(pos, pos + Vector3.new(lookX, 0, lookZ))
end

local function buildLobby(folder: Instance)
	local lobby = CourseLayout.Lobby()
	local slab = placeAabb("Lobby", lobby, PLAZA, folder, M.Cobblestone)
	slab:SetAttribute("Role", "lobby")
	foundation("LobbyCliff", lobby, rgb(44, 38, 52), folder, M.Rock)

	-- Cross-shaped paths, embedded so they never trip anyone.
	local halfX, halfZ = lobby.sx / 2, lobby.sz / 2
	Parts.block({ name = "PathNS", size = Vector3.new(12, 0.2, lobby.sz), position = Vector3.new(0, TOP, 0), color = PATH, parent = folder, material = M.Pavement, decor = true })
	Parts.block({ name = "PathEW", size = Vector3.new(lobby.sx, 0.2, 12), position = Vector3.new(0, TOP, 0), color = PATH, parent = folder, material = M.Pavement, decor = true })

	-- Porch side (west).
	local deck = CourseLayout.PorchDeck()
	placeAabb("PorchDeck", deck, WOOD, folder, M.WoodPlanks)
	foundation("PorchStilts", deck, rgb(50, 36, 32), folder, M.Wood)
	placeAabb("PorchWalkway", CourseLayout.PorchWalkway(), WOOD, folder, M.WoodPlanks)

	-- Iron fence around the plaza with openings at the four exits.
	local inset = 0.6
	local fenceY = TOP
	local openings = { north = 9, south = 11, east = 10, west = 9 }
	local nz, sz = halfZ - inset, -halfZ + inset
	local ex, wx = halfX - inset, -halfX + inset
	Props.fence(folder, Vector3.new(wx, fenceY, nz), Vector3.new(-openings.north, fenceY, nz))
	Props.fence(folder, Vector3.new(openings.north, fenceY, nz), Vector3.new(ex, fenceY, nz))
	Props.fence(folder, Vector3.new(wx, fenceY, sz), Vector3.new(-openings.south, fenceY, sz))
	Props.fence(folder, Vector3.new(openings.south, fenceY, sz), Vector3.new(ex, fenceY, sz))
	Props.fence(folder, Vector3.new(ex, fenceY, sz), Vector3.new(ex, fenceY, -openings.east))
	Props.fence(folder, Vector3.new(ex, fenceY, openings.east), Vector3.new(ex, fenceY, nz))
	Props.fence(folder, Vector3.new(wx, fenceY, sz), Vector3.new(wx, fenceY, -openings.west))
	Props.fence(folder, Vector3.new(wx, fenceY, openings.west), Vector3.new(wx, fenceY, nz))

	-- Haunted street (north half): two houses facing the path, mailboxes, pumpkins.
	Props.house(folder, facingCf(-24, TOP, 36, 1, 0), rgb(70, 62, 92), rgb(255, 160, 60))
	Props.house(folder, facingCf(24, TOP, 36, -1, 0), rgb(62, 80, 78), rgb(170, 110, 255))
	Props.mailbox(folder, facingCf(-9, TOP, 30, 1, 0))
	Props.mailbox(folder, facingCf(9, TOP, 42, -1, 0))
	for z = 12, 48, 12 do
		Props.jackOLantern(folder, facingCf(-7.5, TOP, z, 1, 0), 0.9)
		Props.jackOLantern(folder, facingCf(7.5, TOP, z + 6, -1, 0), 0.9)
	end
	Props.lampPost(folder, facingCf(-9, TOP, 20, 1, 0), PURPLE)
	Props.lampPost(folder, facingCf(9, TOP, 48, -1, 0), rgb(255, 150, 60))

	-- Spawn circle: candles in a ring and four lit candelabras.
	local sx, szSpawn = CourseLayout.SpawnPoint()
	for i = 0, 9 do
		local angle = i / 10 * math.pi * 2
		local pos = Vector3.new(sx + math.cos(angle) * 7, TOP, szSpawn + math.sin(angle) * 7)
		Parts.block({ name = "RingCandle", size = Vector3.new(0.5, 1, 0.5), position = pos + Vector3.new(0, 0.5, 0), color = rgb(246, 236, 220), parent = folder, decor = true })
		Parts.block({ name = "RingFlame", size = Vector3.new(0.35, 0.5, 0.35), position = pos + Vector3.new(0, 1.3, 0), color = rgb(190, 110, 255), parent = folder, material = M.Neon, decor = true })
	end
	for _, spot in { { -10, -16 }, { 10, -16 }, { -10, 4 }, { 10, 4 } } do
		Props.candelabra(folder, facingCf(spot[1], TOP, spot[2], 0, 1), true)
	end

	-- DoorDash-red delivery van parked west of spawn, side facing the spawn.
	Props.van(folder, facingCf(-24, TOP, -18, 0, 1))
	Props.lampPost(folder, facingCf(-16, TOP, -32, 0, 1), RED)

	-- Graveyard corner (south-east): tombstones with goofy epitaphs.
	local epitaphs = { "RIP my feet", "BRB delivering", "Here lies my ankles", "Out for delivery", "Tip your driver", "Scrum-diddly" }
	local index = 0
	for row = 0, 1 do
		for col = 0, 2 do
			index += 1
			Props.tombstone(folder, facingCf(20 + col * 7, TOP, -36 - row * 8, 0, 1), epitaphs[index])
		end
	end
	Props.deadTree(folder, facingCf(39, TOP, -48, 0, 1), 16)
	Props.lampPost(folder, facingCf(16, TOP, -32, 0, 1), rgb(90, 255, 150))

	-- Crypt corner (south-west): coffins and a candelabra.
	Props.coffin(folder, facingCf(-36, TOP, -44, 0, 1), false)
	Props.coffin(folder, facingCf(-30, TOP, -44, 0, 1), true)
	Props.coffin(folder, facingCf(-24, TOP, -46, 0, 1), false)
	Props.candelabra(folder, facingCf(-38, TOP, -36, 0, 1), false)

	-- Dead trees in the north corners.
	Props.deadTree(folder, facingCf(-40, TOP, 50, 0, 1), 18)
	Props.deadTree(folder, facingCf(40, TOP, 50, 0, 1), 15)

	-- East side: rugby goal posts frame the Stage 2 exit.
	Props.goalPosts(folder, facingCf(halfX - 2, TOP, 0, 1, 0), 18, rgb(60, 200, 120))
	Props.lampPost(folder, facingCf(34, TOP, -8, -1, 0), rgb(90, 255, 150))
	Props.lampPost(folder, facingCf(34, TOP, 8, -1, 0), rgb(90, 255, 150))

	-- South side: the manor gate the Stage 3 path runs through.
	local gate = Props.manorGate(folder, facingCf(0, TOP, -halfZ + 3, 0, 1), 20)
	local lintel = gate:FindFirstChild("Lintel")
	if lintel and lintel:IsA("BasePart") then
		Parts.decal(lintel, Enum.NormalId.Front, "COUNT CRACKULA'S MANOR", rgb(255, 90, 110))
	end

	-- West: porch sign over the walkway.
	local porchPos = Vector3.new(-halfX + 2, TOP + 9, 0)
	for _, z in { -8.6, 8.6 } do
		Parts.block({ name = "PorchArchPost", size = Vector3.new(0.8, 11, 0.8), position = Vector3.new(porchPos.X, TOP + 5.5, z), color = rgb(28, 26, 34), parent = folder, material = M.Metal })
	end
	Parts.sign({
		name = "SignPorch",
		parent = folder,
		cframe = CFrame.lookAt(porchPos, porchPos + Vector3.new(1, 0, 0)),
		width = 16,
		height = 3.6,
		title = "YOUR PORCH",
		subtitle = "Bench 50 · Ice Bath 100 · Bag Shrine 150 · Crypt Key",
		ink = rgb(255, 180, 90),
		glow = rgb(255, 120, 40),
	})
end

local function buildEntrance(spec: CourseLayout.CourseSpec, folder: Instance)
	local approach = CourseLayout.Approach(spec)
	local path = placeAabb(spec.id .. "_Approach", approach, PATH, folder, M.Pavement)
	path:SetAttribute("CourseId", spec.id)
	path:SetAttribute("Role", "approach")
	foundation(spec.id .. "_ApproachPier", approach, rgb(44, 38, 52), folder, M.Rock)

	local sign = CourseLayout.EntranceSign(spec)
	local signPos = Vector3.new(sign.x, sign.y, sign.z)
	local signCf = CFrame.lookAt(signPos, signPos + Vector3.new(sign.faceX, 0, sign.faceZ))
	local accent = Parts.rgb(spec.palette.accent)
	-- North and porch exits get their own posts; east uses the goal posts, south the manor gate.
	if spec.heading == "north" then
		for _, side in { -1, 1 } do
			local postPos = signPos + signCf.RightVector * (side * (sign.width / 2 + 0.6))
			Parts.block({ name = "ArchPost", size = Vector3.new(1, sign.y - TOP + 3, 1), position = Vector3.new(postPos.X, TOP + (sign.y - TOP + 3) / 2, postPos.Z), color = rgb(28, 26, 34), parent = folder, material = M.Metal })
			Parts.block({ name = "ArchFinial", size = Vector3.new(1.6, 1.6, 1.6), position = Vector3.new(postPos.X, sign.y + 3.8, postPos.Z), color = accent, parent = folder, material = M.Neon, shape = Enum.PartType.Ball, decor = true })
		end
	end
	local subtitle = "+" .. tostring(spec.payout) .. " cash · " .. tostring(CourseLayout.ObstacleCount(spec)) .. " obstacles"
	if spec.requiredTier > 0 then
		subtitle ..= " · " .. spec.lockHint
	else
		subtitle ..= " · " .. spec.tagline
	end
	Parts.sign({
		name = "Sign_" .. spec.id,
		parent = folder,
		cframe = signCf,
		width = sign.width,
		height = sign.height,
		title = string.upper(spec.displayName),
		subtitle = subtitle,
		ink = accent,
		glow = Parts.rgb(spec.palette.kill):Lerp(Color3.new(0, 0, 0), 0.4),
		backText = "BACK TO THE MANOR",
	})
end

local function buildCourse(spec: CourseLayout.CourseSpec, folder: Instance): CourseParts
	local courseFolder = Instance.new("Folder")
	courseFolder.Name = "Course_" .. spec.id
	courseFolder.Parent = folder

	local record: CourseParts = {
		id = spec.id,
		displayName = spec.displayName,
		payout = spec.payout,
		requiredTier = spec.requiredTier,
		lockHint = spec.lockHint,
		startPart = nil :: any,
		checkpointPart = nil :: any,
		checkpointParts = {},
		finishPart = nil :: any,
		gate = nil,
	}
	local platforms = CourseLayout.Platforms(spec)
	for _, platform in platforms do
		local part = Obstacles.Build(spec, platform, courseFolder)
		if platform.role == "start" then
			record.startPart = part
		elseif platform.role == "checkpoint" then
			table.insert(record.checkpointParts, part)
		elseif platform.role == "finish" then
			record.finishPart = part
		end
	end
	record.checkpointPart = record.checkpointParts[1]
	Obstacles.KillFloor(spec, courseFolder)

	if spec.requiredTier > 0 then
		local first = platforms[1]
		local hd = CourseLayout.Heading(spec)
		local facing = Vector3.new(hd.fx, 0, hd.fz)
		local x, z = CourseLayout.ToWorld(spec, first.forward - first.depth / 2 - 1, first.lat)
		local pos = Vector3.new(x, TOP + 7, z)
		local gate = Parts.block({
			name = spec.id .. "_Gate",
			size = Vector3.new(first.width + 4, 14, 1),
			cframe = CFrame.lookAt(pos, pos + facing),
			color = Parts.rgb(spec.palette.accent),
			parent = courseFolder,
			material = M.ForceField,
			transparency = 0.2,
			canCollide = false,
		})
		gate:SetAttribute("CourseId", spec.id)
		gate:SetAttribute("Role", "gate")
		gate.CastShadow = false
		record.gate = gate
	end

	-- A few themed props along the outside of each course, on the ground.
	local rng = Random.new(#spec.id * 97 + spec.payout)
	local hd = CourseLayout.Heading(spec)
	local last = platforms[#platforms]
	for forward = 20, last.forward, 22 do
		for _, side in { -1, 1 } do
			local lat = side * rng:NextNumber(26, 34)
			local x, z = CourseLayout.ToWorld(spec, forward + rng:NextNumber(-4, 4), lat)
			local cf = facingCf(x, CourseLayout.GROUND_TOP, z, -hd.rx * side, -hd.rz * side)
			if spec.id == "suburbs" then
				if rng:NextNumber() < 0.5 then
					Props.jackOLantern(courseFolder, cf, 1.6)
				else
					Props.deadTree(courseFolder, cf, rng:NextNumber(12, 20))
				end
			elseif spec.id == "stage2" then
				if rng:NextNumber() < 0.6 then
					Props.tombstone(courseFolder, cf, nil, rng:NextNumber(3, 5))
				else
					Props.coffin(courseFolder, cf, true)
				end
			elseif rng:NextNumber() < 0.5 then
				Props.coffin(courseFolder, cf, true)
			else
				Props.deadTree(courseFolder, cf, rng:NextNumber(14, 24))
			end
		end
	end
	return record
end

local function scatter(folder: Instance)
	local rng = Random.new(1337)
	local keepOut: { CourseLayout.Aabb } = {}
	local lobby = CourseLayout.Lobby()
	table.insert(keepOut, { x = lobby.x, z = lobby.z, sx = lobby.sx + 10, sz = lobby.sz + 10 })
	local deck = CourseLayout.PorchDeck()
	table.insert(keepOut, { x = deck.x, z = deck.z, sx = deck.sx + 10, sz = deck.sz + 10 })
	for _, spec in CourseLayout.All() do
		table.insert(keepOut, CourseLayout.CourseBounds(spec, 14))
	end
	local placed = 0
	local tries = 0
	while placed < 70 and tries < 600 do
		tries += 1
		local x = rng:NextNumber(-170, 170)
		local z = rng:NextNumber(-170, 170)
		local blocked = false
		for _, box in keepOut do
			if CourseLayout.Contains(box, x, z, 2) then
				blocked = true
				break
			end
		end
		if not blocked then
			placed += 1
			local cf = CFrame.new(x, CourseLayout.GROUND_TOP, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			local roll = rng:NextNumber()
			if roll < 0.4 then
				Props.tombstone(folder, cf, nil, rng:NextNumber(2.6, 4.2))
			elseif roll < 0.75 then
				Props.deadTree(folder, cf, rng:NextNumber(12, 22))
			elseif roll < 0.9 then
				Props.jackOLantern(folder, cf, rng:NextNumber(1, 2))
			else
				Props.coffin(folder, cf, rng:NextNumber() < 0.5)
			end
		end
	end
end

local function buildSky(folder: Instance)
	Props.moon(folder, Vector3.new(-170, 190, 360), 64)
	local bats = Instance.new("Folder")
	bats.Name = "Bats"
	bats.Parent = folder
	local rng = Random.new(42)
	local centers = {
		Vector3.new(0, TOP + 34, 10),
		Vector3.new(0, TOP + 40, 150),
		Vector3.new(150, TOP + 40, 0),
		Vector3.new(0, TOP + 40, -150),
		Vector3.new(-24, TOP + 30, 36),
	}
	for i = 1, 14 do
		local center = centers[(i - 1) % #centers + 1]
		local bat = Props.bat(bats, CFrame.new(center + Vector3.new(rng:NextNumber(-10, 10), rng:NextNumber(-4, 4), rng:NextNumber(-10, 10))))
		bat:SetAttribute("Center", center)
		bat:SetAttribute("Radius", rng:NextNumber(10, 26))
		bat:SetAttribute("Speed", rng:NextNumber(0.5, 1.1) * (if rng:NextNumber() < 0.5 then -1 else 1))
		bat:SetAttribute("Phase", rng:NextNumber(0, math.pi * 2))
		bat:SetAttribute("Bob", rng:NextNumber(1, 3))
	end
end

function World.Build(): {
	folder: Folder,
	courses: { CourseParts },
	spawn: SpawnLocation,
	spawnCFrame: CFrame,
}
	local folder = Instance.new("Folder")
	folder.Name = "CountCrackulaMap"
	folder.Parent = workspace

	local groundPart = Parts.block({
		name = "GraveyardGround",
		size = Vector3.new(1200, 2, 1200),
		position = Vector3.new(0, CourseLayout.GROUND_TOP - 1, 60),
		color = rgb(34, 44, 38),
		parent = folder,
		material = M.Grass,
	})
	groundPart:SetAttribute("Role", "rescue")

	buildLobby(folder)

	local courses: { CourseParts } = {}
	for _, spec in CourseLayout.All() do
		buildEntrance(spec, folder)
		table.insert(courses, buildCourse(spec, folder))
	end

	scatter(folder)
	buildSky(folder)

	local voidKill = Parts.block({
		name = "VoidKill",
		size = Vector3.new(2400, 2, 2400),
		position = Vector3.new(0, -30, 80),
		color = rgb(20, 10, 20),
		parent = folder,
		transparency = 1,
	})
	voidKill:SetAttribute("Role", "kill")

	local spawnX, spawnZ = CourseLayout.SpawnPoint()
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Enabled = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Color = rgb(140, 60, 220)
	spawn.Material = M.Neon
	spawn.Transparency = 0.15
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.BottomSurface = Enum.SurfaceType.Smooth
	local spawnPos = Vector3.new(spawnX, TOP + 0.5, spawnZ)
	spawn.CFrame = CFrame.lookAt(spawnPos, spawnPos + Vector3.new(0, 0, 10))
	spawn:SetAttribute("Facing", Vector3.new(0, 0, 1))
	spawn.Parent = workspace

	return {
		folder = folder,
		courses = courses,
		spawn = spawn,
		spawnCFrame = Parts.standCFrame(spawn),
	}
end

local function killHumanoid(hit: BasePart)
	local player = Parts.playerFromHit(hit)
	if not player or not player.Character then
		return
	end
	local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = 0
	end
end

function World.HookKills(folder: Instance)
	local function hook(part: Instance)
		if not part:IsA("BasePart") or part:GetAttribute("Role") ~= "kill" then
			return
		end
		part.Touched:Connect(killHumanoid)
	end
	for _, child in folder:GetDescendants() do
		hook(child)
	end
end

-- The ground under everything sends a fallen player back (checkpoint or spawn)
-- without a death, so stepping off the plaza is not a punishment.
function World.HookRescue(folder: Instance, rescue: (Player) -> ())
	local last: { [number]: number } = {}
	for _, part in folder:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute("Role") == "rescue" then
			part.Touched:Connect(function(hit)
				local player = Parts.playerFromHit(hit)
				if not player then
					return
				end
				local now = os.clock()
				if now - (last[player.UserId] or 0) < 1 then
					return
				end
				last[player.UserId] = now
				rescue(player)
			end)
		end
	end
end

return World
