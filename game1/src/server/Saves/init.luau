--!strict
-- One DataStore, session-locked, with retries.
-- Studio without API access (or an unpublished place) falls back to an
-- in-memory session store for this server only. Every DataStore touch is
-- pcall-wrapped; the first access failure flips to memory and warns once.
-- The `base` field is whatever table BaseService.ExportState returns.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Lock = require(script.Lock)
local Document = require(script.Document)
local PlayerLock = require(script.Parent.PlayerLock)

local Saves = {}

local STORE_NAME = "CountCrackula_Player_v1"
local LOCK_TTL = 15 * 60
local AUTOSAVE_SECONDS = 60
local WRITE_ATTEMPTS = 4
local BUSY_RETRIES = 5
local BUSY_WAIT = 2

local store: any = nil
local usingMemory = false
local warnedMemory = false
local studioJob: string? = nil
local closing = false
local loaded: { [number]: boolean } = {}
local docs: { [number]: any } = {}
local collect: ((Player) -> any)? = nil
local apply: ((Player, any) -> ())? = nil

local function jobId(): string
	local id = game.JobId
	if type(id) == "string" and id ~= "" then
		return id
	end
	if studioJob == nil then
		studioJob = "studio-" .. tostring(os.time())
	end
	return studioJob
end

local function keyOf(player: Player): string
	return "player_" .. tostring(player.UserId)
end

local function memoryStore()
	local data: { [string]: any } = {}
	local memory = {}
	function memory:UpdateAsync(key: string, transform: (any) -> any)
		local old = data[key]
		local snapshot = if type(old) == "table" then Document.Reconcile(old) else nil
		if type(old) == "table" and type(old.session) == "table" then
			snapshot.session = { jobId = old.session.jobId, lockedAt = old.session.lockedAt }
		end
		local newValue = transform(snapshot)
		if newValue == nil then
			return nil
		end
		data[key] = newValue
		return newValue
	end
	return memory
end

local function isStudioAccessError(err: any): boolean
	local text = string.lower(tostring(err))
	return string.find(text, "studio access", 1, true) ~= nil
		or string.find(text, "api access", 1, true) ~= nil
		or string.find(text, "must publish", 1, true) ~= nil
		or string.find(text, "publish this place", 1, true) ~= nil
		or string.find(text, "not allowed", 1, true) ~= nil
		or string.find(text, "forbidden", 1, true) ~= nil
end

local function useMemory(reason: any)
	if not usingMemory then
		usingMemory = true
		store = memoryStore()
	end
	if not warnedMemory then
		warnedMemory = true
		warn(
			"[CountCrackula] DataStore unavailable ("
				.. tostring(reason)
				.. "). Profiles are kept in memory for this server only. Publish the place and enable"
				.. " Studio API access to save for real."
		)
	end
end

local function openLiveStore(): (boolean, any)
	return pcall(function()
		local service = game:GetService("DataStoreService")
		return service:GetDataStore(STORE_NAME)
	end)
end

local function update(key: string, transform: (any) -> any): (boolean, any)
	local lastErr = nil
	for attempt = 1, WRITE_ATTEMPTS do
		local ok, result = pcall(function()
			return store:UpdateAsync(key, transform)
		end)
		if ok then
			return true, result
		end
		lastErr = result
		if not usingMemory and isStudioAccessError(result) then
			-- Access went away mid-session (or was never there): fall back once
			-- and retry this write against memory.
			useMemory(result)
		end
		if attempt < WRITE_ATTEMPTS then
			task.wait(2 ^ (attempt - 1))
		end
	end
	warn("[CountCrackula] DataStore write failed: " .. tostring(lastErr))
	return false, lastErr
end

local function merge(doc, collected)
	if type(collected) ~= "table" then
		return
	end
	doc.cash = collected.cash
	doc.stages = collected.stages
	doc.streak = collected.streak
	doc.purchases = collected.purchases
	doc.offline = collected.offline
	doc.base = collected.base
end

function Saves.Configure(hooks: { collect: (Player) -> any, apply: (Player, any) -> () })
	collect = hooks.collect
	apply = hooks.apply
end

function Saves.IsLoaded(player: Player): boolean
	return loaded[player.UserId] == true
end

function Saves.UsingMemory(): boolean
	return usingMemory
end

