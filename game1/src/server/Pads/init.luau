--!strict
-- Placeholder porch. TODO(base-team): swap this for real tycoon pads.
-- Buying all three calls BaseService.SetTier(player, 1).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CourseLayout = require(ReplicatedStorage.Shared.CourseLayout)
local PorchPads = require(ReplicatedStorage.Shared.PorchPads)
local Parts = require(script.Parent.Parts)
local PorchModels = require(script.Parent.PorchModels)
local Saves = require(script.Parent.Saves)
local PlayerLock = require(script.Parent.PlayerLock)

local Pads = {}

type Plot = {
	folder: Folder,
	owned: { [string]: boolean },
	prompts: { [string]: ProximityPrompt },
	tierLabel: TextLabel,
	spawned: { [string]: Model },
}

local plots: { [number]: Plot } = {}
local economy: any = nil
local base: any = nil
local notify: any = nil
local mapFolder: Folder? = nil

local function plotOf(player: Player): Plot?
	return plots[player.UserId]
end

local function slotOf(player: Player): number
	local plot = plotOf(player)
	if plot then
		local slot = plot.folder:GetAttribute("Slot")
		if type(slot) == "number" then
			return slot
		end
	end
	return 1
end

local function refreshTier(player: Player)
	local plot = plotOf(player)
	if plot then
		plot.tierLabel.Text = "Tier " .. tostring(base.GetTier(player))
	end
end

local function spawnOwned(player: Player, padId: string)
	local plot = plotOf(player)
	if not plot or plot.spawned[padId] then
		return
	end
	local def = PorchPads.Get(padId)
	if not def then
		return
	end
	local slot = 0
	for index, other in PorchPads.Defs do
		if other.id == padId then
			slot = index
			break
		end
	end
	local placements = CourseLayout.PadPlacements(slotOf(player))
	local placement = placements[slot]
	if not placement then
		return
	end
	local x, y, z = CourseLayout.ModelPoint(placement)
	plot.spawned[padId] = PorchModels.Spawn(def.kind, Vector3.new(x, y, z), plot.folder)
	local prompt = plot.prompts[padId]
	if prompt then
		prompt.Enabled = false
		prompt.ActionText = "Owned"
	end
end

local nextSlot = 0

local function assignSlot(): number
	nextSlot += 1
	return nextSlot
end

function Pads.Start(deps: { economy: any, base: any, notify: any, folder: Folder })
	economy = deps.economy
	base = deps.base
	notify = deps.notify
	mapFolder = deps.folder
	base.TierChanged:Connect(function(player: Player)
		refreshTier(player)
	end)
end

function Pads.CreatePlot(player: Player)
	local parent = mapFolder
	if not parent then
		return
	end
	local slot = assignSlot()
	local folder = Instance.new("Folder")
	folder.Name = "Plot_" .. player.Name
	folder:SetAttribute("OwnerUserId", player.UserId)
	folder:SetAttribute("Slot", slot)
	folder.Parent = parent

	local placements = CourseLayout.PadPlacements(slot)
	local prompts: { [string]: ProximityPrompt } = {}
	for index, def in PorchPads.Defs do
		local placement = placements[index]
		local pad = Parts.block({
			name = "Pad_" .. def.id,
			size = Vector3.new(placement.size, 1, placement.size),
			position = Vector3.new(placement.x, placement.top + 0.5, placement.z),
			color = Color3.fromRGB(255, 206, 120),
			parent = folder,
			material = Enum.Material.Neon,
		})
		pad:SetAttribute("PadId", def.id)
		pad:SetAttribute("OwnerUserId", player.UserId)
		Parts.billboard(
			pad,
			def.name .. "\n" .. tostring(def.cost) .. " cash",
			Vector3.new(0, 4, 0),
			200
		)

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Buy"
		prompt.ObjectText = tostring(def.cost) .. " cash"
		prompt.HoldDuration = 0.2
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = pad
		prompt.Triggered:Connect(function(triggeringPlayer)
			Pads.TryBuy(triggeringPlayer, def.id, player.UserId)
		end)
		prompts[def.id] = prompt
	end

	local sign = Parts.block({
		name = "PlotSign",
		size = Vector3.new(1, 4, 1),
		position = Vector3.new(placements[2].x + 8, placements[2].top + 2, placements[2].z),
		color = Color3.fromRGB(255, 214, 140),
		parent = folder,
	})
	local board = Parts.billboard(sign, player.DisplayName .. "\nTier 0", Vector3.new(0, 3, 0), 220)
	local tierLabel = board:FindFirstChild("Text") :: TextLabel

	plots[player.UserId] = {
		folder = folder,
		owned = {},
		prompts = prompts,
		tierLabel = tierLabel,
		spawned = {},
	}
end

function Pads.TryBuy(player: Player, padId: string, ownerUserId: number)
	if player.UserId ~= ownerUserId then
		notify.Say(player, "That porch belongs to someone else.")
		return
	end
	if not Saves.IsLoaded(player) then
		notify.Say(player, "Still clocking in your tips.")
		return
	end
	local plot = plotOf(player)
	if not plot then
		return
	end
	local preview = PorchPads.Preview(plot.owned, padId, economy.GetCash(player))
	if not preview.ok or not preview.owned or not preview.cost then
		if preview.reason == "poor" then
			notify.Say(player, "Need " .. tostring(preview.cost) .. " cash. Run Suburbs Delivery.")
		elseif preview.reason == "already" then
			notify.Say(player, "You already bought that.")
		end
		return
	end
	if PlayerLock.IsBusy(player) then
		notify.Say(player, "Syncing. Try the pad again.")
		return
	end
	PlayerLock.Try(player, function()
		local again = PorchPads.Preview(plot.owned, padId, economy.GetCash(player))
		if not again.ok or not again.owned or not again.cost then
			return
		end
		if not economy.TrySpend(player, again.cost, economy.Reasons.BasePad) then
			notify.Say(player, "Need " .. tostring(again.cost) .. " cash. Run Suburbs Delivery.")
			return
		end
		plot.owned = again.owned
		base.SetPad(player, padId, true)
		spawnOwned(player, padId)
		local def = PorchPads.Get(padId)
		notify.Say(player, "Bought " .. (def and def.name or padId) .. ".")
		if again.tier == 1 then
			base.SetTier(player, 1)
			notify.Say(player, "Porch complete. Stage 2 is open.")
		end
		refreshTier(player)
		Saves.Save(player)
	end)
end

function Pads.Export(player: Player): { [string]: boolean }
	local plot = plotOf(player)
	if not plot then
		return {}
	end
	return table.clone(plot.owned)
end

function Pads.Load(player: Player, owned: any)
	local plot = plotOf(player)
	if not plot or type(owned) ~= "table" then
		return
	end
	local restored: { [string]: boolean } = {}
	for _, def in PorchPads.Defs do
		if owned[def.id] == true then
			restored[def.id] = true
			base.SetPad(player, def.id, true)
			spawnOwned(player, def.id)
		end
	end
	plot.owned = restored
	if PorchPads.OwnsAll(restored) then
		base.SetTier(player, 1)
	end
	refreshTier(player)
end

function Pads.Forget(player: Player)
	local plot = plots[player.UserId]
	plots[player.UserId] = nil
	if plot then
		plot.folder:Destroy()
	end
end

return Pads
