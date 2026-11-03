--!strict
local harness = require("./harness")
local CourseLayout = require("../../src/shared/CourseLayout")

local function box(platform): CourseLayout.Aabb
	return { x = platform.x, z = platform.z, sx = platform.sx, sz = platform.sz }
end

harness.test("three courses with 15-20 obstacles and mid-course checkpoints", function()
	local courses = CourseLayout.All()
	harness.assertEq(#courses, 3)
	for _, spec in courses do
		local obstacles = CourseLayout.ObstacleCount(spec)
		harness.assertTrue(obstacles >= 15 and obstacles <= 20, spec.id .. " obstacles " .. tostring(obstacles))
		local platforms = CourseLayout.Platforms(spec)
		harness.assertEq(platforms[1].role, "start", spec.id)
		harness.assertEq(platforms[#platforms].role, "finish", spec.id)
		local checkpoints = CourseLayout.Checkpoints(spec)
		harness.assertTrue(#checkpoints >= 2, spec.id .. " needs two checkpoints")
		for number, checkpoint in checkpoints do
			harness.assertEq(checkpoint.checkpointNumber, number)
			harness.assertTrue(checkpoint.index > 2 and checkpoint.index < #platforms - 1, spec.id .. " checkpoint placement")
			harness.assertTrue(checkpoint.width >= 10 and checkpoint.depth >= 10, spec.id .. " checkpoint is roomy")
		end
		harness.assertEq(#CourseLayout.Transitions(spec), #platforms - 1)
	end
end)

harness.test("payouts and unlock tiers climb", function()
	local suburbs = CourseLayout.Get("suburbs")
	local stage2 = CourseLayout.Get("stage2")
	local stage3 = CourseLayout.Get("stage3")
	harness.assertEq(suburbs.displayName, "Suburbs Delivery")
	harness.assertEq(suburbs.payout, 50)
	harness.assertEq(suburbs.requiredTier, 0)
	harness.assertEq(stage2.displayName, "Graveyard Rugby Rush")
	harness.assertEq(stage2.payout, 150)
	harness.assertEq(stage2.requiredTier, 1)
	harness.assertEq(stage3.displayName, "Sore Foot Lava Crypt")
	harness.assertTrue(stage3.payout > stage2.payout, "stage 3 pays more")
	harness.assertEq(stage3.requiredTier, 2)
end)

harness.test("every jump clears with the default Roblox jump, at the worst phase of motion", function()
	for _, spec in CourseLayout.All() do
		for _, jump in CourseLayout.Transitions(spec) do
			local where = string.format(
				"%s jump %d->%d (gap %.2f step %.1f clearance %.2f)",
				spec.id,
				jump.fromIndex,
				jump.toIndex,
				jump.gap,
				jump.step,
				jump.clearance
			)
			harness.assertTrue(jump.clearance >= spec.minClearance, where .. " too high or too far")
			harness.assertTrue(jump.gap <= CourseLayout.MAX_GAP, where .. " longer than MAX_GAP")
			harness.assertTrue(jump.nominalGap >= 2, where .. " platforms nearly touch")
			harness.assertTrue(jump.closestGap >= 1, where .. " movers collide")
		end
	end
	harness.assertEq(CourseLayout.Get("suburbs").minClearance, 2)
end)

harness.test("the jump math matches a default character", function()
	-- Peak of a 7.2-stud jump; zero gap means no forward travel.
	harness.assertTrue(math.abs(CourseLayout.JumpArcHeight(0)) < 1e-9)
	local v = math.sqrt(2 * 196.2 * 7.2)
	local apexDistance = 16 * v / 196.2
	harness.assertTrue(math.abs(CourseLayout.JumpArcHeight(apexDistance) - 7.2) < 1e-6)
	-- A flat 9-stud gap is out of reach.
	harness.assertTrue(CourseLayout.JumpArcHeight(9) < 0)
end)

harness.test("each course uses the full obstacle toolbox and gets harder", function()
	local function kinds(spec): { [string]: boolean }
		local found = {}
		for _, s in spec.segments do
			found[s.kind] = true
		end
		return found
	end
	for _, spec in CourseLayout.All() do
		local found = kinds(spec)
		for _, kind in { "mover", "spinner", "vanish", "conveyor", "beam", "hurdles" } do
			harness.assertTrue(found[kind] == true, spec.id .. " missing " .. kind)
		end
	end
	harness.assertTrue(kinds(CourseLayout.Get("stage2")).ledge == true, "stage 2 wall hops")
	harness.assertTrue(kinds(CourseLayout.Get("stage3")).ledge == true, "stage 3 wall hops")

	local function averageGap(spec): number
		local total = 0
		local transitions = CourseLayout.Transitions(spec)
		for _, jump in transitions do
			total += jump.gap
		end
		return total / #transitions
	end
	local function smallestPad(spec): number
		local best = math.huge
		for _, s in spec.segments do
			if s.kind ~= "beam" then
				best = math.min(best, s.w * s.d)
			end
		end
		return best
	end
	harness.assertTrue(averageGap(CourseLayout.Get("stage2")) > averageGap(CourseLayout.Get("suburbs")))
	harness.assertTrue(averageGap(CourseLayout.Get("stage3")) > averageGap(CourseLayout.Get("stage2")))
	harness.assertTrue(smallestPad(CourseLayout.Get("stage2")) < smallestPad(CourseLayout.Get("suburbs")))
end)

harness.test("platforms never overlap, within or across courses", function()
	local all: { { id: string, box: CourseLayout.Aabb, index: number } } = {}
	for _, spec in CourseLayout.All() do
		for _, platform in CourseLayout.Platforms(spec) do
			table.insert(all, { id = spec.id, box = CourseLayout.Footprint(spec, platform), index = platform.index })
		end
	end
	for i = 1, #all do
		for j = i + 1, #all do
			local ox, oz = CourseLayout.Overlap(all[i].box, all[j].box)
			if ox > 0 and oz > 0 then
				error(string.format("%s:%d overlaps %s:%d", all[i].id, all[i].index, all[j].id, all[j].index))
			end
		end
	end
end)

harness.test("courses stay off the lobby and porch, and out of each other's kill floors", function()
	local lobby = CourseLayout.Lobby()
	local deck = CourseLayout.PorchDeck()
	local specs = CourseLayout.All()
	for _, spec in specs do
		for _, platform in CourseLayout.Platforms(spec) do
			for _, other in { lobby, deck } do
				local ox, oz = CourseLayout.Overlap(box(platform), other)
				harness.assertFalse(ox > 0 and oz > 0, spec.id .. " platform on the plaza " .. tostring(platform.index))
			end
		end
	end
	for i = 1, #specs do
		for j = i + 1, #specs do
			local ox, oz = CourseLayout.Overlap(CourseLayout.CourseBounds(specs[i], 12), CourseLayout.CourseBounds(specs[j], 12))
			harness.assertFalse(ox > 0 and oz > 0, specs[i].id .. " and " .. specs[j].id .. " kill floors overlap")
		end
		local ox, oz = CourseLayout.Overlap(CourseLayout.CourseBounds(specs[i], 12), deck)
		harness.assertFalse(ox > 0 and oz > 0, specs[i].id .. " kill floor under the porch")
	end
end)

harness.test("each start is a short walk from spawn, fanned out, joined by an approach", function()
	local spawnX, spawnZ = CourseLayout.SpawnPoint()
	local lobby = CourseLayout.Lobby()
	harness.assertTrue(CourseLayout.Contains(lobby, spawnX, spawnZ, 4), "spawn on the plaza")
	local headings: { [string]: boolean } = {}
	local starts = {}
	for _, spec in CourseLayout.All() do
		harness.assertTrue(headings[spec.heading] == nil, "two courses share a heading")
		headings[spec.heading] = true
		local first = CourseLayout.Platforms(spec)[1]
		local distance = math.sqrt((first.x - spawnX) ^ 2 + (first.z - spawnZ) ^ 2)
		harness.assertTrue(distance < 90, spec.id .. " start is " .. tostring(distance) .. " studs away")
		table.insert(starts, first)

		local approach = CourseLayout.Approach(spec)
		harness.assertTrue(approach.length >= 8, spec.id .. " approach length")
		local ax, az = CourseLayout.Overlap(approach, lobby)
		harness.assertTrue(ax > 1 and az > 1, spec.id .. " approach meets lobby")
		local sx, sz = CourseLayout.Overlap(approach, box(first))
		harness.assertTrue(sx > 1 and sz > 1, spec.id .. " approach meets start")
		harness.assertEq(approach.y + approach.sy / 2, CourseLayout.BASE_TOP, spec.id .. " approach flush")
	end
	for i = 1, #starts do
		for j = i + 1, #starts do
			local distance = math.sqrt((starts[i].x - starts[j].x) ^ 2 + (starts[i].z - starts[j].z) ^ 2)
			harness.assertTrue(distance > 60, "starts are stacked")
		end
	end
	local east = CourseLayout.EastBridge()
	harness.assertTrue(east.sx > 8, "east bridge length")
end)

harness.test("entrance signs face the spawn and never overlap", function()
	local spawnX, spawnZ = CourseLayout.SpawnPoint()
	local signs = {}
	for _, spec in CourseLayout.All() do
		local sign = CourseLayout.EntranceSign(spec)
		local toSpawnX, toSpawnZ = spawnX - sign.x, spawnZ - sign.z
		local length = math.sqrt(toSpawnX ^ 2 + toSpawnZ ^ 2)
		local dot = (sign.faceX * toSpawnX + sign.faceZ * toSpawnZ) / length
		harness.assertTrue(dot > 0.8, spec.id .. " sign faces spawn")
		harness.assertTrue(sign.y - sign.height / 2 > CourseLayout.BASE_TOP + 7, spec.id .. " sign clears heads")
		table.insert(signs, sign)
	end
	for i = 1, #signs do
		for j = i + 1, #signs do
			local distance = math.sqrt((signs[i].x - signs[j].x) ^ 2 + (signs[i].z - signs[j].z) ^ 2)
			harness.assertTrue(distance > (signs[i].width + signs[j].width) / 2 + 4, "signs overlap")
		end
	end
end)

harness.test("checkpoint save keys round-trip and stay backward compatible", function()
	harness.assertEq(CourseLayout.EncodeCheckpoint("stage2", 1), "stage2")
	harness.assertEq(CourseLayout.EncodeCheckpoint("stage2", 2), "stage2#2")
	local id, number = CourseLayout.DecodeCheckpoint("stage2#2")
	harness.assertEq(id, "stage2")
	harness.assertEq(number, 2)
	id, number = CourseLayout.DecodeCheckpoint("suburbs")
	harness.assertEq(id, "suburbs")
	harness.assertEq(number, 1)
	id, number = CourseLayout.DecodeCheckpoint("")
	harness.assertEq(id, nil)
	harness.assertEq(number, 0)
	id = CourseLayout.DecodeCheckpoint("bad value!")
	harness.assertEq(id, nil)
	id = CourseLayout.DecodeCheckpoint(42)
	harness.assertEq(id, nil)
end)

harness.test("porch walkway reaches the deck and pads sit on it", function()
	local lobby = CourseLayout.Lobby()
	local deck = CourseLayout.PorchDeck()
	local walkway = CourseLayout.PorchWalkway()
	local walkLobbyX, walkLobbyZ = CourseLayout.Overlap(walkway, lobby)
	local walkDeckX, walkDeckZ = CourseLayout.Overlap(walkway, deck)
	harness.assertTrue(walkway.sx > 4)
	harness.assertTrue(walkLobbyX > 1 and walkLobbyZ > 1, "walkway meets lobby")
	harness.assertTrue(walkDeckX > 1 and walkDeckZ > 1, "walkway meets deck")

	for slot = 1, CourseLayout.MaxPorchSlots() do
		local placements = CourseLayout.PadPlacements(slot)
		harness.assertEq(#placements, 3)
		local upgrade = CourseLayout.UpgradePlacement(slot)
		harness.assertTrue(CourseLayout.Contains(deck, upgrade.x, upgrade.z, upgrade.size / 2), "crypt key pad off deck")
		for index, placement in placements do
			harness.assertTrue(
				CourseLayout.Contains(deck, placement.x, placement.z, placement.size / 2),
				"pad off deck " .. tostring(slot) .. ":" .. tostring(index)
			)
			local modelX, _, modelZ = CourseLayout.ModelPoint(placement)
			harness.assertTrue(CourseLayout.Contains(deck, modelX, modelZ, 3), "model off deck")
			local ux, uz = CourseLayout.Overlap(
				{ x = upgrade.x, z = upgrade.z, sx = upgrade.size, sz = upgrade.size },
				{ x = placement.x, z = placement.z, sx = placement.size, sz = placement.size }
			)
			harness.assertFalse(ux > 0 and uz > 0, "crypt key pad overlaps a pad")
			for other = 1, index - 1 do
				local previous = placements[other]
				local dx = math.abs(placement.x - previous.x)
				local dz = math.abs(placement.z - previous.z)
				harness.assertTrue(dx >= placement.size or dz >= placement.size, "pads overlap")
			end
		end
		if slot > 1 then
			local previousUpgrade = CourseLayout.UpgradePlacement(slot - 1)
			for _, placement in placements do
				local ux, uz = CourseLayout.Overlap(
					{ x = previousUpgrade.x, z = previousUpgrade.z, sx = previousUpgrade.size, sz = previousUpgrade.size },
					{ x = placement.x, z = placement.z, sx = placement.size, sz = placement.size }
				)
				harness.assertFalse(ux > 0 and uz > 0, "crypt key pad overlaps the next slot")
			end
		end
	end
end)
