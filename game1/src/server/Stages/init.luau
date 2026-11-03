--!strict
-- Runs the courses. Finish pays once per trip back to that course's start.
-- Each course checks BaseService.GetTier >= requiredTier (0, 1, 2).
-- Courses can have several checkpoints; the save stores "courseId" for the
-- first one and "courseId#n" for later ones (CourseLayout.EncodeCheckpoint).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CourseLayout = require(ReplicatedStorage.Shared.CourseLayout)
local Parts = require(script.Parent.Parts)
local PlayerLock = require(script.Parent.PlayerLock)
local Saves = require(script.Parent.Saves)

local Stages = {}

type Course = {
	id: string,
	displayName: string,
	payout: number,
	requiredTier: number,
	lockHint: string?,
	startPart: BasePart,
	checkpointPart: BasePart,
	checkpointParts: { BasePart }?,
	finishPart: BasePart,
	gate: BasePart?,
}

local courses: { Course } = {}
local economy: any = nil
local base: any = nil
local notify: any = nil
local spawnCFrame: CFrame = CFrame.new()
local readyFn: ((Player) -> boolean)? = nil

local runCourse: { [number]: string } = {}
local checkpointCFrame: { [number]: CFrame } = {}
local checkpointKey: { [number]: string } = {}
local clears: { [number]: { [string]: number } } = {}
local lastBounce: { [number]: number } = {}

local function isReady(player: Player): boolean
	return readyFn == nil or readyFn(player)
end

local function userIdOf(player: Player): number
	return player.UserId
end

local function pivot(player: Player, cf: CFrame)
	local character = player.Character
	if character then
		character:PivotTo(cf)
	end
end

local function courseById(id: string): Course?
	for _, course in courses do
		if course.id == id then
			return course
		end
	end
	return nil
end

local function unlocked(player: Player, course: Course): boolean
	return base.GetTier(player) >= course.requiredTier
end

local function lockedMessage(course: Course): string
	if course.requiredTier <= 1 then
		return course.displayName .. " is locked. Buy the bench, the ice bath, and the bag shrine."
	end
	return course.displayName .. " is locked. Buy the Crypt Key on your porch."
end

local function checkpointList(course: Course): { BasePart }
	return course.checkpointParts or { course.checkpointPart }
end

