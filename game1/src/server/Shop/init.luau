--!strict
-- Dev products go through ProcessReceipt. Game passes are ownership checks.
-- Ids of 0 never grant. Placeholder SKUs live in Shared.Shop.Catalog.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Catalog = require(ReplicatedStorage.Shared.Shop.Catalog)
local Receipts = require(ReplicatedStorage.Shared.Shop.Receipts)
local Economy = require(ReplicatedStorage.Shared.Economy)

local PlayerLock = require(script.Parent.PlayerLock)
local Saves = require(script.Parent.Saves)
local Stages = require(script.Parent.Stages)
local Movement = require(script.Parent.Movement)
local Gear = require(script.Parent.Gear)

local Shop = {}

type PassMap = { [string]: boolean }
type ReceiptMap = { [string]: { productId: number, at: number } }

local passes: { [number]: PassMap } = {}
local receipts: { [number]: ReceiptMap } = {}
local notify: any = nil
local hasSock: ((Player) -> boolean)? = nil
local lastRefresh: { [number]: number } = {}

local function blankPasses(): PassMap
	return { doubleCash = false, speedCoil = false, vip = false, foamBlaster = false }
end

local function passMap(player: Player): PassMap
	local map = passes[player.UserId]
	if not map then
		map = blankPasses()
		passes[player.UserId] = map
	end
	return map
end

local function receiptMap(player: Player): ReceiptMap
	local map = receipts[player.UserId]
	if not map then
		map = {}
		receipts[player.UserId] = map
	end
	return map
end

function Shop.OwnsPass(player: Player, key: string): boolean
	local map = passes[player.UserId]
	return map ~= nil and map[key] == true
end

local function dress(player: Player)
	if Shop.OwnsPass(player, "doubleCash") then
		Economy.SetEarnMultiplier(player, 2)
	else
		Economy.SetEarnMultiplier(player, 1)
	end
	local character = player.Character
	if character then
		Movement.ApplyCharacter(player, character)
		Gear.Apply(player, character, {
			foam = Shop.OwnsPass(player, "foamBlaster"),
			sock = if hasSock then hasSock(player) else false,
		})
	end
end

function Shop.RefreshCharacter(player: Player)
	dress(player)
end

local function grantProduct(player: Player, product): boolean
	if product.kind == "cash" and type(product.cash) == "number" then
		Economy.AddCash(player, product.cash, Economy.Reasons.DevProduct)
		if notify then
			notify.Say(
				player,
				"+" .. tostring(product.cash) .. " cash from " .. product.name .. "."
			)
		end
		return true
	end
	if product.kind == "skip" then
		if Stages.SkipCurrent(player) then
			if notify then
				notify.Say(player, "Route skipped.")
			end
		else
			Economy.AddCash(player, 50, Economy.Reasons.DevProduct)
			if notify then
				notify.Say(player, "No open route. +50 cash instead.")
			end
		end
		return true
	end
	if product.kind == "revive" then
		Stages.Revive(player)
		return true
	end
	return false
end

local function decisionEnum(name: string)
	if name == "PurchaseGranted" then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

function Shop.HandleReceipt(receiptInfo): string
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player or not Saves.IsLoaded(player) then
		return "NotProcessedYet"
	end
	local product = Catalog.ProductById(receiptInfo.ProductId)
	if not product then
		return "NotProcessedYet"
	end
	local decision = "NotProcessedYet"
	local ran = PlayerLock.Try(player, function()
		decision = Receipts.Process(receiptMap(player), {
			PurchaseId = receiptInfo.PurchaseId,
			ProductId = receiptInfo.ProductId,
		}, {
			grant = function()
				return grantProduct(player, product)
			end,
			save = function()
				return Saves.Save(player)
			end,
			now = function()
				return os.time()
			end,
		})
	end)
	if not ran then
		return "NotProcessedYet"
	end
	return decision
end

function Shop.RefreshPasses(player: Player)
	local now = os.clock()
	if now - (lastRefresh[player.UserId] or 0) < 2 then
		return
	end
	lastRefresh[player.UserId] = now
	local map = passMap(player)
	for _, pass in Catalog.Passes do
		if pass.id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
			end)
			if ok then
				map[pass.key] = owns == true
			end
		end
	end
	dress(player)
end

function Shop.DebugGrantPass(player: Player, key: string): boolean
	if not RunService:IsStudio() then
		return false
	end
	if not Catalog.PassByKey(key) then
		return false
	end
	passMap(player)[key] = true
	dress(player)
	return true
end

function Shop.Load(player: Player, data: any)
	local map = blankPasses()
	local savedReceipts: ReceiptMap = {}
	if type(data) == "table" then
		if type(data.passes) == "table" then
			for _, pass in Catalog.Passes do
				map[pass.key] = data.passes[pass.key] == true
			end
		end
		if type(data.receipts) == "table" then
			for key, value in data.receipts do
				if type(key) == "string" and type(value) == "table" then
					savedReceipts[key] = {
						productId = value.productId or 0,
						at = value.at or 0,
					}
				end
			end
		end
	end
	passes[player.UserId] = map
	receipts[player.UserId] = savedReceipts
	Shop.RefreshPasses(player)
end

function Shop.Export(player: Player)
	local map = passMap(player)
	local copyPasses = {
		doubleCash = map.doubleCash == true,
		speedCoil = map.speedCoil == true,
		vip = map.vip == true,
		foamBlaster = map.foamBlaster == true,
	}
	local copyReceipts = {}
	for key, value in receiptMap(player) do
		copyReceipts[key] = { productId = value.productId, at = value.at }
	end
	return { passes = copyPasses, receipts = copyReceipts }
end

function Shop.Forget(player: Player)
	passes[player.UserId] = nil
	receipts[player.UserId] = nil
	lastRefresh[player.UserId] = nil
end

function Shop.Start(deps: { notify: any, hasSock: (Player) -> boolean })
	notify = deps.notify
	hasSock = deps.hasSock
	Movement.SetSpeedProvider(function(player)
		if Shop.OwnsPass(player, "speedCoil") then
			return 22
		end
		return nil
	end)

	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	local refresh = Instance.new("RemoteEvent")
	refresh.Name = "RefreshPasses"
	refresh.Parent = folder
	refresh.OnServerEvent:Connect(function(player)
		if Saves.IsLoaded(player) then
			Shop.RefreshPasses(player)
		end
	end)

	MarketplaceService.ProcessReceipt = function(receiptInfo)
		return decisionEnum(Shop.HandleReceipt(receiptInfo))
	end
end

return Shop
