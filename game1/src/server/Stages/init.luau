--!strict
-- Runs the two blockout courses. Finish pays once per trip back to that
-- course's start. Stage 2 checks BaseService.GetTier >= requiredTier (1).

local Parts = require(script.Parent.Parts)
local PlayerLock = require(script.Parent.PlayerLock)
local Saves = require(script.Parent.Saves)

local Stages = {}

type Course = {
	id: string,
	displayName: string,
	payout: number,
	requiredTier: number,
	startPart: BasePart,
	checkpointPart: BasePart,
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
		bounce(player, "Stage 2 is locked. Buy the bench, the ice bath, and the bag shrine.")
		return
	end
	runCourse[userIdOf(player)] = course.id
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
		bounce(player, "Stage 2 is locked. Finish the porch first.")
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
		checkpointCFrame[userId] = nil
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
		hookTouch(course.checkpointPart, function(player)
			if not isReady(player) then
				return
			end
			if not unlocked(player, course) then
				bounce(player, "Stage 2 is locked. Finish the porch first.")
				return
			end
			if runCourse[userIdOf(player)] ~= course.id then
				return
			end
			local stand = Parts.standCFrame(course.checkpointPart)
			local existing = checkpointCFrame[userIdOf(player)]
			if existing and (existing.Position - stand.Position).Magnitude < 2 then
				return
			end
			checkpointCFrame[userIdOf(player)] = stand
			notify.Say(player, "Checkpoint. The Count's feet thank you.")
		end)
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
					bounce(player, "Stage 2 opens when the porch has all three buys.")
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
	checkpointCFrame[userId] = nil
	clears[userId] = nil
	lastBounce[userId] = nil
end

function Stages.Export(player: Player): { checkpoint: string, clears: { [string]: number } }
	local userId = userIdOf(player)
	local checkpoint = ""
	local cf = checkpointCFrame[userId]
	if cf then
		for _, course in courses do
			local stand = Parts.standCFrame(course.checkpointPart)
			if (stand.Position - cf.Position).Magnitude < 2 then
				checkpoint = course.id
				break
			end
		end
	end
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
	local courseId = data.checkpoint
	if type(courseId) ~= "string" or courseId == "" then
		return
	end
	local course = courseById(courseId)
	if not course then
		return
	end
	checkpointCFrame[userId] = Parts.standCFrame(course.checkpointPart)
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