local function checkpointPartFor(course: Course, number: number): BasePart?
	local list = checkpointList(course)
	return list[math.clamp(number, 1, #list)]
end

local function clearCheckpoint(userId: number)
	checkpointCFrame[userId] = nil
	checkpointKey[userId] = nil
end

local function bounce(player: Player, message: string)
	local now = os.clock()
	local userId = userIdOf(player)
	if now - (lastBounce[userId] or 0) < 1 then
		return
	end
	lastBounce[userId] = now
	pivot(player, spawnCFrame)
	notify.Say(player, message)
end

local function arm(player: Player, course: Course)
	if not isReady(player) then
		if course.requiredTier <= 0 then
			runCourse[userIdOf(player)] = course.id
		end
		return
	end
	if not unlocked(player, course) then
		bounce(player, lockedMessage(course))
		return
	end
	local userId = userIdOf(player)
	if runCourse[userId] ~= course.id then
		-- Starting a different course drops the old course's checkpoint.
		clearCheckpoint(userId)
	end
	runCourse[userId] = course.id
end

local function bumpClear(userId: number, courseId: string)
	local row = clears[userId]
	if not row then
		row = {}
		clears[userId] = row
	end
	row[courseId] = (row[courseId] or 0) + 1
end

local function complete(player: Player, course: Course)
	local userId = userIdOf(player)
	if runCourse[userId] ~= course.id then
		return
	end
	if not isReady(player) then
		notify.Say(player, "Still clocking in your tips.")
		return
	end
	if not unlocked(player, course) then
		bounce(player, lockedMessage(course))
		return
	end
	if PlayerLock.IsBusy(player) then
		notify.Say(player, "Syncing. Step off the finish and back on.")
		return
	end
	PlayerLock.Try(player, function()
		if runCourse[userId] ~= course.id then
			return
		end
		runCourse[userId] = nil
		clearCheckpoint(userId)
		bumpClear(userId, course.id)
		economy.AddCash(player, course.payout, economy.Reasons.StageClear)
		notify.Say(
			player,
			course.displayName .. " delivered. +" .. tostring(course.payout) .. " cash."
		)
		Saves.Save(player)
	end)
	task.delay(0.6, function()
		if player.Parent then
			pivot(player, Parts.standCFrame(course.startPart))
			runCourse[userId] = course.id
		end
	end)
end

local function hookTouch(part: BasePart, handler: (Player) -> ())
	part.Touched:Connect(function(hit)
		local player = Parts.playerFromHit(hit)
		if player then
			handler(player)
		end
	end)
end

function Stages.Start(deps: {
	courses: { Course },
	economy: any,
	base: any,
	notify: any,
	spawnCFrame: CFrame,
	ready: ((Player) -> boolean)?,
})
	courses = deps.courses
	economy = deps.economy
	base = deps.base
	notify = deps.notify
	spawnCFrame = deps.spawnCFrame
	readyFn = deps.ready

	for _, course in courses do
		hookTouch(course.startPart, function(player)
			arm(player, course)
		end)
		for number, checkpointPart in checkpointList(course) do
			hookTouch(checkpointPart, function(player)
				if not isReady(player) then
					return
				end
				if not unlocked(player, course) then
					bounce(player, lockedMessage(course))
					return
				end
				local userId = userIdOf(player)
				if runCourse[userId] ~= course.id then
					return
				end
				local key = CourseLayout.EncodeCheckpoint(course.id, number)
				if checkpointKey[userId] == key then
					return
				end
				-- Never move a saved checkpoint backwards on the same course.
				local _, savedNumber = CourseLayout.DecodeCheckpoint(checkpointKey[userId])
				if checkpointKey[userId] ~= nil and savedNumber > number then
					return
				end
				checkpointKey[userId] = key
				checkpointCFrame[userId] = Parts.standCFrame(checkpointPart)
				notify.Say(player, "Checkpoint " .. tostring(number) .. ". The Count's feet thank you.")
			end)
		end
		hookTouch(course.finishPart, function(player)
			complete(player, course)
		end)
		if course.gate then
			local gate = course.gate
			hookTouch(gate, function(player)
				if not isReady(player) then
					return
				end
				if not unlocked(player, course) then
					bounce(player, lockedMessage(course))
				end
			end)
		end
	end
end

function Stages.Watch(player: Player)
	player.RespawnLocation = workspace:FindFirstChild("LobbySpawn") :: SpawnLocation
	player.CharacterAdded:Connect(function(character)
		local saved = checkpointCFrame[userIdOf(player)]
		if not saved then
			return
		end
		local root = character:WaitForChild("HumanoidRootPart", 5)
		if root and checkpointCFrame[userIdOf(player)] == saved then
			character:PivotTo(saved)
		end
	end)
end

function Stages.Forget(player: Player)
	local userId = userIdOf(player)
	runCourse[userId] = nil
	clearCheckpoint(userId)
	clears[userId] = nil
	lastBounce[userId] = nil
end

function Stages.Export(player: Player): { checkpoint: string, clears: { [string]: number } }
	local userId = userIdOf(player)
	local checkpoint = checkpointKey[userId] or ""
	local copy: { [string]: number } = table.clone(clears[userId] or {})
	return { checkpoint = checkpoint, clears = copy }
end

function Stages.Load(player: Player, data: any)
	if type(data) ~= "table" then
		return
	end
	local userId = userIdOf(player)
	if type(data.clears) == "table" then
		local row: { [string]: number } = {}
		for key, value in data.clears do
			if type(key) == "string" and type(value) == "number" and value >= 0 then
				row[key] = math.floor(value)
			end
		end
		clears[userId] = row
	end
	local courseId, number = CourseLayout.DecodeCheckpoint(data.checkpoint)
	if not courseId then
		return
	end
	local course = courseById(courseId)
	if not course then
		return
	end
	local part = checkpointPartFor(course, number)
	if not part then
		return
	end
	local list = checkpointList(course)
	checkpointKey[userId] = CourseLayout.EncodeCheckpoint(course.id, math.clamp(number, 1, #list))
	checkpointCFrame[userId] = Parts.standCFrame(part)
	runCourse[userId] = course.id
	if player.Character then
		player.Character:PivotTo(checkpointCFrame[userId])
	end
end

function Stages.Revive(player: Player): boolean
	local userId = userIdOf(player)
	local course = courseById(runCourse[userId] or "") or courseById("suburbs")
	if not course then
		return true
	end
	local cf = checkpointCFrame[userId] or Parts.standCFrame(course.startPart)
	runCourse[userId] = course.id
	pivot(player, cf)
	notify.Say(player, "Ankles iced. Back on the route.")
	return true
end

-- Fell onto the ground: back to the checkpoint (or course start / spawn), no death.
function Stages.Rescue(player: Player)
	local userId = userIdOf(player)
	local saved = checkpointCFrame[userId]
	if saved then
		pivot(player, saved)
		return
	end
	local course = courseById(runCourse[userId] or "")
	if course and unlocked(player, course) then
		pivot(player, Parts.standCFrame(course.startPart))
		return
	end
	pivot(player, spawnCFrame)
end

-- Used by the dev-product stage skip once the shop exists.
function Stages.SkipCurrent(player: Player): boolean
	local userId = userIdOf(player)
	local currentId = runCourse[userId]
	local course = if currentId then courseById(currentId) else courseById("suburbs")
	if not course or not unlocked(player, course) then
		return false
	end
	runCourse[userId] = course.id
	complete(player, course)
	return true
end

return Stages
