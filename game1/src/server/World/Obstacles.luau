--!strict
-- Builds one CourseLayout platform as Parts and wires its behaviour:
--   mover    anchored part tweened by TweenService; a Heartbeat loop copies the
--            tween's speed into AssemblyLinearVelocity so riders are carried.
--   spinner  anchored hub + kill bar on a motorised HingeConstraint.
--   vanish   fades and goes non-solid when stepped on, then comes back.
--   conveyor anchored part with a constant sideways AssemblyLinearVelocity.
--   hurdles  thin neon kill strips across the platform to hop over.
--   ledge    small step with a tall wall on its outer side (wall-climb look).

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CourseLayout = require(ReplicatedStorage.Shared.CourseLayout)
local Parts = require(script.Parent.Parent.Parts)
local Props = require(script.Parent.Props)

local Obstacles = {}

local rgb = Color3.fromRGB
local M = Enum.Material
local UP = Vector3.new(0, 1, 0)

type Frame = {
	center: Vector3,
	facing: Vector3,
	right: Vector3,
	rot: CFrame,
}

local movers: { { part: BasePart, last: Vector3 } } = {}
local motionStarted = false

local function frameOf(spec: CourseLayout.CourseSpec, platform: CourseLayout.Platform): Frame
	local hd = CourseLayout.Heading(spec)
	local facing = Vector3.new(hd.fx, 0, hd.fz)
	local right = Vector3.new(hd.rx, 0, hd.rz)
	return {
		center = Vector3.new(platform.x, platform.yCenter, platform.z),
		facing = facing,
		right = right,
		rot = CFrame.lookAt(Vector3.zero, facing),
	}
end

local function at(frame: Frame, f: number, l: number, y: number): CFrame
	return CFrame.new(frame.center + frame.facing * f + frame.right * l + UP * y) * frame.rot
end

local function lookMaterial(look: string, fallback: Enum.Material): Enum.Material
	if look == "lawn" or look == "pitch" or look == "sprinkler" then
		return M.Grass
	elseif look == "porch" or look == "fence" then
		return M.WoodPlanks
	elseif look == "box" then
		return Parts.material("Cardboard", M.WoodPlanks)
	elseif look == "sidewalk" or look == "drone" then
		return M.Concrete
	elseif look == "roof" then
		return Parts.material("RoofShingles", M.Slate)
	elseif look == "tombstone" or look == "tombwall" or look == "tacklebar" then
		return M.Slate
	elseif look == "coffin" then
		return M.Wood
	elseif look == "crossbar" then
		return M.SmoothPlastic
	elseif look == "ghost" then
		return M.Glass
	elseif look == "scrum" then
		return M.Fabric
	elseif look == "rugbyball" then
		return Parts.material("Leather", M.Fabric)
	elseif look == "crypt" or look == "candle" or look == "candelabra" then
		return M.Cobblestone
	elseif look == "chain" then
		return M.DiamondPlate
	elseif look == "cracked" then
		return M.Slate
	elseif look == "brick" then
		return M.Brick
	elseif look == "lavabelt" then
		return M.Basalt
	elseif look == "sarcophagus" then
		return M.Marble
	end
	return fallback
end

local function lookColor(look: string, palette: CourseLayout.Palette): Color3
	if look == "porch" then
		return rgb(110, 74, 52)
	elseif look == "fence" or look == "crossbar" then
		return Parts.rgb(palette.trim)
	elseif look == "pumpkin" then
		return rgb(255, 128, 28)
	elseif look == "box" then
		return rgb(176, 132, 88)
	elseif look == "sidewalk" or look == "drone" then
		return rgb(120, 118, 128)
	elseif look == "roof" then
		return rgb(66, 44, 74)
	elseif look == "coffin" then
		return rgb(86, 50, 40)
	elseif look == "ghost" then
		return rgb(220, 240, 255)
	elseif look == "scrum" then
		return rgb(40, 90, 60)
	elseif look == "rugbyball" then
		return rgb(150, 86, 44)
	elseif look == "chain" then
		return rgb(90, 88, 100)
	elseif look == "cracked" then
		return rgb(96, 70, 70)
	elseif look == "brick" then
		return rgb(100, 52, 52)
	elseif look == "sarcophagus" then
		return rgb(196, 178, 140)
	elseif look == "lavabelt" then
		return rgb(52, 44, 46)
	end
	return Parts.rgb(palette.base)
end

