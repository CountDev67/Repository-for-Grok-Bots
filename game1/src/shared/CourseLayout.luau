--!strict
-- Source of truth for the map. Pure data and math, no Instances, so Lune can
-- test it. World builds whatever this module describes.
-- Jump numbers match a default Roblox character:
-- JumpHeight 7.2, WalkSpeed 16, gravity 196.2.
--
-- Courses are lists of segments in course-local space:
--   forward = distance along the course heading, lat = sideways offset,
--   h = top height above BASE_TOP. `gap` is the edge-to-edge forward gap from
--   the previous segment. Moving segments carry `move` (axis f / l / y and an
--   amplitude); Transitions() checks every jump at the worst phase of motion.

local CourseLayout = {}

CourseLayout.JUMP_HEIGHT = 7.2
CourseLayout.WALK_SPEED = 16
CourseLayout.GRAVITY = 196.2
CourseLayout.BASE_TOP = 13
CourseLayout.GROUND_TOP = 2
CourseLayout.MAX_GAP = 8

export type Aabb = { x: number, z: number, sx: number, sz: number }

export type Move = { axis: string, amp: number, period: number }

export type Segment = {
	kind: string, -- start | pad | beam | mover | spinner | vanish | conveyor | ledge | hurdles | checkpoint | finish
	look: string,
	gap: number?,
	lat: number?,
	h: number,
	w: number,
	d: number,
	move: Move?,
	spin: number?,
	push: number?,
	wall: number?,
}

export type Palette = {
	base: { number },
	alt: { number },
	accent: { number },
	kill: { number },
	checkpoint: { number },
	finish: { number },
	trim: { number },
}

export type CourseSpec = {
	id: string,
	displayName: string,
	tagline: string,
	payout: number,
	requiredTier: number,
	lockHint: string,
	heading: string,
	originX: number,
	originZ: number,
	thickness: number,
	minClearance: number,
	palette: Palette,
	segments: { Segment },
}

export type Platform = {
	index: number,
	kind: string,
	look: string,
	role: string,
	checkpointNumber: number,
	forward: number,
	lat: number,
	h: number,
	x: number,
	z: number,
	yTop: number,
	yCenter: number,
	width: number,
	depth: number,
	thickness: number,
	sx: number,
	sz: number,
	move: Move?,
	spin: number?,
	push: number?,
	wall: number?,
}

local function seg(
	kind: string,
	look: string,
	gap: number,
	h: number,
	w: number,
	d: number,
	extra: { [string]: any }?
): Segment
	local s: any = { kind = kind, look = look, gap = gap, h = h, w = w, d = d }
	if extra then
		for key, value in extra do
			s[key] = value
		end
	end
	return s :: Segment
end

