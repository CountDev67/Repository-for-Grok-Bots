--!strict
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Economy = require(ReplicatedStorage.Shared.Economy)
local Movement = require(script.Movement)
local Notify = require(script.Notify)
local Leaderstats = require(script.Leaderstats)
local BaseService = require(script.Base)
local World = require(script.World)
local Stages = require(script.Stages)
local Pads = require(script.Pads)
local Saves = require(script.Saves)
local Shop = require(script.Shop)
local Retention = require(script.Retention)
local Gear = require(script.Gear)
local PlayerLock = require(script.PlayerLock)
local StudioTools = require(script.StudioTools)

Players.RespawnTime = 2.5
workspace.StreamingEnabled = false
Movement.ApplyWorld()

Lighting.ClockTime = 17.6
Lighting.Brightness = 2.2
Lighting.Ambient = Color3.fromRGB(110, 96, 112)
Lighting.OutdoorAmbient = Color3.fromRGB(160, 130, 116)
Lighting.FogColor = Color3.fromRGB(255, 176, 140)
Lighting.FogEnd = 900

local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.28
atmosphere.Offset = 0.15
atmosphere.Color = Color3.fromRGB(255, 186, 156)
atmosphere.Decay = Color3.fromRGB(180, 120, 110)
atmosphere.Glare = 0.15
atmosphere.Haze = 1.2
atmosphere.Parent = Lighting

Notify.Start()
Leaderstats.Bind(Economy)

local world = World.Build()
World.HookKills(world.folder)

Saves.Configure({
	collect = function(player)
		return {
			cash = Economy.GetCash(player),
			stages = Stages.Export(player),
			streak = Retention.Export(player),
			purchases = Shop.Export(player),
			offline = Retention.ExportOffline(player),
			base = BaseService.ExportState(player),
		}
	end,
	apply = function(player, data)
		Economy.Hydrate(player, if type(data.cash) == "number" then data.cash else 0)
		Stages.Load(player, data.stages)
		Retention.Load(player, data.streak, data.offline)
		Shop.Load(player, data.purchases)
		BaseService.ImportState(player, data.base)
		Pads.Load(player, BaseService.GetPads(player))
	end,
})
Saves.Start()

Stages.Start({
	courses = world.courses,
	economy = Economy,
	base = BaseService,
	notify = Notify,
	spawnCFrame = world.spawnCFrame,
	ready = function(player)
		return Saves.IsLoaded(player)
	end,
})

Pads.Start({
	economy = Economy,
	base = BaseService,
	notify = Notify,
	folder = world.folder,
})

Shop.Start({
	notify = Notify,
	hasSock = Retention.HasSock,
})

Retention.Start({
	folder = world.folder,
	notify = Notify,
	base = BaseService,
	onDress = function(player)
		Shop.RefreshCharacter(player)
	end,
})

StudioTools.Start(Economy, Notify, Shop)

local function dress(player: Player, character: Model)
	Movement.ApplyCharacter(player, character)
	Gear.Apply(player, character, {
		foam = Shop.OwnsPass(player, "foamBlaster"),
		sock = Retention.HasSock(player),
	})
end

local function onPlayer(player: Player)
	Leaderstats.Attach(player, 0)
	player.RespawnLocation = world.spawn
	Pads.CreatePlot(player)
	Stages.Watch(player)
	player.CharacterAdded:Connect(function(character)
		dress(player, character)
	end)
	if not Saves.Open(player) or not player.Parent then
		return
	end
	if player.Character then
		dress(player, player.Character)
	end
end

local function onRemoving(player: Player)
	Saves.Close(player)
	Economy.Forget(player)
	BaseService.Forget(player)
	Stages.Forget(player)
	Pads.Forget(player)
	Shop.Forget(player)
	Retention.Forget(player)
	PlayerLock.Forget(player)
end

Players.PlayerAdded:Connect(onPlayer)
Players.PlayerRemoving:Connect(onRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayer, player)
end
