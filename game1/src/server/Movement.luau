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

function Movement.ApplyWorld()
	workspace.Gravity = CourseLayout.GRAVITY
	workspace.FallenPartsDestroyHeight = -80
	local starter = game:GetService("StarterPlayer")
	starter.CharacterWalkSpeed = CourseLayout.WALK_SPEED
	starter.CharacterJumpHeight = CourseLayout.JUMP_HEIGHT
	starter.CharacterUseJumpPower = false
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
