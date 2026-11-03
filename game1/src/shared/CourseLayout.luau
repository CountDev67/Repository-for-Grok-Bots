--!strict
-- Source of truth for the blockout map.
-- Jump numbers match a default Roblox character:
-- JumpHeight 7.2, WalkSpeed 16, gravity 196.2.
-- World.luau instances whatever this module describes.

local CourseLayout = {}

CourseLayout.JUMP_HEIGHT = 7.2
CourseLayout.WALK_SPEED = 16
CourseLayout.GRAVITY = 196.2
CourseLayout.BASE_TOP = 13

export type Aabb = { x: number, z: number, sx: number, sz: number }

export type Platform = {
	index: number,
	x: number,
	z: number,
	yTop: number,
	yCenter: number,
	width: number,
	depth: number,
	thickness: number,
	role: string,
}

export type CourseSpec = {
	id: string,
	displayName: string,
	payout: number,
	requiredTier: number,
	firstX: number,
	firstZ: number,
	width: number,
	depth: number,
	thickness: number,
	heights: { number },
	gaps: { number },
	checkpointIndex: number,
	color: { number },
	finishColor: { number },
	checkpointColor: { number },
}

local COURSES: { CourseSpec } = {
	{
		id = "suburbs",
		displayName = "Suburbs Delivery",
		payout = 50,
		requiredTier = 0,
		firstX = 0,
		firstZ = 38,
		width = 16,
		depth = 16,
		thickness = 2,
		heights = { 0, 0, 2, 2, 4, 3, 5, 5 },
		gaps = { 5, 5, 5, 5, 5, 5, 5 },
		checkpointIndex = 4,
		color = { 86, 168, 92 },
		finishColor = { 255, 196, 64 },
		checkpointColor = { 80, 170, 255 },
	},
	{
		id = "stage2",
		displayName = "Stage 2",
		payout = 150,
		requiredTier = 1,
		firstX = 72,
		firstZ = 0,
		width = 8,
		depth = 12,
		thickness = 2,
		heights = { 0, 3, 6, 6, 9, 9, 12, 14 },
		gaps = { 6, 6, 6, 6, 7, 6, 6 },
		checkpointIndex = 4,
		color = { 78, 88, 122 },
		finishColor = { 255, 120, 96 },
		checkpointColor = { 120, 190, 255 },
	},
}

function CourseLayout.All(): { CourseSpec }
	return COURSES
end

function CourseLayout.Get(id: string): CourseSpec
	for _, spec in COURSES do
		if spec.id == id then
			return spec
		end
	end
	error("unknown course " .. id, 2)
end

function CourseLayout.Lobby(): Aabb & { y: number, sy: number, top: number }
	local sy = 2
	local sx = 90
	local sz = 70
	return {
		x = 0,
		z = 0,
		sx = sx,
		sz = sz,
		sy = sy,
		y = CourseLayout.BASE_TOP - sy / 2,
		top = CourseLayout.BASE_TOP,
	}
end

function CourseLayout.Platforms(spec: CourseSpec): { Platform }
	local count = #spec.heights
	if #spec.gaps ~= count - 1 then
		error(spec.id .. " gap count must be platform count minus one", 2)
	end
	if spec.checkpointIndex <= 1 or spec.checkpointIndex >= count then
		error(spec.id .. " checkpoint must sit between the start and the finish", 2)
	end

	local platforms: { Platform } = {}
	local z = spec.firstZ
	for index = 1, count do
		if index > 1 then
			z += spec.depth + spec.gaps[index - 1]
		end
		local role = "jump"
		if index == 1 then
			role = "start"
		elseif index == spec.checkpointIndex then
			role = "checkpoint"
		elseif index == count then
			role = "finish"
		end
		local yTop = CourseLayout.BASE_TOP + spec.heights[index]
		platforms[index] = {
			index = index,
			x = spec.firstX,
			z = z,
			yTop = yTop,
			yCenter = yTop - spec.thickness / 2,
			width = spec.width,
			depth = spec.depth,
			thickness = spec.thickness,
			role = role,
		}
	end
	return platforms
end

function CourseLayout.JumpArcHeight(horizontalGap: number): number
	local gravity = CourseLayout.GRAVITY
	local verticalSpeed = math.sqrt(2 * gravity * CourseLayout.JUMP_HEIGHT)
	local timeToGap = horizontalGap / CourseLayout.WALK_SPEED
	return verticalSpeed * timeToGap - 0.5 * gravity * timeToGap * timeToGap
