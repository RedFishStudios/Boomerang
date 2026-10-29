--[[
	BoomerangCurveLibrary (T-141)

	Thrown boomerangs fly a gentle arc instead of a straight line. The arc still passes through the point the player aimed at
	(the aim arrow stays straight and points at it): the boomerang leaves a few degrees to one side of the aim line and turns
	steadily back across it, and keeps turning the same way after passing the aimed point.

	The arc is a constant turn rate per stud flown ("curvature", radians per stud, positive = turning left / counterclockwise
	seen from above). For a chord of length c and a launch angle a off the chord, the circle through both ends has
	curvature 2*sin(a)/c, so the boomerang crosses the aim line again exactly c studs ahead.

	SERVER AUTHORITY
	- Only the server decides the curve (side and angle) when it accepts the throw (Boomerang.throw): from the thrower's
	  movement on the server (Humanoid.MoveDirection, replicated input) and the aim distance the client asked for (clamped).
	- The decision is replicated with the spawn (ThrownBoomerangSpawned) and every snapshot; the server and every client
	  then apply the same turn in the same fixed step (Boomerang simulateStep), so a client only predicts where it goes.
	- Lag compensation: a spawn or snapshot that arrives late is advanced along the ARC (not a straight line) by the time it
	  spent in transit (advanceAlongArc), heading included, so the client's prediction lines up with the server's state.

	Pure math only; no state.
]]

local BoomerangCurveLibrary = {}

-- ============================================================================================================================
-- INTERNAL CONFIG
-- ============================================================================================================================
-- // Launch angle off the aim line, in degrees. Standing still: random between MIN and MAX. Moving sideways: scales with
-- // how much of the movement is sideways to the aim (just past the threshold = MIN, fully sideways = MAX).
BoomerangCurveLibrary.MIN_BEND_DEGREES = 4
BoomerangCurveLibrary.MAX_BEND_DEGREES = 19
-- // How much of the movement must be sideways to the aim (0..1, the sideways part of Humanoid.MoveDirection) for it to pick
-- // the curve's side. Below this (standing still, or walking straight toward/away from the aim) the side is random.
BoomerangCurveLibrary.MOVE_SIDEWAYS_THRESHOLD = 0.3
-- // true: moving left makes the arc bow out to the left (it leaves left of the aim line, like momentum carried from the
-- // run, and swings back right through the aimed point). false: it leaves right and hooks left.
BoomerangCurveLibrary.BOW_TOWARD_MOVEMENT = true
-- // The aimed distance is clamped to this range (studs) before the curve is worked out. The minimum keeps a point aimed
-- // right next to the player from making a tight loop; the maximum is also capped by how far the throw can fly (its energy).
BoomerangCurveLibrary.MIN_AIM_DISTANCE = 12
BoomerangCurveLibrary.MAX_AIM_DISTANCE = 200
-- // A bounce off a wall or a clash straightens it out (false) or it keeps turning after the bounce (true)
BoomerangCurveLibrary.KEEP_CURVE_AFTER_BOUNCE = false

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-- // Rotate a horizontal direction about the vertical axis (positive angle = turn left / counterclockwise from above)
function BoomerangCurveLibrary.rotate(direction: Vector3, angle: number): Vector3
	if angle == 0 then
		return direction
	end
	local cosAngle, sinAngle = math.cos(angle), math.sin(angle)
	return Vector3.new(direction.X * cosAngle + direction.Z * sinAngle, 0, -direction.X * sinAngle + direction.Z * cosAngle)
end

-- // Where a boomerang ends up after flying `distance` studs along its arc: the displacement and the new heading
function BoomerangCurveLibrary.advanceAlongArc(direction: Vector3, curvature: number, distance: number): (Vector3, Vector3)
	local turn = curvature * distance
	if math.abs(turn) < 1e-6 then
		return direction * distance, direction
	end
	-- // Chord of the arc: half the turn off the start heading, length 2*sin(turn/2)/curvature
	local chordLength = 2 * math.sin(turn / 2) / curvature
	return BoomerangCurveLibrary.rotate(direction, turn / 2) * chordLength, BoomerangCurveLibrary.rotate(direction, turn)
end

-- // SERVER: decide a throw's curve.
-- // aimDirection: horizontal unit direction of the aim arrow. aimDistance: how far ahead the aimed point is (nil = unknown).
-- // moveDirection: the thrower's Humanoid.MoveDirection on the server. maxDistance: how far this throw can fly (energy).
-- // Returns the launch direction and the curvature to fly with.
function BoomerangCurveLibrary.decide(aimDirection: Vector3, aimDistance: number?, moveDirection: Vector3?, maxDistance: number, random: Random?): (Vector3, number)
	local rng = random or Random.new()
	local minBend = math.rad(BoomerangCurveLibrary.MIN_BEND_DEGREES)
	local maxBend = math.rad(BoomerangCurveLibrary.MAX_BEND_DEGREES)

	-- // Which way it bows, and by how much
	local leftVector = BoomerangCurveLibrary.rotate(aimDirection, math.pi / 2)
	local horizontalMove = if moveDirection then Vector3.new(moveDirection.X, 0, moveDirection.Z) else Vector3.zero
	local sideways = if horizontalMove.Magnitude > 1e-3 then horizontalMove:Dot(leftVector) else 0 -- // +1 = moving fully left
	local threshold = BoomerangCurveLibrary.MOVE_SIDEWAYS_THRESHOLD
	local bowSide: number -- // +1 = bows out to the left of the aim line
	local bend: number
	if math.abs(sideways) >= threshold then
		local towardMovement = if sideways > 0 then 1 else -1
		bowSide = if BoomerangCurveLibrary.BOW_TOWARD_MOVEMENT then towardMovement else -towardMovement
		local alpha = math.clamp((math.abs(sideways) - threshold) / math.max(1 - threshold, 1e-3), 0, 1)
		bend = minBend + (maxBend - minBend) * alpha
	else
		bowSide = if rng:NextNumber() < 0.5 then 1 else -1
		bend = minBend + (maxBend - minBend) * rng:NextNumber()
	end

	-- // How far ahead it crosses the aim line again
	local chord = aimDistance or maxDistance
	chord = math.clamp(chord, BoomerangCurveLibrary.MIN_AIM_DISTANCE, math.max(math.min(BoomerangCurveLibrary.MAX_AIM_DISTANCE, maxDistance), BoomerangCurveLibrary.MIN_AIM_DISTANCE))

	-- // Leaves on the bow side, turns the other way back through the aimed point
	local launchDirection = BoomerangCurveLibrary.rotate(aimDirection, bowSide * bend)
	local curvature = -bowSide * 2 * math.sin(bend) / chord
	return launchDirection, curvature
end

-- // The largest curvature a replicated value may carry (the tightest arc decide() can make)
function BoomerangCurveLibrary.getMaxCurvature(): number
	return 2 * math.sin(math.rad(BoomerangCurveLibrary.MAX_BEND_DEGREES)) / BoomerangCurveLibrary.MIN_AIM_DISTANCE
end

return BoomerangCurveLibrary