local COURSES: { CourseSpec } = {
	{
		id = "suburbs",
		displayName = "Suburbs Delivery",
		tagline = "Haunted night route",
		payout = 50,
		requiredTier = 0,
		lockHint = "",
		heading = "north",
		originX = 0,
		originZ = 70,
		thickness = 2,
		minClearance = 2,
		palette = {
			base = { 58, 96, 66 },
			alt = { 120, 84, 60 },
			accent = { 255, 140, 40 },
			kill = { 150, 70, 230 },
			checkpoint = { 255, 150, 40 },
			finish = { 190, 90, 255 },
			trim = { 232, 226, 214 },
		},
		segments = {
			seg("start", "lawn", 0, 0, 16, 14),
			seg("pad", "lawn", 5, 0, 12, 10),
			seg("pad", "porch", 4, 2, 10, 8),
			seg("pad", "porch", 4, 4, 10, 8),
			seg("beam", "fence", 4, 4, 2, 18),
			seg("pad", "pumpkin", 4, 4, 6, 6, { lat = 4 }),
			seg("pad", "pumpkin", 4, 5, 6, 6, { lat = -4 }),
			seg("checkpoint", "lawn", 4, 5, 12, 12),
			seg("mover", "drone", 5, 5, 8, 8, { move = { axis = "l", amp = 6, period = 5 } }),
			seg("pad", "porch", 5, 6, 10, 8),
			seg("vanish", "box", 4, 6, 6, 6, { lat = 3 }),
			seg("vanish", "box", 4, 6, 6, 6, { lat = -3 }),
			seg("vanish", "box", 4, 6, 6, 6, { lat = 3 }),
			seg("conveyor", "sidewalk", 4, 6, 12, 14, { push = 6 }),
			seg("checkpoint", "lawn", 4, 7, 12, 10),
			seg("spinner", "sprinkler", 4, 7, 14, 14, { spin = 1.6 }),
			seg("pad", "roof", 5, 9, 10, 8),
			seg("hurdles", "roof", 4, 9, 10, 16),
			seg("finish", "lawn", 4, 10, 14, 14),
		},
	},
	{
		id = "stage2",
		displayName = "Graveyard Rugby Rush",
		tagline = "Tombstone hops and coffin scrums",
		payout = 150,
		requiredTier = 1,
		lockHint = "Needs Porch Tier 1",
		heading = "east",
		originX = 59,
		originZ = 0,
		thickness = 2,
		minClearance = 1,
		palette = {
			base = { 92, 96, 108 },
			alt = { 74, 44, 38 },
			accent = { 90, 255, 150 },
			kill = { 80, 255, 140 },
			checkpoint = { 90, 255, 150 },
			finish = { 255, 210, 80 },
			trim = { 236, 236, 236 },
		},
		segments = {
			seg("start", "pitch", 0, 0, 12, 12),
			seg("pad", "tombstone", 5, 2, 4, 3),
			seg("pad", "tombstone", 5, 3, 4, 3, { lat = 3 }),
			seg("pad", "tombstone", 5, 4, 4, 3, { lat = -3 }),
			seg("pad", "coffin", 5, 4, 4, 10),
			seg("mover", "coffin", 5, 4, 4, 8, { move = { axis = "l", amp = 5, period = 4 } }),
			seg("pad", "coffin", 5, 5, 4, 8),
			seg("checkpoint", "pitch", 5, 5, 10, 10),
			seg("spinner", "tacklebar", 5, 5, 14, 14, { spin = 2.2 }),
			seg("beam", "crossbar", 5, 6, 2, 20),
			seg("vanish", "ghost", 5, 6, 5, 5, { lat = 2 }),
			seg("vanish", "ghost", 5, 7, 5, 5, { lat = -2 }),
			seg("vanish", "ghost", 5, 8, 5, 5, { lat = 2 }),
			seg("ledge", "tombwall", 5, 10, 4, 4, { lat = 4, wall = 1 }),
			seg("ledge", "tombwall", 5, 12, 4, 4, { lat = 4, wall = 1 }),
			seg("checkpoint", "pitch", 5, 12, 10, 10),
			seg("conveyor", "scrum", 5, 12, 12, 14, { push = 8 }),
			seg("hurdles", "pitch", 5, 12, 10, 18),
			seg("mover", "rugbyball", 6, 12, 8, 8, { move = { axis = "y", amp = 3, period = 4 } }),
			seg("finish", "pitch", 6, 13, 14, 14),
		},
	},
	{
		id = "stage3",
		displayName = "Sore Foot Lava Crypt",
		tagline = "Blood-moon lava. Mind the bunions.",
		payout = 400,
		requiredTier = 2,
		lockHint = "Needs the Crypt Key (Porch Tier 2)",
		heading = "south",
		originX = 0,
		originZ = -69,
		thickness = 2,
		minClearance = 1,
		palette = {
			base = { 74, 62, 72 },
			alt = { 46, 40, 48 },
			accent = { 255, 50, 70 },
			kill = { 255, 96, 36 },
			checkpoint = { 255, 60, 90 },
			finish = { 255, 200, 70 },
			trim = { 150, 60, 200 },
		},
		segments = {
			seg("start", "crypt", 0, 0, 12, 12),
			seg("pad", "crypt", 6, 1, 6, 6),
			seg("beam", "chain", 6, 1, 2, 16),
			seg("mover", "coffin", 6, 2, 6, 6, { move = { axis = "l", amp = 6, period = 4 } }),
			seg("mover", "coffin", 4, 2, 6, 6, { move = { axis = "f", amp = 2, period = 3 } }),
			seg("pad", "candle", 4, 3, 6, 6),
			seg("checkpoint", "crypt", 6, 3, 10, 10),
			seg("spinner", "candelabra", 6, 3, 14, 14, { spin = 2.8 }),
			seg("vanish", "cracked", 6, 4, 5, 5),
			seg("vanish", "cracked", 6, 4, 5, 5, { lat = 3 }),
			seg("vanish", "cracked", 6, 5, 5, 5, { lat = -3 }),
			seg("ledge", "brick", 6, 7, 4, 4, { lat = -4, wall = -1 }),
			seg("ledge", "brick", 6, 9, 4, 4, { lat = -4, wall = -1 }),
			seg("beam", "chain", 6, 9, 2, 20),
			seg("checkpoint", "crypt", 6, 9, 10, 10),
			seg("conveyor", "lavabelt", 6, 9, 12, 14, { push = 10 }),
			seg("hurdles", "crypt", 6, 9, 10, 18),
			seg("spinner", "candelabra", 6, 10, 14, 14, { spin = 3.2 }),
			seg("mover", "sarcophagus", 6, 11, 8, 8, { move = { axis = "y", amp = 3, period = 4 } }),
			seg("pad", "candle", 7, 11, 6, 6),
			seg("finish", "crypt", 6, 12, 14, 14),
		},
	},
}

