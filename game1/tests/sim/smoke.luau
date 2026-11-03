-- Smoke test: execute the built place's server boot under @lune/roblox with
-- light service stubs. Catches bad property names/types and nil errors.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local process = require("@lune/process")

local place = roblox.deserializePlace(fs.readFile(process.args[1]))
local real = place

local connections = 0
local function signal()
	return { Connect = function(_, fn) connections += 1 return { Disconnect = function() end, Connected = true } end, Wait = function() end }
end
local tweens = 0
local stubs = {
	TweenService = { Create = function(_, inst, info, goal) tweens += 1 for k, v in goal do inst[k] = v end return { Play = function() end } end },
	RunService = { Heartbeat = signal(), RenderStepped = signal(), IsStudio = function() return true end, IsServer = function() return true end, IsClient = function() return false end },
	Players = { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return {} end, GetPlayerFromCharacter = function() return nil end, GetPlayerByUserId = function() return nil end },
	DataStoreService = { GetDataStore = function() error("You must publish this place to the web to access DataStore.") end },
	MarketplaceService = {},
	Debris = { AddItem = function() end },
}
local gameProxy = setmetatable({
	GetService = function(_, name)
		if stubs[name] then return stubs[name] end
		return real:GetService(name)
	end,
	BindToClose = function() end,
	JobId = "",
	PlaceId = 0,
}, { __index = function(_, k) return real[k] end })

local workspace = real:GetService("Workspace")
delayed = {}
hooks = {}
toasts = {}
local warned = {}
local cache = {}
local loadModule

-- Lune instances have no events; route .Event:Connect through a stub.
local function patch(source)
	source = source:gsub("%.(%a+):Connect%(", function(ev) return ":__ev(\"" .. ev .. "\"):Connect(" end)
	return source
end

local function makeEnv(script)
	local env = {
		script = script, game = gameProxy, workspace = workspace,
		Instance = roblox.Instance, Vector3 = roblox.Vector3, Vector2 = roblox.Vector2, CFrame = roblox.CFrame,
		Color3 = roblox.Color3, UDim2 = roblox.UDim2, UDim = roblox.UDim, Enum = roblox.Enum,
		TweenInfo = { new = function(...) return { ... } end },
		Random = { new = function(seed) local r = { s = seed } function r:NextNumber(a, b) a = a or 0 b = b or 1 return a + math.random() * (b - a) end return r end },
		task = {
			spawn = function(fn, ...) if select("#", ...) > 0 then fn(...) end end,
			delay = function(_, fn, ...) table.insert(delayed, { fn, { ... } }) end,
			wait = function() end,
			defer = function() end,
		},
		warn = function(...) table.insert(warned, table.concat({ ... }, " ")) end,
		typeof = function(v) local t = typeof(v) return t end,
		require = function(m) return loadModule(m) end,
	}
	return setmetatable(env, { __index = _G })
end

-- Give Instances an :__ev method via a wrapper is not possible; instead patch source to call a helper.
loadModule = function(module)
	if cache[module] then return cache[module] end
	local source = patch(module.Source)
	source = source:gsub(':__ev%("(%a+)"%)', function(ev) return "" end)
	return nil
end

-- Simpler: patch '.X:Connect(' -> ' and __connect('
loadModule = function(module)
	if cache[module] ~= nil then return cache[module] end
	local source = module.Source
	source = source:gsub("([%w_%.%]%)\"]+)%.(%a+):Connect%(", function(obj, ev) return "__connect(" .. obj .. ", \"" .. ev .. "\", " end)
	source = source:gsub("([%w_%.%[%]]+):PivotTo%(", "__pivot(%1, ")
	source = source:gsub("([%w_%.]+):FireClient%(", "__fire(%1, ")
	source = source:gsub("%.Position(%s*=[^=])", ".__POSSET%1")
	source = source:gsub("([%w_][%w_%.]*)%.Position", "__pos(%1)")
	source = source:gsub("%.__POSSET", ".Position")
	local env = makeEnv(module)
	env.__pos = function(x) if typeof(x) == "Instance" then return x.CFrame.Position end return x.Position end
	env.__connect = function(obj, ev, fn) connections += 1 table.insert(hooks, { obj = obj, ev = ev, fn = fn }) return { Disconnect = function() end } end
	env.__pivot = function(obj, cf) _G.lastPivot = cf end
	env.__fire = function(remote, player, msg) table.insert(toasts, tostring(msg)) end
	local fn = luau.load(source, { debugName = module:GetFullName(), environment = env })
	local result = fn()
	cache[module] = result
	return result
end

local sss = real:GetService("ServerScriptService")
local server = sss:FindFirstChild("Server")
local ok, err = pcall(loadModule, server)
local count, kinds = 0, {}
for _, d in workspace:GetDescendants() do
	count += 1
	kinds[d.ClassName] = (kinds[d.ClassName] or 0) + 1
end
print("boot ok:", ok, err)
print("instances in workspace:", count, "connections:", connections, "tweens:", tweens)
for k, v in kinds do print("  ", k, v) end
print("lighting children:") for _, c in real:GetService("Lighting"):GetChildren() do print("  ", c.ClassName, c.Name) end
print("warnings:") for _, w in warned do print("  ", w) end

