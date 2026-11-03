--!strict
-- Small part helpers for the placeholder blockout.

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
}

function Parts.block(props: BlockProps): Part
	local part = Instance.new("Part")
	part.Name = props.name
	part.Anchored = true
	part.Size = props.size
	if props.cframe then
		part.CFrame = props.cframe
	elseif props.position then
		part.CFrame = CFrame.new(props.position)
	end
	part.Color = props.color
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Transparency = props.transparency or 0
	part.CanCollide = if props.canCollide == nil then true else props.canCollide
	part.CanTouch = if props.canTouch == nil then true else props.canTouch
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = props.parent
	return part
end

function Parts.billboard(
	parent: Instance,
	text: string,
	offset: Vector3?,
	width: number?
): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(width or 220, 80)
	gui.StudsOffset = offset or Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 180
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = Color3.fromRGB(255, 244, 230)
	label.TextStrokeColor3 = Color3.fromRGB(20, 12, 16)
	label.TextStrokeTransparency = 0.4
	label.TextScaled = true
	label.Parent = gui
	return gui
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

function Parts.standCFrame(part: BasePart): CFrame
	local top = part.Position.Y + part.Size.Y / 2
	local feet = Vector3.new(part.Position.X, top + 3.5, part.Position.Z)
	return CFrame.lookAt(feet, feet + Vector3.new(0, 0, 10))
end

function Parts.rgb(channels: { number }): Color3
	return Color3.fromRGB(channels[1], channels[2], channels[3])
end

return Parts
