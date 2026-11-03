--!strict
-- Placeholder blockout. TODO(world-team): replace the parts with a real map.
-- Gameplay reads CourseLayout, not these colors. Kill volumes live here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CourseLayout = require(ReplicatedStorage.Shared.CourseLayout)
local Parts = require(script.Parent.Parts)

local World = {}

export type CourseParts = {
	id: string,
	displayName: string,
	payout: number,
	requiredTier: number,
	startPart: BasePart,
	checkpointPart: BasePart,
	finishPart: BasePart,
	gate: BasePart?,
}

local WOOD = Color3.fromRGB(138, 90, 56)
local STONE = Color3.fromRGB(54, 46, 64)
local LAVA = Color3.fromRGB(255, 94, 48)

local function placeAabb(
	name: string,
	bounds: any,
	color: Color3,
	parent: Instance,
	material: Enum.Material?
): Part
	return Parts.block({
		name = name,
		size = Vector3.new(bounds.sx, bounds.sy, bounds.sz),
		position = Vector3.new(bounds.x, bounds.y, bounds.z),
		color = color,
		parent = parent,
		material = material,
	})
end

local function lavaUnder(platforms: { any }, parent: Instance, name: string)
	local minX, maxX = math.huge, -math.huge
	local minZ, maxZ = math.huge, -math.huge
	for _, platform in platforms do
		minX = math.min(minX, platform.x - platform.width / 2)
		maxX = math.max(maxX, platform.x + platform.width / 2)
		minZ = math.min(minZ, platform.z - platform.depth / 2)
		maxZ = math.max(maxZ, platform.z + platform.depth / 2)
	end
	local pad = 10
	local part = Parts.block({
		name = name,
		size = Vector3.new((maxX - minX) + pad * 2, 2, (maxZ - minZ) + pad * 2),
		position = Vector3.new((minX + maxX) / 2, 0, (minZ + maxZ) / 2),
		color = LAVA,
		parent = parent,
		material = Enum.Material.Neon,
		transparency = 0.15,
	})
	part:SetAttribute("Role", "kill")
	return part
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

	local lobby = CourseLayout.Lobby()
	placeAabb("Lobby", lobby, STONE, folder, Enum.Material.Slate)

	local deck = CourseLayout.PorchDeck()
	placeAabb("PorchDeck", deck, WOOD, folder, Enum.Material.WoodPlanks)
	placeAabb("PorchWalkway", CourseLayout.PorchWalkway(), WOOD, folder, Enum.Material.WoodPlanks)

	local bridge = CourseLayout.EastBridge()
	placeAabb("Stage2Bridge", bridge, Color3.fromRGB(90, 96, 120), folder, Enum.Material.Concrete)

	local courses: { CourseParts } = {}
	for _, spec in CourseLayout.All() do
		local platforms = CourseLayout.Platforms(spec)
		local record: CourseParts = {
			id = spec.id,
			displayName = spec.displayName,
			payout = spec.payout,
			requiredTier = spec.requiredTier,
			startPart = nil :: any,
			checkpointPart = nil :: any,
			finishPart = nil :: any,
			gate = nil,
		}
		for _, platform in platforms do
			local color = Parts.rgb(spec.color)
			if platform.role == "finish" then
				color = Parts.rgb(spec.finishColor)
			elseif platform.role == "checkpoint" then
				color = Parts.rgb(spec.checkpointColor)
			end
			local part = Parts.block({
				name = spec.id .. "_" .. platform.role .. "_" .. tostring(platform.index),
				size = Vector3.new(platform.width, platform.thickness, platform.depth),
				position = Vector3.new(platform.x, platform.yCenter, platform.z),
				color = color,
				parent = folder,
				material = if platform.role == "finish" or platform.role == "checkpoint"
					then Enum.Material.Neon
					else Enum.Material.SmoothPlastic,
			})
			part:SetAttribute("CourseId", spec.id)
			part:SetAttribute("Role", platform.role)
			part:SetAttribute("Index", platform.index)
			if platform.role == "start" then
				record.startPart = part
				Parts.billboard(part, spec.displayName .. "\nSTART", Vector3.new(0, 5, 0))
			elseif platform.role == "checkpoint" then
				record.checkpointPart = part
				Parts.billboard(part, "CHECKPOINT", Vector3.new(0, 4, 0))
			elseif platform.role == "finish" then
				record.finishPart = part
				Parts.billboard(
					part,
					"FINISH  +" .. tostring(spec.payout),
					Vector3.new(0, 5, 0),
					240
				)
			end
		end
		lavaUnder(platforms, folder, spec.id .. "_Lava")
		if spec.requiredTier > 0 then
			local first = platforms[1]
			local gate = Parts.block({
				name = spec.id .. "_Gate",
				size = Vector3.new(4, 18, math.max(16, first.depth + 4)),
				position = Vector3.new(
					first.x - first.width / 2 - 1,
					CourseLayout.BASE_TOP + 8,
					first.z
				),
				color = Color3.fromRGB(226, 64, 72),
				parent = folder,
				transparency = 0.55,
				canCollide = false,
			})
			gate:SetAttribute("CourseId", spec.id)
			gate:SetAttribute("Role", "gate")
			Parts.billboard(gate, "STAGE 2\nNeeds porch tier 1", Vector3.new(0, 6, 0), 260)
			record.gate = gate
		end
		table.insert(courses, record)
	end

	local voidKill = Parts.block({
		name = "VoidKill",
		size = Vector3.new(2000, 2, 2000),
		position = Vector3.new(0, -30, 80),
		color = Color3.fromRGB(40, 16, 18),
		parent = folder,
		canCollide = true,
		transparency = 1,
	})
	voidKill:SetAttribute("Role", "kill")

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Enabled = true
	spawn.Duration = 2
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Color = Color3.fromRGB(255, 214, 140)
	spawn.Material = Enum.Material.Neon
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.BottomSurface = Enum.SurfaceType.Smooth
	local spawnPos = Vector3.new(0, CourseLayout.BASE_TOP + 0.5, -8)
	spawn.CFrame = CFrame.lookAt(spawnPos, spawnPos + Vector3.new(0, 0, 10))
	spawn.Parent = workspace

	local title = Parts.block({
		name = "TitlePost",
		size = Vector3.new(2, 8, 2),
		position = Vector3.new(-18, CourseLayout.BASE_TOP + 4, -8),
		color = Color3.fromRGB(226, 48, 42),
		parent = folder,
		material = Enum.Material.Neon,
	})
	Parts.billboard(title, "COUNT CRACKULA\nSore-Foot Shift", Vector3.new(0, 6, 0), 280)

	local north = Vector3.new(0, CourseLayout.BASE_TOP + 3, lobby.z + lobby.sz / 2 - 4)
	local northMark = Parts.block({
		name = "SignSuburbs",
		size = Vector3.new(4, 4, 1),
		position = north,
		color = Color3.fromRGB(86, 168, 92),
		parent = folder,
	})
	Parts.billboard(northMark, "SUBURBS DELIVERY\n7 jumps  ·  +50", Vector3.new(0, 4, 0), 260)

	local eastMark = Parts.block({
		name = "SignStage2",
		size = Vector3.new(1, 4, 4),
		position = Vector3.new(lobby.x + lobby.sx / 2 - 4, CourseLayout.BASE_TOP + 3, 0),
		color = Color3.fromRGB(78, 88, 122),
		parent = folder,
	})
	Parts.billboard(eastMark, "STAGE 2  →\n+150  ·  tier 1", Vector3.new(0, 4, 0), 240)

	local westMark = Parts.block({
		name = "SignPorch",
		size = Vector3.new(1, 4, 4),
		position = Vector3.new(lobby.x - lobby.sx / 2 + 4, CourseLayout.BASE_TOP + 3, 0),
		color = WOOD,
		parent = folder,
	})
	Parts.billboard(westMark, "PORCH  ←\n50 / 100 / 150", Vector3.new(0, 4, 0), 240)

	return {
		folder = folder,
		courses = courses,
		spawn = spawn,
		spawnCFrame = Parts.standCFrame(spawn),
	}
end

function World.HookKills(folder: Instance)
	local function hook(part: Instance)
		if not part:IsA("BasePart") or part:GetAttribute("Role") ~= "kill" then
			return
		end
		part.Touched:Connect(function(hit)
			local player = Parts.playerFromHit(hit)
			if not player or not player.Character then
				return
			end
			local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				humanoid.Health = 0
			end
		end)
	end
	for _, child in folder:GetChildren() do
		hook(child)
	end
end

return World