local function tag(part: BasePart, spec: CourseLayout.CourseSpec, platform: CourseLayout.Platform, frame: Frame)
	part:SetAttribute("CourseId", spec.id)
	part:SetAttribute("Role", platform.role)
	part:SetAttribute("Kind", platform.kind)
	part:SetAttribute("Index", platform.index)
	part:SetAttribute("Facing", frame.facing)
	if platform.role == "checkpoint" then
		part:SetAttribute("CheckpointNumber", platform.checkpointNumber)
	end
end

-- Decor that rides along with a moving root.
local function weldDecor(root: BasePart, decor: BasePart)
	decor.Anchored = false
	decor.Massless = true
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = decor
	weld.Parent = decor
end

local function rim(main: BasePart, frame: Frame, platform: CourseLayout.Platform, color: Color3, parent: Instance)
	local half = platform.thickness / 2
	local w, d = platform.width, platform.depth
	for _, edge in
		{
			{ 0, d / 2, w + 0.4, 0.4 },
			{ 0, -d / 2, w + 0.4, 0.4 },
			{ w / 2, 0, 0.4, d },
			{ -w / 2, 0, 0.4, d },
		}
	do
		local strip = Parts.block({
			name = "Rim",
			size = Vector3.new(edge[3], 0.5, edge[4]),
			cframe = at(frame, edge[2], edge[1], half - 0.2),
			color = color,
			parent = parent,
			material = M.Neon,
			decor = true,
		})
		if platform.move then
			weldDecor(main, strip)
		end
	end
end

local function pillar(frame: Frame, platform: CourseLayout.Platform, size: number, color: Color3, material: Enum.Material, parent: Instance)
	local bottom = CourseLayout.GROUND_TOP
	local top = platform.yTop - platform.thickness
	local height = top - bottom
	if height < 1 then
		return
	end
	Parts.block({
		name = "Pillar",
		size = Vector3.new(size, height, size),
		cframe = CFrame.new(Vector3.new(platform.x, bottom + height / 2, platform.z)) * frame.rot,
		color = color,
		parent = parent,
		material = material,
		decor = true,
	})
end

local function startMotion()
	if motionStarted then
		return
	end
	motionStarted = true
	RunService.Heartbeat:Connect(function(dt)
		if dt <= 0 then
			return
		end
		for _, entry in movers do
			local part = entry.part
			if part.Parent then
				local position = part.Position
				part.AssemblyLinearVelocity = (position - entry.last) / dt
				entry.last = position
			end
		end
	end)
end

