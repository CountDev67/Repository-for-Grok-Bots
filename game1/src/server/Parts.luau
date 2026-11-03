--!strict
-- Part, sign, and label helpers shared by the runtime-built map.
-- Everything is built from Parts and built-in Materials. No asset ids.

local Players = game:GetService("Players")

local Parts = {}

export type BlockProps = {
	name: string,
	size: Vector3,
	cframe: CFrame?,
	position: Vector3?,
	color: Color3,
	parent: Instance,
	material: Enum.Material?,
	transparency: number?,
	canCollide: boolean?,
	canTouch: boolean?,
	shape: Enum.PartType?,
	decor: boolean?,
}

local function enumItem(enumType: any, name: string): any?
	local ok, item = pcall(function()
		return enumType[name]
	end)
	if ok then
		return item
	end
	return nil
end

-- Newer materials (Cardboard, RoofShingles, ...) fall back if this client lacks them.
function Parts.material(name: string, fallback: Enum.Material): Enum.Material
	local item = enumItem(Enum.Material, name)
	if item then
		return item :: Enum.Material
	end
	return fallback
end

local gothic: Enum.Font? = nil
function Parts.gothicFont(): Enum.Font
	if gothic then
		return gothic
	end
	for _, name in { "Creepster", "Fondamento", "Antique" } do
		local item = enumItem(Enum.Font, name)
		if item then
			gothic = item :: Enum.Font
			return item :: Enum.Font
		end
	end
	gothic = Enum.Font.GothamBold
	return Enum.Font.GothamBold
end

function Parts.block(props: BlockProps): Part
	local part = Instance.new("Part")
	part.Name = props.name
	part.Anchored = true
	if props.shape then
		part.Shape = props.shape
	end
	part.Size = props.size
	if props.cframe then
		part.CFrame = props.cframe
	elseif props.position then
		part.CFrame = CFrame.new(props.position)
	end
	part.Color = props.color
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Transparency = props.transparency or 0
	if props.decor then
		part.CanCollide = if props.canCollide == nil then false else props.canCollide
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
	else
		part.CanCollide = if props.canCollide == nil then true else props.canCollide
		part.CanTouch = if props.canTouch == nil then true else props.canTouch
	end
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = props.parent
	return part
end

function Parts.wedge(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	parent: Instance,
	material: Enum.Material?
): WedgePart
	local part = Instance.new("WedgePart")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Small world-sized label. Sized in studs so it shrinks with distance like a
-- real object, never drawn on top of the world, and hidden past maxDistance.
function Parts.billboard(
	parent: Instance,
	text: string,
	offset: Vector3?,
	studsWide: number?,
	maxDistance: number?
): BillboardGui
	local wide = studsWide or 6
	local lines = 1
	for _ in string.gmatch(text, "\n") do
		lines += 1
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromScale(wide, math.max(1.2, lines * 1.1))
	gui.StudsOffset = offset or Vector3.new(0, 3, 0)
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.MaxDistance = maxDistance or 55
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = Color3.fromRGB(255, 244, 230)
	label.TextStrokeColor3 = Color3.fromRGB(20, 12, 16)
	label.TextStrokeTransparency = 0.3
	label.TextScaled = true
	label.Parent = gui
	return gui
end

export type SignProps = {
	name: string,
	parent: Instance,
	cframe: CFrame, -- board center; LookVector points at the reader
	width: number,
	height: number,
	title: string,
	subtitle: string?,
	board: Color3?,
	ink: Color3?,
	glow: Color3?,
	material: Enum.Material?,
	backText: string?,
}

