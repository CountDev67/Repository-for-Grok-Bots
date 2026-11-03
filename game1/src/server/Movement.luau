--!strict
-- Locks jump height, walkspeed, and gravity to the values CourseLayout tests.
-- A later speed-coil pass should call SetSpeedProvider instead of fighting this.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CourseLayout = require(ReplicatedStorage.Shared.CourseLayout)

local Movement = {}

local speedProvider: ((Player) -> number?)? = nil

function Movement.SetSpeedProvider(provider: (Player) -> number?)
	speedProvider = provider
end

-- World/StarterPlayer values also live in default.project.json; these writes are
-- best-effort because some properties are not script-writable at runtime.
local function trySet(object: any, property: string, value: any)
	local ok, err = pcall(function()
		object[property] = value
	end)
	if not ok then
		warn(`[Movement] skipped {property}: {err}`)
	end
end

function Movement.ApplyWorld()
	trySet(workspace, "Gravity", CourseLayout.GRAVITY)
	local starter = game:GetService("StarterPlayer")
	trySet(starter, "CharacterUseJumpPower", false)
	trySet(starter, "CharacterWalkSpeed", CourseLayout.WALK_SPEED)
	trySet(starter, "CharacterJumpHeight", CourseLayout.JUMP_HEIGHT)
end

function Movement.ApplyCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	humanoid.UseJumpPower = false
	humanoid.JumpHeight = CourseLayout.JUMP_HEIGHT
	local speed = CourseLayout.WALK_SPEED
	if speedProvider then
		local custom = speedProvider(player)
		if type(custom) == "number" and custom > 0 then
			speed = custom
		end
	end
	humanoid.WalkSpeed = speed
end

return Movement
