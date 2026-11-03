--!strict
local Leaderstats = {}

function Leaderstats.Attach(player: Player, amount: number)
	local existing = player:FindFirstChild("leaderstats")
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = math.floor(amount)
	cash.Parent = folder
	folder.Parent = player
end

function Leaderstats.Bind(economy: any)
	economy.Changed:Connect(function(player: Player, amount: number)
		local folder = player:FindFirstChild("leaderstats")
		if not folder then
			return
		end
		local cash = folder:FindFirstChild("Cash")
		if cash and cash:IsA("IntValue") then
			cash.Value = math.floor(amount)
		end
	end)
end

return Leaderstats