local HEADINGS: { [string]: { fx: number, fz: number, rx: number, rz: number } } = {
	north = { fx = 0, fz = 1, rx = 1, rz = 0 },
	east = { fx = 1, fz = 0, rx = 0, rz = -1 },
	south = { fx = 0, fz = -1, rx = -1, rz = 0 },
	west = { fx = -1, fz = 0, rx = 0, rz = 1 },
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

function CourseLayout.Heading(spec: CourseSpec): { fx: number, fz: number, rx: number, rz: number }
	local heading = HEADINGS[spec.heading]
	if not heading then
		error(spec.id .. " has an unknown heading " .. tostring(spec.heading), 2)
	end
	return heading
end

-- Local (forward, lat) to world (x, z).
function CourseLayout.ToWorld(spec: CourseSpec, forward: number, lat: number): (number, number)
	local hd = CourseLayout.Heading(spec)
	return spec.originX + hd.fx * forward + hd.rx * lat, spec.originZ + hd.fz * forward + hd.rz * lat
end

-- Local (depth along forward, width along lat) to world (sx, sz).
function CourseLayout.WorldSize(spec: CourseSpec, depth: number, width: number): (number, number)
	local hd = CourseLayout.Heading(spec)
	return math.abs(hd.fx) * depth + math.abs(hd.rx) * width, math.abs(hd.fz) * depth + math.abs(hd.rz) * width
end

function CourseLayout.Lobby(): Aabb & { y: number, sy: number, top: number }
	local sy = 2
	return {
		x = 0,
		z = 0,
		sx = 90,
		sz = 110,
		sy = sy,
		y = CourseLayout.BASE_TOP - sy / 2,
		top = CourseLayout.BASE_TOP,
	}
end

function CourseLayout.SpawnPoint(): (number, number)
	return 0, -6
end

function CourseLayout.Platforms(spec: CourseSpec): { Platform }
	local segments = spec.segments
	local count = #segments
	if count < 3 then
		error(spec.id .. " needs a start, something to jump, and a finish", 2)
	end
	if segments[1].kind ~= "start" then
		error(spec.id .. " must begin with a start segment", 2)
	end
	if segments[count].kind ~= "finish" then
		error(spec.id .. " must end with a finish segment", 2)
	end

	local platforms: { Platform } = {}
	local forward = 0
	local checkpoints = 0
	for index, s in segments do
		if index > 1 then
			local previous = segments[index - 1]
			forward += previous.d / 2 + (s.gap or 0) + s.d / 2
		end
		local role = "jump"
		local number = 0
		if s.kind == "start" then
			role = "start"
		elseif s.kind == "finish" then
			role = "finish"
		elseif s.kind == "checkpoint" then
			role = "checkpoint"
			checkpoints += 1
			number = checkpoints
		end
		local lat = s.lat or 0
		local x, z = CourseLayout.ToWorld(spec, forward, lat)
		local sx, sz = CourseLayout.WorldSize(spec, s.d, s.w)
		local yTop = CourseLayout.BASE_TOP + s.h
		platforms[index] = {
			index = index,
			kind = s.kind,
			look = s.look,
			role = role,
			checkpointNumber = number,
			forward = forward,
			lat = lat,
			h = s.h,
			x = x,
			z = z,
			yTop = yTop,
			yCenter = yTop - spec.thickness / 2,
			width = s.w,
			depth = s.d,
			thickness = spec.thickness,
			sx = sx,
			sz = sz,
			move = s.move,
			spin = s.spin,
			push = s.push,
			wall = s.wall,
		}
	end
	return platforms
end

function CourseLayout.Checkpoints(spec: CourseSpec): { Platform }
	local found = {}
	for _, platform in CourseLayout.Platforms(spec) do
		if platform.role == "checkpoint" then
			table.insert(found, platform)
		end
	end
	return found
end

function CourseLayout.ObstacleCount(spec: CourseSpec): number
	local count = 0
	for _, s in spec.segments do
		if s.kind ~= "start" and s.kind ~= "finish" and s.kind ~= "checkpoint" then
			count += 1
		end
	end
	return count
end

function CourseLayout.JumpArcHeight(horizontalGap: number): number
	local gravity = CourseLayout.GRAVITY
	local verticalSpeed = math.sqrt(2 * gravity * CourseLayout.JUMP_HEIGHT)
	local timeToGap = horizontalGap / CourseLayout.WALK_SPEED
	return verticalSpeed * timeToGap - 0.5 * gravity * timeToGap * timeToGap
end

local function amp(platform: Platform, axis: string): number
	local move = platform.move
	if move and move.axis == axis then
		return move.amp
	end
	return 0
end

export type Transition = {
	fromIndex: number,
	toIndex: number,
	nominalGap: number,
	gap: number,
	step: number,
	clearance: number,
	closestGap: number,
}

-- Worst case over the motion of either end: the longest edge-to-edge reach
-- and the highest climb a player could be forced into.
function CourseLayout.Transitions(spec: CourseSpec): { Transition }
	local platforms = CourseLayout.Platforms(spec)
	local transitions: { Transition } = {}
	for index = 1, #platforms - 1 do
		local a = platforms[index]
		local b = platforms[index + 1]
		local nominal = (b.forward - b.depth / 2) - (a.forward + a.depth / 2)
		local gapF = nominal + amp(a, "f") + amp(b, "f")
		local latSep = math.max(
			0,
			math.abs(b.lat - a.lat) + amp(a, "l") + amp(b, "l") - (a.width + b.width) / 2
		)
		local gap = math.sqrt(gapF * gapF + latSep * latSep)
		local step = (b.h + amp(b, "y")) - (a.h - amp(a, "y"))
		transitions[index] = {
			fromIndex = index,
			toIndex = index + 1,
			nominalGap = nominal,
			gap = gap,
			step = step,
			clearance = CourseLayout.JumpArcHeight(gap) - step,
			closestGap = nominal - amp(a, "f") - amp(b, "f"),
		}
	end
	return transitions
end

-- World-space footprint including how far a mover can travel.
function CourseLayout.Footprint(spec: CourseSpec, platform: Platform): Aabb
	local depth = platform.depth + 2 * amp(platform, "f")
	local width = platform.width + 2 * amp(platform, "l")
	local sx, sz = CourseLayout.WorldSize(spec, depth, width)
	return { x = platform.x, z = platform.z, sx = sx, sz = sz }
end

function CourseLayout.CourseBounds(spec: CourseSpec, pad: number): Aabb
	local minX, maxX = math.huge, -math.huge
	local minZ, maxZ = math.huge, -math.huge
	for _, platform in CourseLayout.Platforms(spec) do
		local box = CourseLayout.Footprint(spec, platform)
		minX = math.min(minX, box.x - box.sx / 2)
		maxX = math.max(maxX, box.x + box.sx / 2)
		minZ = math.min(minZ, box.z - box.sz / 2)
		maxZ = math.max(maxZ, box.z + box.sz / 2)
	end
	return {
		x = (minX + maxX) / 2,
		z = (minZ + maxZ) / 2,
		sx = (maxX - minX) + pad * 2,
		sz = (maxZ - minZ) + pad * 2,
	}
end

function CourseLayout.Overlap(a: Aabb, b: Aabb): (number, number)
	local overlapX = math.min(a.x + a.sx / 2, b.x + b.sx / 2)
		- math.max(a.x - a.sx / 2, b.x - b.sx / 2)
	local overlapZ = math.min(a.z + a.sz / 2, b.z + b.sz / 2)
		- math.max(a.z - a.sz / 2, b.z - b.sz / 2)
	return overlapX, overlapZ
end

-- The walkway from the lobby edge to a course's start platform.
function CourseLayout.Approach(spec: CourseSpec): Aabb & { y: number, sy: number, length: number }
	local lobby = CourseLayout.Lobby()
	local first = CourseLayout.Platforms(spec)[1]
	local hd = CourseLayout.Heading(spec)
	local overlap = 3
	-- Distance from lobby center to the lobby edge along the heading.
	local edge = math.abs(hd.fx) * lobby.sx / 2 + math.abs(hd.fz) * lobby.sz / 2
	local lobbyCenterForward = (lobby.x - spec.originX) * hd.fx + (lobby.z - spec.originZ) * hd.fz
	local fromForward = lobbyCenterForward + edge - overlap
	local toForward = first.forward - first.depth / 2 + 2
	local length = toForward - fromForward
	local mid = (fromForward + toForward) / 2
	local x, z = CourseLayout.ToWorld(spec, mid, first.lat)
	local width = math.max(10, first.width - 2)
	local sx, sz = CourseLayout.WorldSize(spec, length, width)
	return {
		x = x,
		z = z,
		sx = sx,
		sz = sz,
		sy = 2,
		y = CourseLayout.BASE_TOP - 1,
		length = length,
	}
end

-- Kept for callers of the old API.
function CourseLayout.EastBridge(): Aabb & { y: number, sy: number }
	return CourseLayout.Approach(CourseLayout.Get("stage2"))
end

-- One sign per course, on an arch over the approach, facing the spawn.
function CourseLayout.EntranceSign(
	spec: CourseSpec
): { x: number, y: number, z: number, width: number, height: number, faceX: number, faceZ: number }
	local lobby = CourseLayout.Lobby()
	local hd = CourseLayout.Heading(spec)
	local edge = math.abs(hd.fx) * lobby.sx / 2 + math.abs(hd.fz) * lobby.sz / 2
	local first = CourseLayout.Platforms(spec)[1]
	local latWorldX = hd.rx * first.lat
	local latWorldZ = hd.rz * first.lat
	return {
		x = lobby.x + hd.fx * (edge - 2) + latWorldX,
		y = CourseLayout.BASE_TOP + 13,
		z = lobby.z + hd.fz * (edge - 2) + latWorldZ,
		width = 16,
		height = 5,
		faceX = -hd.fx,
		faceZ = -hd.fz,
	}
end

function CourseLayout.EncodeCheckpoint(courseId: string, number: number): string
	if number <= 1 then
		return courseId
	end
	return courseId .. "#" .. tostring(math.floor(number))
end

function CourseLayout.DecodeCheckpoint(value: any): (string?, number)
	if type(value) ~= "string" or value == "" then
		return nil, 0
	end
	local id, number = string.match(value, "^([%w_]+)#(%d+)$")
	if id and number then
		return id, math.max(1, tonumber(number) or 1)
	end
	if string.match(value, "^[%w_]+$") then
		return value, 1
	end
	return nil, 0
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

-- The tier-2 Crypt Key pad, beside the three porch pads.
function CourseLayout.UpgradePlacement(slotIndex: number): { x: number, z: number, size: number, top: number }
	local slotZ = (slotIndex - 1) * SLOT_SPACING
	return { x = -61, z = slotZ + 18, size = 6, top = CourseLayout.BASE_TOP }
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
