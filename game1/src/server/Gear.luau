--!strict
-- Cosmetics the passes and the day-7 sock actually equip.
-- Foam Fangs is a toy. Do not add damage, knockback, or explosions.

local Debris = game:GetService("Debris")

local Gear = {}

local function ensureSock(character: Model)
	if character:FindFirstChild("LuckyGameSock") then
		return
	end
	local foot = character:FindFirstChild("LeftFoot") or character:FindFirstChild("Left Leg")
	if not foot or not foot:IsA("BasePart") then
		return
	end
	local sock = Instance.new("Part")
	sock.Name = "LuckyGameSock"
	sock.Size = Vector3.new(0.55, 0.8, 1)
	sock.Color = Color3.fromRGB(250, 244, 230)
	sock.Material = Enum.Material.Fabric
	sock.CanCollide = false
	sock.CanTouch = false
	sock.Massless = true
	sock.CFrame = foot.CFrame * CFrame.new(0, -0.15, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = foot
	weld.Part1 = sock
	weld.Parent = sock
	local stripe = Instance.new("Part")
	stripe.Name = "Stripe"
	stripe.Size = Vector3.new(0.58, 0.18, 1.02)
	stripe.Color = Color3.fromRGB(226, 48, 42)
	stripe.Material = Enum.Material.Fabric
	stripe.CanCollide = false
	stripe.CanTouch = false
	stripe.Massless = true
	stripe.CFrame = sock.CFrame * CFrame.new(0, 0.15, 0)
	local stripeWeld = Instance.new("WeldConstraint")
	stripeWeld.Part0 = sock
	stripeWeld.Part1 = stripe
	stripeWeld.Parent = stripe
	stripe.Parent = sock
	sock.Parent = character
end

local function launchDart(tool: Tool)
	local character = tool.Parent
	if not character or not character:IsA("Model") then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local dart = Instance.new("Part")
	dart.Name = "FoamDart"
	dart.Shape = Enum.PartType.Ball
	dart.Size = Vector3.new(0.8, 0.8, 0.8)
	dart.Color = Color3.fromRGB(255, 140, 48)
	dart.Material = Enum.Material.SmoothPlastic
	dart.CanCollide = false
	dart.CanTouch = false
	dart.Massless = true
	dart.CFrame = root.CFrame * CFrame.new(0, 0.5, -3)
	dart.AssemblyLinearVelocity = root.CFrame.LookVector * 90
	dart:SetAttribute("Toy", true)
	dart.Parent = workspace
	Debris:AddItem(dart, 1.2)
end

local function ensureBlaster(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	if not backpack then
		return
	end
	if backpack:FindFirstChild("Foam Fangs") then
		return
	end
	local character = player.Character
	if character and character:FindFirstChild("Foam Fangs") then
		return
	end
	local tool = Instance.new("Tool")
	tool.Name = "Foam Fangs"
	tool.ToolTip = "Toy foam blaster. Squishes nothing that matters."
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool:SetAttribute("Toy", true)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.45, 0.45, 1.4)
	handle.Color = Color3.fromRGB(126, 220, 86)
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.Parent = tool
	local tip = Instance.new("Part")
	tip.Name = "Cork"
	tip.Shape = Enum.PartType.Ball
	tip.Size = Vector3.new(0.55, 0.55, 0.55)
	tip.Color = Color3.fromRGB(255, 176, 64)
	tip.Material = Enum.Material.SmoothPlastic
	tip.CanCollide = false
	tip.Massless = true
	tip.CFrame = handle.CFrame * CFrame.new(0, 0, -0.8)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = tip
	weld.Parent = tip
	tip.Parent = tool
	tool.Activated:Connect(function()
		launchDart(tool)
	end)
	tool.Parent = backpack
end

function Gear.Apply(player: Player, character: Model, flags: { foam: boolean, sock: boolean })
	if flags.sock then
		ensureSock(character)
	end
	if flags.foam then
		ensureBlaster(player)
	end
end

return Gear
