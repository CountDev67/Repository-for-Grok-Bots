--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "CrackulaHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "CashPanel"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 12)
panel.Size = UDim2.fromOffset(240, 72)
panel.BackgroundColor3 = Color3.fromRGB(28, 20, 24)
panel.BackgroundTransparency = 0.15
panel.BorderSizePixel = 0
panel.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(255, 186, 92)
stroke.Thickness = 1.5
stroke.Transparency = 0.2
stroke.Parent = panel

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.fromOffset(12, 8)
title.Size = UDim2.new(1, -24, 0, 18)
title.Font = Enum.Font.Gotham
pcall(function()
	title.Font = Enum.Font.Creepster
end)
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(255, 186, 92)
title.Text = "COUNT CRACKULA"
title.Parent = panel

local cashLabel = Instance.new("TextLabel")
cashLabel.BackgroundTransparency = 1
cashLabel.Position = UDim2.fromOffset(12, 28)
cashLabel.Size = UDim2.new(1, -24, 0, 36)
cashLabel.Font = Enum.Font.GothamBold
cashLabel.TextSize = 28
cashLabel.TextXAlignment = Enum.TextXAlignment.Left
cashLabel.TextColor3 = Color3.fromRGB(255, 244, 230)
cashLabel.Text = "Cash  0"
cashLabel.Parent = panel

local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 1)
toast.Position = UDim2.new(0.5, 0, 1, -28)
toast.Size = UDim2.new(0.9, 0, 0, 44)
toast.BackgroundColor3 = Color3.fromRGB(28, 20, 24)
toast.BackgroundTransparency = 0.1
toast.Font = Enum.Font.GothamBold
toast.TextSize = 18
toast.TextColor3 = Color3.fromRGB(255, 244, 230)
toast.Text = ""
toast.Visible = false
toast.Parent = gui
local toastCorner = Instance.new("UICorner")
toastCorner.CornerRadius = UDim.new(0, 8)
toastCorner.Parent = toast

local toastToken = 0
local function showToast(message: string)
	toastToken += 1
	local token = toastToken
	toast.Text = message
	toast.Visible = true
	task.delay(3.4, function()
		if toastToken == token then
			toast.Visible = false
		end
	end)
end

local remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
if remotes then
	local notify = remotes:WaitForChild("Notify")
	if notify and notify:IsA("RemoteEvent") then
		notify.OnClientEvent:Connect(function(message)
			if type(message) == "string" then
				showToast(message)
			end
		end)
	end
else
	showToast("Still tying the cleats…")
end

local leaderstats = player:WaitForChild("leaderstats", 30)
if leaderstats then
	local cash = leaderstats:WaitForChild("Cash", 10)
	if cash and cash:IsA("IntValue") then
		local function render()
			cashLabel.Text = "Cash  " .. tostring(cash.Value)
		end
		render()
		cash.Changed:Connect(render)
	end
end

local ShopGui = require(script.ShopGui)
ShopGui.Attach(gui, showToast)

require(script.Bats).Start()