function Saves.Start()
	local isStudio = RunService:IsStudio()
	local openOk, live = openLiveStore()
	if not openOk then
		useMemory(live)
	elseif game.PlaceId == 0 and isStudio then
		-- Unpublished Studio file: DataStores can never work here.
		useMemory("unpublished place")
	else
		local probeOk, probeErr = pcall(function()
			live:UpdateAsync("__probe", function()
				return nil
			end)
		end)
		if probeOk then
			store = live
		elseif isStudio or isStudioAccessError(probeErr) then
			useMemory(probeErr)
		else
			store = live
			warn("[CountCrackula] DataStore probe failed, will keep retrying: " .. tostring(probeErr))
		end
	end

	task.spawn(function()
		while not closing do
			task.wait(AUTOSAVE_SECONDS)
			if closing then
				break
			end
			for _, player in Players:GetPlayers() do
				if Saves.IsLoaded(player) and not PlayerLock.IsBusy(player) then
					PlayerLock.Try(player, function()
						Saves.Save(player)
					end)
				end
			end
		end
	end)

	local bound, bindErr = pcall(function()
		game:BindToClose(function()
			closing = true
			for _, player in Players:GetPlayers() do
				Saves.Close(player)
			end
		end)
	end)
	if not bound then
		warn("[CountCrackula] BindToClose unavailable: " .. tostring(bindErr))
	end
end

local function claim(player: Player): (boolean, any)
	local key = keyOf(player)
	local id = jobId()
	for attempt = 1, BUSY_RETRIES do
		local status = "busy"
		local ok, result = update(key, function(old)
			local session = if type(old) == "table" then old.session else nil
			local newSession, claimStatus = Lock.Claim(session, id, os.time(), LOCK_TTL)
			status = claimStatus
			if not newSession then
				return nil
			end
			local doc = if type(old) == "table" then old else Document.Template()
			doc.session = newSession
			return doc
		end)
		if not ok then
			return false, "error"
		end
		if status ~= "busy" and type(result) == "table" then
			return true, result
		end
		if attempt < BUSY_RETRIES then
			task.wait(BUSY_WAIT)
		end
	end
	return false, "busy"
end

function Saves.Open(player: Player): boolean
	if loaded[player.UserId] then
		return true
	end
	if store == nil then
		player:Kick("The tip jar is not open yet. Rejoin in a moment.")
		return false
	end
	local ok, result = claim(player)
	if not player.Parent then
		return false
	end
	if not ok then
		if result == "busy" then
			player:Kick("You're still clocked in on another server. Wait a minute and rejoin.")
		else
			player:Kick("The tip jar is stuck. Rejoin in a moment.")
		end
		return false
	end
	local doc = Document.Reconcile(result)
	docs[player.UserId] = doc
	if apply then
		local applied, err = pcall(apply, player, doc)
		if not applied then
			warn("[CountCrackula] profile apply failed: " .. tostring(err))
		end
	end
	if not player.Parent then
		Saves.Close(player)
		return false
	end
	loaded[player.UserId] = true
	PlayerLock.Try(player, function()
		Saves.Save(player)
	end)
	return true
end

function Saves.Save(player: Player): boolean
	if not loaded[player.UserId] then
		return false
	end
	local doc = docs[player.UserId]
	if not doc or not collect then
		return false
	end
	merge(doc, collect(player))
	local id = jobId()
	local status = "lost"
	local ok, result = update(keyOf(player), function(old)
		if type(old) ~= "table" or not Lock.Owns(old.session, id) then
			status = "lost"
			return nil
		end
		local newSession = Lock.Claim(old.session, id, os.time(), LOCK_TTL)
		if not newSession then
			status = "lost"
			return nil
		end
		old.cash = doc.cash
		old.stages = doc.stages
		old.streak = doc.streak
		old.purchases = doc.purchases
		old.offline = doc.offline
		old.base = doc.base
		old.session = newSession
		status = "ok"
		return old
	end)
	return ok and status == "ok" and type(result) == "table"
end

function Saves.Close(player: Player)
	local userId = player.UserId
	local doc = docs[userId]
	if not doc then
		loaded[userId] = nil
		return
	end
	if loaded[userId] and collect then
		merge(doc, collect(player))
	end
	if type(doc.offline) ~= "table" then
		doc.offline = { lastSeen = 0, settledLogoutAt = 0 }
	end
	doc.offline.lastSeen = os.time()
	local id = jobId()
	update(keyOf(player), function(old)
		if type(old) ~= "table" or not Lock.Owns(old.session, id) then
			return nil
		end
		old.cash = doc.cash
		old.stages = doc.stages
		old.streak = doc.streak
		old.purchases = doc.purchases
		old.offline = doc.offline
		old.base = doc.base
		old.session = nil
		return old
	end)
	docs[userId] = nil
	loaded[userId] = nil
end

return Saves
