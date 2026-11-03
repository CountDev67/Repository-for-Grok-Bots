--!strict
-- Placeholder porch. TODO(base-team): swap this for real tycoon pads.
-- Buying all three calls BaseService.SetTier(player, 1).
-- The Crypt Key pad (PorchPads.Upgrade) unlocks after that and sets tier 2.

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
	if padId == PorchPads.Upgrade.id then
		local placement = CourseLayout.UpgradePlacement(slotOf(player))
		plot.spawned[padId] = PorchModels.Spawn(
			"cryptkey",
			Vector3.new(placement.x, placement.top + 1, placement.z),
			plot.folder
		)
		local prompt = plot.prompts[padId]
		if prompt then
			prompt.Enabled = false
			prompt.ActionText = "Owned"
		end
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
		local plot = plotOf(player)
		local prompt = plot and plot.prompts[PorchPads.Upgrade.id]
		if plot and prompt and not plot.owned[PorchPads.Upgrade.id] then
			prompt.Enabled = base.GetTier(player) >= PorchPads.Upgrade.requiresTier
		end
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
		Parts.billboard(pad, def.name .. "\n" .. tostring(def.cost) .. " cash", Vector3.new(0, 3, 0), 7, 45)

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

	local upgrade = PorchPads.Upgrade
	local spot = CourseLayout.UpgradePlacement(slot)
	local keyPad = Parts.block({
		name = "Pad_" .. upgrade.id,
		size = Vector3.new(spot.size, 1, spot.size),
		position = Vector3.new(spot.x, spot.top + 0.5, spot.z),
		color = Color3.fromRGB(170, 70, 255),
		parent = folder,
		material = Enum.Material.Neon,
	})
	keyPad:SetAttribute("PadId", upgrade.id)
	keyPad:SetAttribute("OwnerUserId", player.UserId)
	Parts.billboard(
		keyPad,
		upgrade.name .. "\n" .. tostring(upgrade.cost) .. " cash · Tier 2",
		Vector3.new(0, 3, 0),
		7,
		45
	)
	local keyPrompt = Instance.new("ProximityPrompt")
	keyPrompt.ActionText = "Buy"
	keyPrompt.ObjectText = upgrade.name .. " · " .. tostring(upgrade.cost) .. " cash"
	keyPrompt.HoldDuration = 0.4
	keyPrompt.MaxActivationDistance = 10
	keyPrompt.RequiresLineOfSight = false
	keyPrompt.Enabled = false
	keyPrompt.Parent = keyPad
	keyPrompt.Triggered:Connect(function(triggeringPlayer)
		Pads.TryUpgrade(triggeringPlayer, player.UserId)
	end)
	prompts[upgrade.id] = keyPrompt

	local sign = Parts.block({
		name = "PlotSign",
		size = Vector3.new(1, 4, 1),
		position = Vector3.new(placements[2].x + 8, placements[2].top + 2, placements[2].z),
		color = Color3.fromRGB(255, 214, 140),
		parent = folder,
	})
	local board = Parts.billboard(sign, player.DisplayName .. "\nTier 0", Vector3.new(0, 3, 0), 7, 60)
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
			notify.Say(player, "Porch complete. Graveyard Rugby Rush is open. Next: the Crypt Key.")
		end
		refreshTier(player)
		Saves.Save(player)
	end)
end

function Pads.TryUpgrade(player: Player, ownerUserId: number)
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
	local upgrade = PorchPads.Upgrade
	local preview = PorchPads.PreviewUpgrade(plot.owned, base.GetTier(player), economy.GetCash(player))
	if not preview.ok then
		if preview.reason == "poor" then
			notify.Say(player, "Need " .. tostring(upgrade.cost) .. " cash. Graveyard Rugby Rush pays 150.")
		elseif preview.reason == "tier" then
			notify.Say(player, "Finish the porch (bench, ice bath, bag shrine) first.")
		elseif preview.reason == "already" then
			notify.Say(player, "The crypt already knows your feet.")
		end
		return
	end
	if PlayerLock.IsBusy(player) then
		notify.Say(player, "Syncing. Try the pad again.")
		return
	end
	PlayerLock.Try(player, function()
		local again = PorchPads.PreviewUpgrade(plot.owned, base.GetTier(player), economy.GetCash(player))
		if not again.ok or not again.owned or not again.cost then
			return
		end
		if not economy.TrySpend(player, again.cost, economy.Reasons.BasePad) then
			notify.Say(player, "Need " .. tostring(upgrade.cost) .. " cash.")
			return
		end
		plot.owned = again.owned
		base.SetPad(player, upgrade.id, true)
		spawnOwned(player, upgrade.id)
		base.SetTier(player, math.max(base.GetTier(player), upgrade.tier))
		notify.Say(player, "Crypt Key bought. Sore Foot Lava Crypt is open, behind the manor gate.")
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
	local upgrade = PorchPads.Upgrade
	if owned[upgrade.id] == true and PorchPads.OwnsAll(restored) then
		restored[upgrade.id] = true
		base.SetPad(player, upgrade.id, true)
		spawnOwned(player, upgrade.id)
	end
	plot.owned = restored
	if PorchPads.OwnsAll(restored) then
		local earned = if restored[upgrade.id] then upgrade.tier else 1
		base.SetTier(player, math.max(base.GetTier(player), earned))
	end
	local prompt = plot.prompts[upgrade.id]
	if prompt and not restored[upgrade.id] then
		prompt.Enabled = base.GetTier(player) >= upgrade.requiresTier
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
