--!strict
-- Purely cosmetic, client-side: circles and flaps the bats the server built
-- under workspace.CountCrackulaMap.Bats,.
-- Local CFrame writes never replicate, so this costs the server nothing.

local RunService = game:GetService("RunService")

local Bats = {}

type Bat = {
	parts: { { part: BasePart, offset: CFrame, side: number } },
	center: Vector3,
	radius: number,
	speed: number,
	phase: number,
	bob: number,
}

function Bats.Start()
	task.spawn(function()
		local map = workspace:WaitForChild("CountCrackulaMap", 60)
		local folder = map and map:WaitForChild("Bats", 30)
		if not folder then
			return
		end
		local bats: { Bat } = {}
		for _, model in folder:GetChildren() do
			if model:IsA("Model") and model.PrimaryPart then
				local root = model.PrimaryPart :: BasePart
				local center = model:GetAttribute("Center")
				if typeof(center) ~= "Vector3" then
					continue
				end
				local entry: Bat = {
					parts = {},
					center = center :: Vector3,
					radius = tonumber(model:GetAttribute("Radius")) or 16,
					speed = tonumber(model:GetAttribute("Speed")) or 0.8,
					phase = tonumber(model:GetAttribute("Phase")) or 0,
					bob = tonumber(model:GetAttribute("Bob")) or 2,
				}
				for _, child in model:GetChildren() do
					if child:IsA("BasePart") then
						local side = child:GetAttribute("Side")
						table.insert(entry.parts, {
							part = child,
							offset = root.CFrame:ToObjectSpace(child.CFrame),
							side = if type(side) == "number" then side else 0,
						})
					end
				end
				table.insert(bats, entry)
			end
		end
		RunService.RenderStepped:Connect(function()
			local t = os.clock()
			for _, bat in bats do
				local angle = bat.phase + t * bat.speed
				local pos = bat.center
					+ Vector3.new(math.cos(angle) * bat.radius, math.sin(t * 2 + bat.phase) * bat.bob, math.sin(angle) * bat.radius)
				local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle)) * math.sign(bat.speed)
				local root = CFrame.lookAt(pos, pos + tangent)
				local flap = math.sin(t * 14 + bat.phase) * 0.6
				for _, piece in bat.parts do
					local cf = root * piece.offset
					if piece.side ~= 0 then
						cf = root * CFrame.Angles(0, 0, -piece.side * flap) * piece.offset
					end
					piece.part.CFrame = cf
				end
			end
		end)
	end)
end

return Bats
