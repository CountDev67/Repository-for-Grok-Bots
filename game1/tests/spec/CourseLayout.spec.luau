--!strict
local harness = require("./harness")
local CourseLayout = require("../../src/shared/CourseLayout")

harness.test("both courses are 7 jumps with one checkpoint", function()
	local courses = CourseLayout.All()
	harness.assertEq(#courses, 2)
	for _, spec in courses do
		harness.assertEq(#spec.heights, 8, spec.id)
		harness.assertEq(#spec.gaps, 7, spec.id)
		harness.assertEq(#CourseLayout.Transitions(spec), 7, spec.id)
		local platforms = CourseLayout.Platforms(spec)
		harness.assertEq(platforms[1].role, "start")
		harness.assertEq(platforms[spec.checkpointIndex].role, "checkpoint")
		harness.assertEq(platforms[8].role, "finish")
	end
end)

harness.test("payouts and unlock tier match the slice", function()
	local suburbs = CourseLayout.Get("suburbs")
	local stage2 = CourseLayout.Get("stage2")
	harness.assertEq(suburbs.displayName, "Suburbs Delivery")
	harness.assertEq(suburbs.payout, 50)
	harness.assertEq(suburbs.requiredTier, 0)
	harness.assertEq(stage2.displayName, "Stage 2")
	harness.assertEq(stage2.payout, 150)
	harness.assertEq(stage2.requiredTier, 1)
	harness.assertTrue(stage2.width < suburbs.width)
end)

harness.test("every jump clears with the default Roblox jump", function()
	for _, spec in CourseLayout.All() do
		local minimum = if spec.id == "suburbs" then 2 else 1
		for _, jump in CourseLayout.Transitions(spec) do
			if jump.clearance < minimum then
				error(
					string.format(
						"%s jump %d clearance %.2f < %d (gap %d step %d)",
						spec.id,
						jump.fromIndex,
						jump.clearance,
						minimum,
						jump.gap,
						jump.step
					)
				)
			end
		end
		harness.assertTrue(spec.depth >= 12, spec.id .. " runway")
	end
end)

harness.test("stage 2 is a harder copy", function()
	local suburbs = CourseLayout.Get("suburbs")
	local stage2 = CourseLayout.Get("stage2")
	local function maxGap(spec): number
		local best = 0
		for _, gap in spec.gaps do
			best = math.max(best, gap)
		end
		return best
	end
	local function maxStep(spec): number
		local best = 0
		for index = 1, #spec.heights - 1 do
			best = math.max(best, spec.heights[index + 1] - spec.heights[index])
		end
		return best
	end
	harness.assertTrue(maxGap(stage2) > maxGap(suburbs))
	harness.assertTrue(maxStep(stage2) > maxStep(suburbs))
	harness.assertTrue(stage2.width < suburbs.width)
end)

harness.test("lobby connects to suburbs and the stage 2 bridge", function()
	local lobby = CourseLayout.Lobby()
	local suburbs = CourseLayout.Platforms(CourseLayout.Get("suburbs"))[1]
	local overlapX, overlapZ = CourseLayout.Overlap(lobby, {
		x = suburbs.x,
		z = suburbs.z,
		sx = suburbs.width,
		sz = suburbs.depth,
	})
	harness.assertTrue(overlapX > 2, "suburbs x overlap")
	harness.assertTrue(overlapZ >= 2 and overlapZ <= 8, "suburbs z overlap " .. tostring(overlapZ))

	local bridge = CourseLayout.EastBridge()
	harness.assertTrue(bridge.sx > 8, "bridge length")
	local bridgeLobbyX, bridgeLobbyZ = CourseLayout.Overlap(bridge, lobby)
	harness.assertTrue(bridgeLobbyX > 1 and bridgeLobbyZ > 1, "bridge meets lobby")
	local first = CourseLayout.Platforms(CourseLayout.Get("stage2"))[1]
	local bridgeCourseX, bridgeCourseZ = CourseLayout.Overlap(bridge, {
		x = first.x,
		z = first.z,
		sx = first.width,
		sz = first.depth,
	})
	harness.assertTrue(bridgeCourseX > 1 and bridgeCourseZ > 1, "bridge meets stage 2")
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
		for index, placement in placements do
			harness.assertTrue(
				CourseLayout.Contains(deck, placement.x, placement.z, placement.size / 2),
				"pad off deck " .. tostring(slot) .. ":" .. tostring(index)
			)
			local modelX, _, modelZ = CourseLayout.ModelPoint(placement)
			harness.assertTrue(CourseLayout.Contains(deck, modelX, modelZ, 3), "model off deck")
			for other = 1, index - 1 do
				local previous = placements[other]
				local dx = math.abs(placement.x - previous.x)
				local dz = math.abs(placement.z - previous.z)
				harness.assertTrue(dx >= placement.size or dz >= placement.size, "pads overlap")
			end
		end
	end
end)