local function surfaceText(
	part: BasePart,
	face: Enum.NormalId,
	title: string,
	subtitle: string?,
	ink: Color3,
	glow: Color3
): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Sign_" .. face.Name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.MaxDistance = 300
	gui.Parent = part

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.BackgroundTransparency = 1
	titleLabel.AnchorPoint = Vector2.new(0.5, 0)
	titleLabel.Position = UDim2.fromScale(0.5, 0.06)
	titleLabel.Size = UDim2.fromScale(0.92, if subtitle then 0.58 else 0.88)
	titleLabel.Font = Parts.gothicFont()
	titleLabel.Text = title
	titleLabel.TextColor3 = ink
	titleLabel.TextStrokeColor3 = glow
	titleLabel.TextStrokeTransparency = 0.35
	titleLabel.TextScaled = true
	titleLabel.TextWrapped = true
	titleLabel.Parent = gui

	if subtitle then
		local sub = Instance.new("TextLabel")
		sub.Name = "Subtitle"
		sub.BackgroundTransparency = 1
		sub.AnchorPoint = Vector2.new(0.5, 1)
		sub.Position = UDim2.fromScale(0.5, 0.95)
		sub.Size = UDim2.fromScale(0.9, 0.3)
		sub.Font = Enum.Font.GothamBold
		sub.Text = subtitle
		sub.TextColor3 = Color3.fromRGB(240, 232, 255)
		sub.TextStrokeColor3 = Color3.fromRGB(10, 6, 16)
		sub.TextStrokeTransparency = 0.4
		sub.TextScaled = true
		sub.TextWrapped = true
		sub.Parent = gui
	end
	return gui
end

-- A solid sign board with a SurfaceGui on the face that points at the reader.
function Parts.sign(props: SignProps): Part
	local ink = props.ink or Color3.fromRGB(255, 120, 60)
	local glow = props.glow or Color3.fromRGB(40, 0, 30)
	local board = Parts.block({
		name = props.name,
		size = Vector3.new(props.width, props.height, 0.6),
		cframe = props.cframe,
		color = props.board or Color3.fromRGB(34, 26, 40),
		parent = props.parent,
		material = props.material or Enum.Material.WoodPlanks,
	})
	-- Neon frame so the board reads at night.
	local frameColor = props.glow or Color3.fromRGB(170, 70, 255)
	local thick = 0.3
	for _, edge in
		{
			{ Vector3.new(props.width + thick, thick, 0.7), Vector3.new(0, props.height / 2, 0) },
			{ Vector3.new(props.width + thick, thick, 0.7), Vector3.new(0, -props.height / 2, 0) },
			{ Vector3.new(thick, props.height, 0.7), Vector3.new(props.width / 2, 0, 0) },
			{ Vector3.new(thick, props.height, 0.7), Vector3.new(-props.width / 2, 0, 0) },
		}
	do
		Parts.block({
			name = "Frame",
			size = edge[1],
			cframe = props.cframe * CFrame.new(edge[2]),
			color = frameColor,
			parent = board,
			material = Enum.Material.Neon,
			decor = true,
		})
	end
	surfaceText(board, Enum.NormalId.Front, props.title, props.subtitle, ink, glow)
	if props.backText then
		surfaceText(board, Enum.NormalId.Back, props.backText, nil, ink, glow)
	end
	return board
end

-- Small text painted onto one face of an existing part (checkpoints, plaques).
function Parts.decal(part: BasePart, face: Enum.NormalId, text: string, color: Color3?): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Paint_" .. face.Name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.MaxDistance = 120
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.8, 0.35)
	label.Font = Parts.gothicFont()
	label.Text = text
	label.TextColor3 = color or Color3.fromRGB(255, 250, 240)
	label.TextTransparency = 0.1
	label.TextStrokeTransparency = 0.6
	label.TextScaled = true
	label.Parent = gui
	return gui
end

function Parts.light(parent: BasePart, color: Color3, range: number?, brightness: number?): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range or 14
	light.Brightness = brightness or 1.5
	light.Shadows = false
	light.Parent = parent
	return light
end

function Parts.playerFromHit(hit: BasePart): Player?
	local current: Instance? = hit
	while current do
		if current:IsA("Model") then
			local player = Players:GetPlayerFromCharacter(current)
			if player then
				return player
			end
		end
		current = current.Parent
	end
	return nil
end

function Parts.standCFrame(part: BasePart, facing: Vector3?): CFrame
	local top = part.Position.Y + part.Size.Y / 2
	local feet = Vector3.new(part.Position.X, top + 3.5, part.Position.Z)
	local look = facing or part:GetAttribute("Facing")
	if typeof(look) ~= "Vector3" or (look :: Vector3).Magnitude < 0.01 then
		look = Vector3.new(0, 0, 1)
	end
	return CFrame.lookAt(feet, feet + (look :: Vector3))
end

function Parts.rgb(channels: { number }): Color3
	return Color3.fromRGB(channels[1], channels[2], channels[3])
end

return Parts