-- ---- simulated player ----
local player = roblox.Instance.new("Player")
player.Name = "Tester"
player.UserId = 777
player.DisplayName = "Tester"
player.Parent = real:GetService("Players")
local character = roblox.Instance.new("Model")
character.Name = "Tester"
local leg = roblox.Instance.new("Part")
leg.Parent = character
character.Parent = workspace
stubs.Players.GetPlayerFromCharacter = function(_, model) if model == character then return player end return nil end
stubs.Players.GetPlayerByUserId = function(_, id) if id == 777 then return player end return nil end
for _, h in hooks do
	if h.obj == stubs.Players and h.ev == "PlayerAdded" then h.fn(player) end
end
local Economy = cache[real:GetService("ReplicatedStorage").Shared.Economy]
local Saves = cache[server.Saves]
local Stages = cache[server.Stages]
local Base = cache[server.Base]
print("loaded:", Saves.IsLoaded(player), "memory:", Saves.UsingMemory(), "cash:", Economy.GetCash(player))

local function touch(part)
	for _, h in hooks do
		if h.obj == part and h.ev == "Touched" then h.fn(leg) end
	end
end
local function flush()
	local list = delayed delayed = {}
	for _, d in list do d[1](table.unpack(d[2])) end
end
local map = workspace.CountCrackulaMap
local function course(id)
	local f = map["Course_" .. id]
	local start, finish, cps = nil, nil, {}
	for _, c in f:GetChildren() do
		local role = c:GetAttribute("Role")
		if role == "start" then start = c elseif role == "finish" then finish = c
		elseif role == "checkpoint" then cps[c:GetAttribute("CheckpointNumber")] = c end
	end
	return start, cps, finish, f:FindFirstChild(id .. "_Gate")
end
local function run(id)
	local start, cps, finish = course(id)
	touch(start) for _, cp in ipairs(cps) do touch(cp) end
	local mid = Stages.Export(player).checkpoint
	touch(finish) flush()
	return mid
end
local function check(cond, msg) if not cond then error("FAIL: " .. msg) end print("pass:", msg) end

local mid = run("suburbs")
check(mid == "suburbs#2", "checkpoint 2 recorded as " .. tostring(mid))
check(Economy.GetCash(player) == 50, "suburbs pays 50")
run("stage2")
check(Economy.GetCash(player) == 50, "stage2 locked at tier 0")
for _ = 1, 5 do run("suburbs") end
check(Economy.GetCash(player) == 300, "six suburbs runs = 300")
local function prompt(padId)
	for _, pad in map:GetDescendants() do
		if pad:GetAttribute("PadId") == padId then
			for _, h in hooks do
				if h.obj and h.obj.Parent == pad and h.ev == "Triggered" then h.fn(player) return end
			end
		end
	end
	error("no prompt for " .. padId)
end
prompt("cryptkey")
check(Base.GetTier(player) == 0, "crypt key refused before porch")
prompt("bench") prompt("icebath") prompt("shrine")
check(Base.GetTier(player) == 1 and Economy.GetCash(player) == 0, "porch complete -> tier 1")
run("stage2")
check(Economy.GetCash(player) == 150, "stage2 pays 150 at tier 1")
run("stage3")
check(Economy.GetCash(player) == 150, "stage3 locked at tier 1")
for _ = 1, 9 do run("stage2") end
check(Economy.GetCash(player) == 1500, "ten stage2 runs = 1500")
prompt("cryptkey")
check(Base.GetTier(player) == 2 and Economy.GetCash(player) == 0, "crypt key -> tier 2")
local mid3 = run("stage3")
check(Economy.GetCash(player) == 400, "stage3 pays 400")
check(mid3 == "stage3#2", "stage3 checkpoint 2")
-- Save round trip: export then reload into a fresh run.
local start3, cps3 = course("stage3")
touch(start3) touch(cps3[2])
local exported = Stages.Export(player)
Stages.Forget(player)
Stages.Load(player, exported)
check(Stages.Export(player).checkpoint == "stage3#2", "checkpoint survives save/load")
Stages.Load(player, { checkpoint = "stage2", clears = {} })
check(Stages.Export(player).checkpoint == "stage2", "old-format checkpoint loads")
-- rescue from the ground goes to the checkpoint without dying
pcall(function() player.Character = character end)
_G.lastPivot = nil
touch(map.GraveyardGround)
check(_G.lastPivot ~= nil, "ground rescue pivots the player")
print("toasts:", #toasts) for i = math.max(1, #toasts - 6), #toasts do print("   ", toasts[i]) end
print("warnings after play:", #warned)
local out = {}
for _, d in workspace:GetDescendants() do
	if d:IsA("BasePart") and d.Transparency < 0.95 then
		local cf = d.CFrame
		local p = cf.Position
		local rx = cf.RightVector local lv = cf.LookVector local uv = cf.UpVector
		local c = d.Color
		table.insert(out, string.format("%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%.3f,%d,%d,%d,%s", p.X, p.Y, p.Z, d.Size.X, d.Size.Y, d.Size.Z, rx.X, rx.Y, rx.Z, uv.X, uv.Y, uv.Z, lv.X, lv.Y, lv.Z, math.floor(c.R*255), math.floor(c.G*255), math.floor(c.B*255), d.Name))
	end
end
fs.writeFile("parts.csv", table.concat(out, "\n"))