local function makeMover(main: BasePart, frame: Frame, move: CourseLayout.Move)
	local axis = if move.axis == "f" then frame.facing elseif move.axis == "y" then UP else frame.right
	local base = main.CFrame
	local offset = axis * move.amp
	main.CFrame = base - offset
	local info = TweenInfo.new(move.period / 2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local ok, err = pcall(function()
		TweenService:Create(main, info, { CFrame = base + offset }):Play()
	end)
	if not ok then
		warn("[CountCrackula] mover tween failed: " .. tostring(err))
		main.CFrame = base
		return
	end
	table.insert(movers, { part = main, last = main.Position })
	startMotion()
end

local function makeSpinner(
	spec: CourseLayout.CourseSpec,
	platform: CourseLayout.Platform,
	frame: Frame,
	parent: Instance,
	color: Color3
)
	local barHeight = 2.4
	local hubHeight = barHeight + 0.5
	local hub = Parts.block({
		name = "SpinnerHub",
		size = Vector3.new(hubHeight, 1.6, 1.6),
		cframe = CFrame.new(Vector3.new(platform.x, platform.yTop + hubHeight / 2, platform.z))
			* CFrame.Angles(0, 0, math.rad(90)),
		color = rgb(40, 34, 46),
		parent = parent,
		material = M.Metal,
		shape = Enum.PartType.Cylinder,
	})
	local barLength = platform.width - 2
	local barCf = CFrame.new(Vector3.new(platform.x, platform.yTop + barHeight, platform.z)) * frame.rot
	local bar = Instance.new("Part")
	bar.Name = "SpinnerBar"
	bar.Size = Vector3.new(barLength, 1, 1)
	bar.CFrame = barCf
	bar.Color = color
	bar.Material = M.Neon
	bar.Anchored = false
	bar.CanCollide = false
	bar.CanTouch = true
	bar.CastShadow = false
	bar.TopSurface = Enum.SurfaceType.Smooth
	bar.BottomSurface = Enum.SurfaceType.Smooth
	bar:SetAttribute("Role", "kill")
	bar:SetAttribute("CourseId", spec.id)

	-- Attachment primary axis is +X; tilt it so the hinge turns about world up.
	local a0 = Instance.new("Attachment")
	a0.Name = "HingeBase"
	a0.Parent = hub
	local axisCf = CFrame.new(barCf.Position) * CFrame.Angles(0, 0, math.rad(90))
	a0.CFrame = hub.CFrame:ToObjectSpace(axisCf)
	local a1 = Instance.new("Attachment")
	a1.Name = "HingeBar"
	a1.Parent = bar
	a1.CFrame = barCf:ToObjectSpace(axisCf)
	local hinge = Instance.new("HingeConstraint")
	hinge.Attachment0 = a0
	hinge.Attachment1 = a1
	hinge.ActuatorType = Enum.ActuatorType.Motor
	hinge.AngularVelocity = platform.spin or 2
	hinge.MotorMaxTorque = 1e8
	hinge.MotorMaxAcceleration = 50
	hinge.Parent = bar
	bar.Parent = parent
	pcall(function()
		bar:SetNetworkOwner(nil)
	end)
	-- Tip caps so the bar ends read clearly.
	for _, side in { -1, 1 } do
		local cap = Parts.block({
			name = "BarCap",
			size = Vector3.new(1.3, 1.3, 1.3),
			cframe = barCf * CFrame.new(side * barLength / 2, 0, 0),
			color = rgb(255, 255, 255),
			parent = parent,
			material = M.Neon,
			shape = Enum.PartType.Ball,
			decor = true,
		})
		weldDecor(bar, cap)
	end
end

local function makeVanish(main: BasePart, parent: Instance)
	local busy = false
	local originalTransparency = main.Transparency
	local originalColor = main.Color
	main.Touched:Connect(function(hit)
		if busy or not Parts.playerFromHit(hit) then
			return
		end
		busy = true
		main.Color = rgb(255, 80, 90)
		local fade = TweenService:Create(main, TweenInfo.new(0.7, Enum.EasingStyle.Quad), { Transparency = 0.85 })
		fade:Play()
		task.delay(0.75, function()
			main.CanCollide = false
			for _, child in parent:GetChildren() do
				if child:IsA("BasePart") and child ~= main and child:GetAttribute("FadeWith") == main.Name then
					child.Transparency = 1
				end
			end
			task.delay(2.6, function()
				main.CanCollide = true
				main.Transparency = originalTransparency
				main.Color = originalColor
				for _, child in parent:GetChildren() do
					if child:IsA("BasePart") and child:GetAttribute("FadeWith") == main.Name then
						child.Transparency = 0
					end
				end
				busy = false
			end)
		end)
	end)
end

local function makeHurdles(platform: CourseLayout.Platform, frame: Frame, parent: Instance, color: Color3, spec: CourseLayout.CourseSpec)
	-- First strip sits 7 studs in: a max-length jump (8.7 studs minus the gap)
	-- can never land on it. Then one every 5 studs, leaving room to exit.
	local f = -platform.depth / 2 + 7
	while f <= platform.depth / 2 - 3.5 do
		local strip = Parts.block({
			name = "KillStrip",
			size = Vector3.new(platform.width, 0.7, 1.4),
			cframe = at(frame, f, 0, platform.thickness / 2 + 0.35),
			color = color,
			parent = parent,
			material = M.Neon,
			canCollide = false,
		})
		strip:SetAttribute("Role", "kill")
		strip:SetAttribute("CourseId", spec.id)
		f += 5
	end
end

local function makeConveyor(main: BasePart, platform: CourseLayout.Platform, frame: Frame, parent: Instance, color: Color3)
	local push = platform.push or 6
	main.AssemblyLinearVelocity = frame.right * push
	-- Chevrons point the way the belt pushes.
	for f = -platform.depth / 2 + 2, platform.depth / 2 - 2, 3 do
		for _, side in { -1, 1 } do
			local chevron = Parts.block({
				name = "Arrow",
				size = Vector3.new(0.4, 0.12, 2),
				cframe = at(frame, f, 0, platform.thickness / 2 + 0.02)
					* CFrame.Angles(0, math.rad(side * 40), 0),
				color = color,
				parent = parent,
				material = M.Neon,
				decor = true,
			})
			chevron.CFrame = chevron.CFrame + frame.facing * (side * 0.6)
		end
	end
end

local function decorate(spec: CourseLayout.CourseSpec, platform: CourseLayout.Platform, frame: Frame, main: Part, parent: Instance)
	local look = platform.look
	local palette = spec.palette
	local accent = Parts.rgb(palette.accent)
	local top = platform.thickness / 2
	if look == "pumpkin" then
		-- Turn the pad into a pumpkin top: a disc with a stem and a smile on its side.
		main.Shape = Enum.PartType.Cylinder
		main.Size = Vector3.new(platform.thickness, platform.depth, platform.width)
		main.CFrame = main.CFrame * CFrame.Angles(0, 0, math.rad(90))
		local stem = Parts.block({
			name = "Stem",
			size = Vector3.new(0.6, 1, 0.6),
			cframe = at(frame, 0, 0, top + 0.5),
			color = rgb(70, 110, 40),
			parent = parent,
			material = M.Wood,
			decor = true,
		})
		stem.CanCollide = false
		local face = Parts.block({
			name = "Smile",
			size = Vector3.new(2.4, 0.4, 0.2),
			cframe = at(frame, -platform.depth / 2 - 0.05, 0, -0.2),
			color = rgb(255, 210, 90),
			parent = parent,
			material = M.Neon,
			decor = true,
		})
		face.CanCollide = false
		pillar(frame, platform, 1.2, rgb(60, 90, 40), M.Wood, parent)
	elseif look == "tombstone" or look == "candle" then
		pillar(frame, platform, math.min(platform.width, platform.depth) - 0.4, main.Color:Lerp(Color3.new(0, 0, 0), 0.25), M.Slate, parent)
		if look == "candle" then
			for _, corner in { { 1, 1 }, { -1, -1 } } do
				local flame = Parts.block({
					name = "Flame",
					size = Vector3.new(0.4, 0.7, 0.4),
					cframe = at(frame, corner[1] * (platform.depth / 2 - 0.6), corner[2] * (platform.width / 2 - 0.6), top + 0.9),
					color = rgb(255, 190, 90),
					parent = parent,
					material = M.Neon,
					decor = true,
				})
				flame:SetAttribute("Flicker", true)
			end
		else
			Parts.decal(main, Enum.NormalId.Front, "RIP", rgb(40, 34, 50))
			Parts.decal(main, Enum.NormalId.Back, "RIP", rgb(40, 34, 50))
		end
	elseif look == "coffin" then
		local trim = Parts.block({
			name = "Trim",
			size = Vector3.new(platform.width + 0.2, 0.3, 0.6),
			cframe = at(frame, platform.depth * 0.25, 0, top - 0.1),
			color = Parts.rgb(palette.trim),
			parent = parent,
			material = M.Neon,
			decor = true,
		})
		if platform.move then
			weldDecor(main, trim)
		end
	elseif look == "drone" then
		for _, corner in { { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } do
			local prop = Parts.block({
				name = "Propeller",
				size = Vector3.new(0.3, 2.4, 2.4),
				cframe = at(frame, corner[1] * platform.depth / 2, corner[2] * platform.width / 2, -0.6)
					* CFrame.Angles(0, 0, math.rad(90)),
				color = accent,
				parent = parent,
				material = M.Neon,
				shape = Enum.PartType.Cylinder,
				decor = true,
			})
			weldDecor(main, prop)
		end
	elseif look == "fence" then
		for f = -platform.depth / 2 + 1, platform.depth / 2 - 1, 2 do
			for _, side in { -1, 1 } do
				Parts.block({
					name = "Picket",
					size = Vector3.new(0.3, 3, 0.5),
					cframe = at(frame, f, side * 1.3, -1),
					color = Parts.rgb(palette.trim),
					parent = parent,
					material = M.Wood,
					decor = true,
				})
			end
		end
	elseif look == "crossbar" then
		for _, f in { -platform.depth / 2, platform.depth / 2 } do
			Parts.block({
				name = "GoalPost",
				size = Vector3.new(0.8, 18, 0.8),
				cframe = at(frame, f, 0, -6),
				color = Parts.rgb(palette.trim),
				parent = parent,
				material = M.SmoothPlastic,
				decor = true,
			})
		end
	elseif look == "chain" then
		for f = -platform.depth / 2 + 1, platform.depth / 2 - 1, 2 do
			Parts.block({
				name = "Link",
				size = Vector3.new(0.2, 1, 1.4),
				cframe = at(frame, f, 0, -1.4),
				color = rgb(60, 58, 70),
				parent = parent,
				material = M.Metal,
				decor = true,
			})
		end
	elseif look == "ghost" then
		main.Transparency = 0.25
		for _, side in { -0.8, 0.8 } do
			local eye = Parts.block({
				name = "GhostEye",
				size = Vector3.new(0.6, 0.6, 0.1),
				cframe = at(frame, -platform.depth / 2 - 0.05, side, 0),
				color = rgb(20, 20, 30),
				parent = parent,
				material = M.SmoothPlastic,
				decor = true,
			})
			eye:SetAttribute("FadeWith", main.Name)
		end
	elseif look == "cracked" or look == "box" then
		local crack = Parts.block({
			name = "Crack",
			size = Vector3.new(0.3, 0.1, platform.depth * 0.8),
			cframe = at(frame, 0, 0, top + 0.02) * CFrame.Angles(0, math.rad(35), 0),
			color = if look == "cracked" then rgb(255, 90, 40) else rgb(120, 86, 56),
			parent = parent,
			material = if look == "cracked" then M.Neon else M.SmoothPlastic,
			decor = true,
		})
		crack:SetAttribute("FadeWith", main.Name)
	elseif look == "sarcophagus" then
		local lid = Parts.block({
			name = "Lid",
			size = Vector3.new(platform.width - 1, 0.4, platform.depth - 1),
			cframe = at(frame, 0, 0, -top - 0.4),
			color = rgb(255, 200, 70),
			parent = parent,
			material = M.Neon,
			decor = true,
		})
		weldDecor(main, lid)
	elseif look == "pitch" and platform.role == "jump" then
		for f = -platform.depth / 2 + 2, platform.depth / 2 - 2, 4 do
			Parts.block({
				name = "PitchLine",
				size = Vector3.new(platform.width, 0.06, 0.3),
				cframe = at(frame, f, 0, top + 0.03),
				color = rgb(240, 240, 240),
				parent = parent,
				material = M.SmoothPlastic,
				decor = true,
			})
		end
	end
end

local function checkpointDecor(spec: CourseLayout.CourseSpec, platform: CourseLayout.Platform, frame: Frame, main: BasePart, parent: Instance)
	local color = Parts.rgb(spec.palette.checkpoint)
	rim(main, frame, platform, color, parent)
	Parts.decal(main, Enum.NormalId.Top, "CHECKPOINT " .. tostring(platform.checkpointNumber), color)
	-- A small lantern on a post at one corner, out of the jump line.
	local postCf = at(frame, platform.depth / 2 - 1, platform.width / 2 - 1, platform.thickness / 2)
	Parts.block({
		name = "LanternPost",
		size = Vector3.new(0.4, 5, 0.4),
		cframe = postCf * CFrame.new(0, 2.5, 0),
		color = rgb(28, 26, 34),
		parent = parent,
		material = M.Metal,
		decor = true,
	})
	local lantern = Parts.block({
		name = "Lantern",
		size = Vector3.new(1, 1.3, 1),
		cframe = postCf * CFrame.new(0, 5.4, 0),
		color = color,
		parent = parent,
		material = M.Neon,
		decor = true,
	})
	Parts.light(lantern, color, 18, 1.4)
end

local function finishDecor(spec: CourseLayout.CourseSpec, platform: CourseLayout.Platform, frame: Frame, main: BasePart, parent: Instance)
	local color = Parts.rgb(spec.palette.finish)
	rim(main, frame, platform, color, parent)
	local half = platform.width / 2
	local archFront = platform.depth / 2 - 1.5
	for _, side in { -1, 1 } do
		Parts.block({
			name = "ArchPost",
			size = Vector3.new(1.2, 12, 1.2),
			cframe = at(frame, archFront, side * (half - 0.8), platform.thickness / 2 + 6),
			color = rgb(30, 24, 36),
			parent = parent,
			material = M.Metal,
		})
		local orb = Parts.block({
			name = "ArchOrb",
			size = Vector3.new(1.6, 1.6, 1.6),
			cframe = at(frame, archFront, side * (half - 0.8), platform.thickness / 2 + 12.6),
			color = color,
			parent = parent,
			material = M.Neon,
			shape = Enum.PartType.Ball,
			decor = true,
		})
		if side > 0 then
			Parts.light(orb, color, 24, 2)
		end
	end
	-- Banner faces back down the course, toward the runner.
	local bannerCf = CFrame.new((at(frame, archFront, 0, platform.thickness / 2 + 10)).Position)
		* CFrame.lookAt(Vector3.zero, -frame.facing)
	Parts.sign({
		name = "FinishBanner",
		parent = parent,
		cframe = bannerCf,
		width = platform.width - 2.4,
		height = 3.4,
		title = "FINISH",
		subtitle = "+" .. tostring(spec.payout) .. " cash",
		ink = color,
		glow = rgb(40, 0, 50),
		board = rgb(24, 18, 30),
	})
	Parts.decal(main, Enum.NormalId.Top, "DELIVERED!", color)
end

function Obstacles.Build(spec: CourseLayout.CourseSpec, platform: CourseLayout.Platform, parent: Instance): BasePart
	local frame = frameOf(spec, platform)
	local palette = spec.palette
	local color = lookColor(platform.look, palette)
	local material = lookMaterial(platform.look, M.Slate)
	if platform.role == "checkpoint" then
		color = Parts.rgb(palette.base):Lerp(Parts.rgb(palette.checkpoint), 0.35)
	elseif platform.role == "finish" then
		color = Parts.rgb(palette.finish)
		material = M.Neon
	end
	local main = Parts.block({
		name = spec.id .. "_" .. platform.role .. "_" .. tostring(platform.index),
		size = Vector3.new(platform.width, platform.thickness, platform.depth),
		cframe = at(frame, 0, 0, 0),
		color = color,
		parent = parent,
		material = material,
	})
	if platform.role == "finish" then
		main.Transparency = 0.1
	end
	tag(main, spec, platform, frame)

	decorate(spec, platform, frame, main, parent)

	local kind = platform.kind
	if kind == "start" then
		Parts.decal(main, Enum.NormalId.Top, "START", Parts.rgb(palette.accent))
		rim(main, frame, platform, Parts.rgb(palette.accent), parent)
	elseif kind == "checkpoint" then
		checkpointDecor(spec, platform, frame, main, parent)
	elseif kind == "finish" then
		finishDecor(spec, platform, frame, main, parent)
	elseif kind == "spinner" then
		makeSpinner(spec, platform, frame, parent, Parts.rgb(palette.kill))
	elseif kind == "vanish" then
		makeVanish(main, parent)
	elseif kind == "conveyor" then
		makeConveyor(main, platform, frame, parent, Parts.rgb(palette.accent))
	elseif kind == "hurdles" then
		makeHurdles(platform, frame, parent, Parts.rgb(palette.kill), spec)
	elseif kind == "ledge" then
		local side = platform.wall or 1
		Parts.block({
			name = "ClimbWall",
			size = Vector3.new(1, 16, platform.depth + 6),
			cframe = at(frame, 0, side * (platform.width / 2 + 0.5), 5),
			color = Parts.rgb(palette.alt),
			parent = parent,
			material = if platform.look == "brick" then M.Brick else M.Slate,
		})
	end
	if platform.move then
		makeMover(main, frame, platform.move)
	end
	return main
end

-- Kill floor under a course: goo, ectoplasm, or lava depending on the stage.
function Obstacles.KillFloor(spec: CourseLayout.CourseSpec, parent: Instance): BasePart
	local bounds = CourseLayout.CourseBounds(spec, 12)
	-- Dim neon so a big glowing floor does not wash the scene out under bloom.
	local material = M.Neon
	local transparency = 0.25
	local dim = 0.55
	if spec.id == "stage3" then
		material = Parts.material("CrackedLava", M.Neon)
		transparency = 0
		dim = 0.2
	end
	local floor = Parts.block({
		name = spec.id .. "_KillFloor",
		size = Vector3.new(bounds.sx, 1.2, bounds.sz),
		position = Vector3.new(bounds.x, CourseLayout.GROUND_TOP + 0.6, bounds.z),
		color = Parts.rgb(spec.palette.kill):Lerp(Color3.new(0, 0, 0), dim),
		parent = parent,
		material = material,
		transparency = transparency,
	})
	floor.CastShadow = false
	floor:SetAttribute("Role", "kill")
	floor:SetAttribute("CourseId", spec.id)
	return floor
end

-- Re-exported so World can drop matching props along a course edge.
Obstacles.Props = Props

return Obstacles
