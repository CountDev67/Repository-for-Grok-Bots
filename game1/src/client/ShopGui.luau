--!strict
-- Shop list. Ids of 0 stay on the board until the dashboard SKUs exist.
-- Prompts are client-side. Grants happen on the server.

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Catalog =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Shop"):WaitForChild("Catalog"))

local ShopGui = {}

function ShopGui.Attach(gui: ScreenGui, toast: (string) -> ())
	local open = Instance.new("TextButton")
	open.Name = "ShopButton"
	open.AnchorPoint = Vector2.new(1, 0)
	open.Position = UDim2.new(1, -12, 0, 12)
	open.Size = UDim2.fromOffset(88, 40)
	open.BackgroundColor3 = Color3.fromRGB(226, 48, 42)
	open.Font = Enum.Font.GothamBold
	open.TextSize = 16
	open.TextColor3 = Color3.fromRGB(255, 244, 230)
	open.Text = "Shop"
	open.AutoButtonColor = true
	open.Parent = gui
	local openCorner = Instance.new("UICorner")
	openCorner.CornerRadius = UDim.new(0, 8)
	openCorner.Parent = open

	local panel = Instance.new("Frame")
	panel.Name = "Shop"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromScale(0.92, 0.78)
	panel.BackgroundColor3 = Color3.fromRGB(24, 18, 22)
	panel.Visible = false
	panel.Parent = gui
	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 12)
	panelCorner.Parent = panel
	local sizeCap = Instance.new("UISizeConstraint")
	sizeCap.MaxSize = Vector2.new(480, 560)
	sizeCap.MinSize = Vector2.new(280, 320)
	sizeCap.Parent = panel

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(16, 10)
	title.Size = UDim2.new(1, -80, 0, 28)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(255, 214, 140)
	title.Text = "Count's bag"
	title.Parent = panel

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -10, 0, 10)
	close.Size = UDim2.fromOffset(36, 28)
	close.BackgroundTransparency = 1
	close.Font = Enum.Font.GothamBold
	close.TextSize = 18
	close.TextColor3 = Color3.fromRGB(255, 244, 230)
	close.Text = "X"
	close.Parent = panel

	local scroller = Instance.new("ScrollingFrame")
	scroller.Position = UDim2.fromOffset(12, 48)
	scroller.Size = UDim2.new(1, -24, 1, -60)
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.ScrollBarThickness = 6
	scroller.CanvasSize = UDim2.fromOffset(0, 0)
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.Parent = scroller

	local function addRow(kind: string, def)
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -8, 0, 72)
		row.BackgroundColor3 = Color3.fromRGB(40, 30, 36)
		row.Parent = scroller
		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 8)
		rowCorner.Parent = row

		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Position = UDim2.fromOffset(10, 6)
		name.Size = UDim2.new(1, -110, 0, 22)
		name.Font = Enum.Font.GothamBold
		name.TextSize = 16
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextColor3 = Color3.fromRGB(255, 244, 230)
		name.Text = def.name
		name.Parent = row

		local blurb = Instance.new("TextLabel")
		blurb.BackgroundTransparency = 1
		blurb.Position = UDim2.fromOffset(10, 28)
		blurb.Size = UDim2.new(1, -110, 0, 36)
		blurb.Font = Enum.Font.Gotham
		blurb.TextSize = 13
		blurb.TextXAlignment = Enum.TextXAlignment.Left
		blurb.TextYAlignment = Enum.TextYAlignment.Top
		blurb.TextWrapped = true
		blurb.TextColor3 = Color3.fromRGB(214, 190, 180)
		blurb.Text = def.blurb
		blurb.Parent = row

		local buy = Instance.new("TextButton")
		buy.AnchorPoint = Vector2.new(1, 0.5)
		buy.Position = UDim2.new(1, -8, 0.5, 0)
		buy.Size = UDim2.fromOffset(84, 32)
		buy.BackgroundColor3 = Color3.fromRGB(255, 186, 92)
		buy.Font = Enum.Font.GothamBold
		buy.TextSize = 14
		buy.TextColor3 = Color3.fromRGB(28, 18, 16)
		buy.Text = if def.id == 0 then "No id" else (tostring(def.price) .. " R$")
		buy.Parent = row
		local buyCorner = Instance.new("UICorner")
		buyCorner.CornerRadius = UDim.new(0, 6)
		buyCorner.Parent = buy
		buy.Activated:Connect(function()
			if def.id == 0 then
				toast(def.name .. " still has placeholder id 0.")
				return
			end
			local ok = pcall(function()
				if kind == "pass" then
					MarketplaceService:PromptGamePassPurchase(def.id)
				else
					MarketplaceService:PromptProductPurchase(def.id)
				end
			end)
			if not ok then
				toast("Purchases need a published place.")
			end
		end)
	end

	for _, pass in Catalog.Passes do
		addRow("pass", pass)
	end
	for _, product in Catalog.Products do
		addRow("product", product)
	end

	open.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)
	close.Activated:Connect(function()
		panel.Visible = false
	end)

	local remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
	local refresh = if remotes then remotes:WaitForChild("RefreshPasses", 30) else nil
	if refresh and refresh:IsA("RemoteEvent") then
		local function ping()
			refresh:FireServer()
		end
		MarketplaceService.PromptGamePassPurchaseFinished:Connect(ping)
		MarketplaceService.PromptProductPurchaseFinished:Connect(ping)
	end
end

return ShopGui