end

export type Transition = {
	fromIndex: number,
	toIndex: number,
	gap: number,
	step: number,
	clearance: number,
}

function CourseLayout.Transitions(spec: CourseSpec): { Transition }
	local platforms = CourseLayout.Platforms(spec)
	local transitions: { Transition } = {}
	for index = 1, #platforms - 1 do
		local step = spec.heights[index + 1] - spec.heights[index]
		local gap = spec.gaps[index]
		transitions[index] = {
			fromIndex = index,
			toIndex = index + 1,
			gap = gap,
			step = step,
			clearance = CourseLayout.JumpArcHeight(gap) - step,
		}
	end
	return transitions
end

function CourseLayout.Overlap(a: Aabb, b: Aabb): (number, number)
	local overlapX = math.min(a.x + a.sx / 2, b.x + b.sx / 2)
		- math.max(a.x - a.sx / 2, b.x - b.sx / 2)
	local overlapZ = math.min(a.z + a.sz / 2, b.z + b.sz / 2)
		- math.max(a.z - a.sz / 2, b.z - b.sz / 2)
	return overlapX, overlapZ
end

function CourseLayout.EastBridge(): Aabb & { y: number, sy: number }
	local lobby = CourseLayout.Lobby()
	local first = CourseLayout.Platforms(CourseLayout.Get("stage2"))[1]
	local overlap = 3
	local xMin = (lobby.x + lobby.sx / 2) - overlap
	local xMax = (first.x - first.width / 2) + overlap
	return {
		x = (xMin + xMax) / 2,
		z = first.z,
		sx = xMax - xMin,
		sz = math.max(14, first.depth),
		sy = 2,
		y = CourseLayout.BASE_TOP - 1,
	}
end

local PAD_X = -70
local PAD_OFFSETS = { -12, 0, 12 }
local PAD_SIZE = 8
local SLOT_SPACING = 40
local MAX_SLOTS = 6

function CourseLayout.MaxPorchSlots(): number
	return MAX_SLOTS
end

function CourseLayout.PadPlacements(
	slotIndex: number
): { { x: number, z: number, size: number, top: number } }
	local slotZ = (slotIndex - 1) * SLOT_SPACING
	local placements = {}
	for index, offset in PAD_OFFSETS do
		placements[index] = {
			x = PAD_X,
			z = slotZ + offset,
			size = PAD_SIZE,
			top = CourseLayout.BASE_TOP,
		}
	end
	return placements
end

function CourseLayout.ModelPoint(
	placement: { x: number, z: number, top: number }
): (number, number, number)
	return placement.x - 16, placement.top, placement.z
end

function CourseLayout.PorchDeck(): Aabb & { y: number, sy: number, top: number }
	local padHalf = PAD_SIZE / 2
	local zMin = 0 - 12 - padHalf - 8
	local zMax = (MAX_SLOTS - 1) * SLOT_SPACING + 12 + padHalf + 8
	local xMin = -98
	local xMax = -56
	local sy = 2
	return {
		x = (xMin + xMax) / 2,
		z = (zMin + zMax) / 2,
		sx = xMax - xMin,
		sz = zMax - zMin,
		sy = sy,
		y = CourseLayout.BASE_TOP - sy / 2,
		top = CourseLayout.BASE_TOP,
	}
end

function CourseLayout.PorchWalkway(): Aabb & { y: number, sy: number }
	local lobby = CourseLayout.Lobby()
	local deck = CourseLayout.PorchDeck()
	local overlap = 3
	local xMin = (deck.x + deck.sx / 2) - overlap
	local xMax = (lobby.x - lobby.sx / 2) + overlap
	return {
		x = (xMin + xMax) / 2,
		z = 0,
		sx = xMax - xMin,
		sz = 16,
		sy = 2,
		y = CourseLayout.BASE_TOP - 1,
	}
end

function CourseLayout.Contains(bounds: Aabb, x: number, z: number, half: number): boolean
	if x - half < bounds.x - bounds.sx / 2 then
		return false
	end
	if x + half > bounds.x + bounds.sx / 2 then
		return false
	end
	if z - half < bounds.z - bounds.sz / 2 then
		return false
	end
	if z + half > bounds.z + bounds.sz / 2 then
		return false
	end
	return true
end

return CourseLayout
