--!strict
-- Toy placeholder props. No gameplay except the bench, which is a Seat.

local PorchModels = {}

local function part(
	model: Model,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Anchored = true
	piece.CanCollide = true
	piece.Size = size
	piece.CFrame = cframe
	piece.Color = color
	piece.Material = material or Enum.Material.SmoothPlastic
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	piece.Parent = model
	return piece
end

function PorchModels.Spawn(kind: string, position: Vector3, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = "Porch_" .. kind
	local origin = CFrame.new(position)

	if kind == "bench" then
		local seat = Instance.new("Seat")
		seat.Name = "Bench"
		seat.Anchored = true
		seat.Size = Vector3.new(4.5, 0.45, 1.8)
		seat.CFrame = origin * CFrame.new(0, 1.3, 0)
		seat.Color = Color3.fromRGB(122, 74, 48)
		seat.Material = Enum.Material.Wood
		seat.Parent = model
		part(
			model,
			"Back",
			Vector3.new(4.5, 1.6, 0.35),
			origin * CFrame.new(0, 2.3, -0.85),
			Color3.fromRGB(96, 56, 36),
			Enum.Material.Wood
		)
		model.PrimaryPart = seat
	elseif kind == "icebath" then
		local tub = part(
			model,
			"Tub",
			Vector3.new(6, 2.2, 3.2),
			origin * CFrame.new(0, 1.1, 0),
			Color3.fromRGB(236, 240, 244),
			Enum.Material.SmoothPlastic
		)
		local water = part(
			model,
			"Water",
			Vector3.new(5.2, 0.45, 2.4),
			origin * CFrame.new(0, 2.05, 0),
			Color3.fromRGB(120, 210, 255),
			Enum.Material.Neon
		)
		water.CanCollide = false
		model.PrimaryPart = tub
	elseif kind == "shrine" then
		local pedestal = part(
			model,
			"Pedestal",
			Vector3.new(4, 3, 4),
			origin * CFrame.new(0, 1.5, 0),
			Color3.fromRGB(72, 64, 78),
			Enum.Material.Slate
		)
		local bag = part(
			model,
			"Bag",
			Vector3.new(2.6, 2.8, 1.5),
			origin * CFrame.new(0, 4.4, 0),
			Color3.fromRGB(226, 48, 42),
			Enum.Material.SmoothPlastic
		)
		part(
			model,
			"Flap",
			Vector3.new(2.6, 0.9, 1.5),
			origin * CFrame.new(0, 6.1, 0),
			Color3.fromRGB(176, 32, 36)
		)
		local mark = part(
			model,
			"Mark",
			Vector3.new(1.1, 1.1, 0.2),
			origin * CFrame.new(0, 4.5, 0.8),
			Color3.fromRGB(255, 196, 64),
			Enum.Material.Neon
		)
		mark.CanCollide = false
		model.PrimaryPart = pedestal
		local board = Instance.new("BillboardGui")
		board.Size = UDim2.fromOffset(160, 40)
		board.StudsOffset = Vector3.new(0, 3.2, 0)
		board.AlwaysOnTop = false
		board.Parent = bag
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBold
		label.Text = "TIP BAG"
		label.TextColor3 = Color3.fromRGB(255, 228, 180)
		label.TextScaled = true
		label.Parent = board
	else
		part(
			model,
			"Block",
			Vector3.new(3, 3, 3),
			origin * CFrame.new(0, 1.5, 0),
			Color3.fromRGB(200, 200, 200)
		)
	end

	model.Parent = parent
	return model
end

return PorchModels
