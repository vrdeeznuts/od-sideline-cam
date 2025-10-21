metadata = {
	name = "Sideline Cam (LIVE)",
	description = "4v4 automated sideline dolly camera with arena selection, ball tracking, automated zoom (FOV), automated side switching, endzone riser, keyboard/mouse controls, and somewhat documented GUI. Implementation by Yuki, ideation by Mozzy.",
	authors = { "Yuki.10", "Mozzy" },
	version = "1.4",
	defaultKeybind = "NumPadZero",
}

local firstTransition = true

-- keybinds
local nameKey = Input.Key.N
local sideKey = Input.Key.L
local saveKey = Input.Key.S
local arenaSwapKey = Input.Key.A
local autozoomKey = Input.Key.Z
local endzoneKey = Input.Key.E
local hookKey = Input.Key.C
local upKey = Input.Key.Up
local downKey = Input.Key.Down

-------------------------------------------------------------------
-------- camera settings ------------------------------------------
-------------------------------------------------------------------
local MINFOV = 1
local MAXFOV = 170
local ZOOMSPEED = 5
local fieldOfView = config.fieldOfView or 60
local fieldOfViewSmoothing = config.fieldOfViewSmoothing or 0.05
local rotationSmoothing = config.rotationSmoothing or 0.3
local positionSmoothing = config.positionSmoothing or 0.3
camera.showNameTags = config.showNameTags or true

local arcEnabled = config.arcEnabled or false
local endzoneHookEnabled = config.endzoneHookEnabled or true
local ballHeightOffset = config.ballHeightOffset or 200
local ceiling = 1329.671
local minHeightAboveGround = 10
local maxBallHeight = config.maxBallHeight or 1329
local currentSide = config.currentSide or 1
local currentRow = config.currentRow or 1
local currentArena = config.currentArena or "West-1"
local autoSwitchSides = config.autoSwitchSides or true
local sideSwitchDistance = config.sideSwitchDistance or 2093
local sideSwitchWidth = 1000
local sidelineLength = config.sidelineLength or 3072
local sideSwitchInstant = config.sideSwitchInstant or true
local sewerSwitchCooldown = config.sewerSwitchCooldown or 3.0
local sewerCooldownTimer = 0.0
local currentSewerCamPos = nil
local arcScale = 1e-4 / 2 -- height increase per squared distance from midfield line
local hookScaleX = config.hookScaleX or 0
local hookScaleY = config.hookScaleY or 2.5

local autozoom = config.autozoom or {
	enabled = true,
	targetFrac = 0.035,
	ballDiameter = 40.0,
	followSpeed = 30.0,
}

-- game/score
local prevScore0 = 0
local prevScore1 = 0
local lastGoalScorerName = "N/A"
-- local lastGoalScorerTeamName = ""
local lastGoalTeam = -1
local lastTouchPlayer = nil
-- local lastPlayerTeam0 = nil
-- local lastPlayerTeam1 = nil
local playerGoalCounts = {}
local playerAssistCounts = {}
local lastTouchesTeam0 = {}
local lastTouchesTeam1 = {}

-- hardcoded arena positions based on gamemode slot id transform positions
-- will update this to use the values directly from SpectatorGamemodes
-- note that up is not z+, so we use gravity.upDirection

local arena2Slot = {
	["West-1"] = "TKB_Driftplex01",
	["West-2"] = "TKB_Driftplex02",
	["West-3"] = "TKB_Driftplex03",
	["East-1"] = "TKB_Driftplex04",
	["East-2"] = "TKB_Driftplex05",
	["East-3"] = "TKB_Driftplex06",
}

local ARENAS

-- local ARENARADIUSLENGTH = 4164
-- local ARENARADIUSWIDTH = 2929
-- height: (-85, 1330)

-- sewer width radius = 850
-- sewer length radius = 1724
-- sewer height lower = -85
-- sewer height upper = 147
--                                 forward, 	  right,       up
-- sewer camera position offset: +- 487.982, +- 842.255, +133.541

local transitionBeginArenas = {
	["West-1"] = { x = 16450.833025, y = 6900, z = -25893.678626 },
	["West-2"] = { x = 16450.833025, y = 16300, z = -25893.678626 },
	["West-3"] = { x = 16450.833025, y = 25700, z = -25893.678626 },
	["East-1"] = { x = -16450.833924, y = 6900, z = -25893.678684 },
	["East-2"] = { x = -16450.833924, y = 16300, z = -25893.678684 },
	["East-3"] = { x = -16450.833924, y = 25700, z = -25893.678684 },
}

local POSITIONS = { "1", "2", "3" }

-- sideline plane corners
local CORNERS = {
	{ label = "NW", sx = 1, sy = 1 },
	{ label = "NE", sx = -1, sy = 1 },
	{ label = "SW", sx = 1, sy = -1 },
	{ label = "SE", sx = -1, sy = -1 },
}
local CORNERS_BY_DIR = {}
for _, c in ipairs(CORNERS) do
	CORNERS_BY_DIR[c.label] = { x = c.sx, y = c.sy }
end

-- drawing settings
local drawBallOutline = config.drawBallOutline or true
local visible = false

-- post process settings
local yukiCamSets = config.yukiCamSets or false

-- ball trail
local trail: { { p: Vec3, t: number } } = {}
local simTime = 0.0
local trailSeconds = config.trailSeconds or 0.2
local BALL_RADIUS = 20
local searchRadiusMult = config.searchRadiusMult or 1.53
local TRAIL_HEAD_OFFSET = config.TRAIL_HEAD_OFFSET or 3
local glowMultiplier = config.glowMultiplier or 1.5
local debugDrawSearch = false
local MAX_THICKNESS = 25.0
local MIN_THICKNESS = 1.0

-- medal clip for these players
local newWhitelistName = ""
local whitelistEnabled = config.whitelistEnabled or false
local whitelist = config.whitelist or {}

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------

local function initializeArenas()
	ARENAS = {}
	for k, v in pairs(arena2Slot) do
		ARENAS[k] = SpectatorGamemodes.getGamemode(v)
		if ARENAS[k] == nil then
			-- print("Warning: Failed to get gamemode for " .. k)
			continue
		end
	end
	if #ARENAS == 6 then
		print("Arenas initialized.")
	end
end

function initializeConfig(defaultConfig)
	for i, v in ipairs(defaultConfig) do
		if config[i] == nil then
			config[i] = v
		end
	end
end

local function saveToConfig()
	config.fieldOfView = fieldOfView
	config.fieldOfViewSmoothing = fieldOfViewSmoothing
	config.rotationSmoothing = rotationSmoothing
	config.positionSmoothing = positionSmoothing
	config.showNameTags = camera.showNameTags
	config.arcEnabled = arcEnabled
	config.endzoneHookEnabled = endzoneHookEnabled
	config.hookScaleX = hookScaleX
	config.hookScaleY = hookScaleY
	config.ballHeightOffset = ballHeightOffset
	config.maxBallHeight = maxBallHeight
	config.currentSide = currentSide
	config.currentRow = currentRow
	config.currentArena = currentArena or "West-1"
	config.autoSwitchSides = autoSwitchSides
	config.sideSwitchDistance = sideSwitchDistance
	config.sidelineLength = sidelineLength
	config.sideSwitchInstant = sideSwitchInstant
	config.sewerSwitchCooldown = sewerSwitchCooldown
	config.drawBallOutline = drawBallOutline
	config.yukiCamSets = yukiCamSets
	config.autozoom = autozoom
	for i, v in ipairs(config) do
		print(config[i])
		print(v)
		print()
	end
	config.searchRadiusMult = searchRadiusMult
	config.trailSeconds = trailSeconds
	config.TRAIL_HEAD_OFFSET = TRAIL_HEAD_OFFSET
	config.glowMultiplier = glowMultiplier

	config.whitelist = whitelist
	config.whitelistEnabled = whitelistEnabled
	saveConfig()
end

function main()
	initializeConfig({
		fieldOfView = 60,
		fieldOfViewSmoothing = 0.05,
		rotationSmoothing = 0.3,
		positionSmoothing = 0.3,
		showNameTags = true,
		arcEnabled = false,
		endzoneHookEnabled = true,
		hookScaleX = 0.0,
		hookScaleY = 2.5,
		ballHeightOffset = 200,
		maxBallHeight = 1329, -- roughly arena ceiling
		currentSide = 1,
		currentRow = 1,
		currentArena = "West-1",
		autoSwitchSides = true,
		sideSwitchDistance = 2093,
		sideSwitchInstant = true,
		sewerSwitchCooldown = 3,
		sidelineLength = 3072,
		drawBallOutline = true,
		yukiCamSets = false,
		autozoom = {
			enabled = true,
			targetFrac = 0.035,
			ballDiameter = 40.0,
			followSpeed = 30.0,
		},
		searchRadiusMult = 2.0,
		trailSeconds = 0.2,
		TRAIL_HEAD_OFFSET = 3,
		glowMultiplier = 1.5,

		whitelist = {},
		whitelistEnabled = false,
	})
end

function onTransitionBegin(transitionInfo: Transition)
	if firstTransition then
		transitionInfo.length = 0
		currentArena = config.currentArena or "West-1"
		camera.position = transitionBeginArenas[currentArena]
		camera.rotationSmoothing = rotationSmoothing
		camera.positionSmoothing = positionSmoothing
		camera.fieldOfView = fieldOfView
		camera.fieldOfViewSmoothing = fieldOfViewSmoothing
		camera.showNameTags = config.showNameTags or true
		print("Initialized")
	end
	firstTransition = false
end

------------------------------------------------------
-- game helpers
------------------------------------------------------
local function isClipAllowed(scorerName)
	if not whitelistEnabled then
		return true
	end

	if not scorerName or scorerName == "" or scorerName == "N/A" then
		return false
	end

	local scorerLower = string.lower(scorerName)
	for _, name in ipairs(whitelist) do
		if string.lower(name) == scorerLower then
			return true -- found a match
		end
	end

	return false -- no match
end

------------------------------------------------------
-- format helpers
------------------------------------------------------
local function formatTime(totalSeconds)
	if totalSeconds < 0 then
		totalSeconds = 0
	end
	local minutes = math.floor(totalSeconds / 60)
	local seconds = math.floor(totalSeconds % 60)
	return string.format("%d:%02d", minutes, seconds)
end

------------------------------------------------------
-- arena helpers
------------------------------------------------------
local function toggleEastWestName(name: string)
	local side, row = string.match(name, "(.*)-(.*)")
	if not side or not row then
		return name
	end
	-- var = condition and a or b is the lua idiomatic
	-- method for simulating a ternary operator (like)
	-- a python 1 line if/else statement.
	-- pitfall: if the first arg (a) is falsy, it will
	-- evaluate to the second arg (b). therefore, using
	-- the typical if/else statment is better
	-- side = (side == "West") and "East" or "West"
	if side == "West" then
		side = "East"
	else
		side = "West"
	end
	lastTouchPlayer = nil
	return side .. "-" .. row
end

local function cycleArenaName(name: string, reverse)
	reverse = reverse or false
	local side, _ = string.match(name, "(.*)-(.*)")
	if side == nil then
		return name
	end
	if reverse then
		currentRow -= 1
		if currentRow < 1 then
			currentRow = #POSITIONS
		end
	else
		currentRow += 1
		if currentRow > #POSITIONS then
			currentRow = 1
		end
	end
	lastTouchPlayer = nil
	return side .. "-" .. POSITIONS[currentRow]
end

local function getWorldData(origin)
	local axisY = Vec3.new(0, 1, 0)
	local up = gravity.upDirection:getSafeNormal()
	local right = (axisY:cross(up)):getSafeNormal()
	local forward = up:cross(right):getSafeNormal()
	return up, right, forward, axisY
end

local function getCamVectors()
	-- use right hand rule to determine cross product of vectors
	-- NOTE: argument order matters!
	local camRot = camera:getSmoothedRotation()
	local forward = camRot:rotateVector(Vec3.forwardVector):getSafeNormal()
	local worldUp = gravity.upDirection
	if math.abs(forward:dot(worldUp)) > 0.999 then
		worldUp = Vec3.rightVector
	end
	local right = forward:cross(worldUp):getSafeNormal()
	local up = right:cross(forward):getSafeNormal()
	return up, right, forward
end

local function getHeightAboveOrigin(pos: Vec3, origin: Vec3)
	-- get the height difference between an object's position and the arena origin
	-- along the gravity up direction
	local displacement = pos - origin
	local up = gravity.upDirection:getSafeNormal()
	return displacement:dot(up)
end

local function isBelow(up: Vec3, pos: Vec3, origin: Vec3, offset: number | Vec3)
	-- check if pos is below a plane defined by origin + offset * upDirection
	-- offset can be a number (height above origin) or a vector (absolute offset from origin)
	-- if offset is nil, use ceiling
	local newOffset = (offset ~= nil) and offset or ceiling

	local kind = (typeof and typeof(newOffset)) or type(newOffset)
	local planePoint
	if kind == "number" then
		planePoint = origin + up * newOffset
	else -- assume vector offset
		planePoint = origin + newOffset
	end

	return (pos - planePoint):dot(up) < 0
end

local function endzoneHeightAdjust(ballPos: Vec3, arenaCenter: Vec3)
	if not arcEnabled then
		return 0
	end

	local dy = ballPos.y - arenaCenter.y
	return arcScale * (dy * dy) -- quadratic offset
end

local function endzoneHookAdjust(ballLen, sidelineLen)
	if not endzoneHookEnabled then
		return 0, 0
	end

	local quarterline = sidelineLen / 2
	local absBallLen = math.abs(ballLen)
	local actualHookScaleX = hookScaleX * 1e-4
	local actualHookScaleY = hookScaleY * 1e-4

	if absBallLen > quarterline then
		local distPastQuarter = absBallLen - quarterline
		local distPastSquared = distPastQuarter * distPastQuarter
		local x_offset = actualHookScaleX * distPastSquared
		local y_offset = actualHookScaleY * distPastSquared
		return x_offset, y_offset
	end

	return 0, 0
end

-- auto switch update
local function autoSwitchSidesUpdate(ballWidth)
	if autoSwitchSides then
		if
			(currentSide == 1 and ballWidth < -sideSwitchWidth)
			or (currentSide == -1 and ballWidth > sideSwitchWidth)
		then
			-- switch sides
			currentSide *= -1
		end
	end
end

local function getBallPosVel(arena, balls, up)
	if balls and #balls > 0 then
		local bestDist = math.huge
		local closestBall = nil
		for _, ball in ipairs(balls) do
			-- if ball.type == 1 and isBelow(up, ball.transform.position, arenaPos) then
			if ball.type == 1 then
				local ballPos: Vec3 = ball.transform.position
				local dist = (ballPos - arena):length()
				if dist < bestDist and isBelow(gravity.upDirection, ball.transform.position, arena, ceiling) then
					closestBall = ball
					bestDist = dist
				end
			end
		end
		if closestBall then
			return closestBall.transform.position, closestBall.velocity
		end
	end
	return nil, nil
end

local function isBallInSewer(ballPos, arenaCenter, wUp, wRight, yAxis)
	local sewerHalfWidth = 850
	local sewerHalfLength = 1096
	local sewerLowerHeight = -85
	local sewerUpperHeight = 147

	local relPos = ballPos - arenaCenter
	local lclX = relPos:dot(wRight)
	local lclY = relPos:dot(yAxis)
	local lclZ = relPos:dot(wUp)

	if
		math.abs(lclX) <= sewerHalfWidth
		and math.abs(lclY) <= sewerHalfLength
		and lclZ >= sewerLowerHeight
		and lclZ <= sewerUpperHeight
	then
		return true
	end

	return false
end

local function getSewerCameraPos(ballPos, arenaCenter, wUp, wRight, yAxis)
	local rightDisp = 842.255
	local forwardDisp = 487.982
	local upDisp = 133.541
	
	local candidatePos = {}
	for _, signX in ipairs({1, -1}) do
		for _, signY in ipairs({1, -1}) do
			local pos = arenaCenter
			+ (wRight * rightDisp * signX)
			+ (yAxis * forwardDisp * signY)
			+ (wUp * upDisp)
			table.insert(candidatePos, pos)
		end
	end
	
	local relPos = ballPos - arenaCenter
	local idealSignX = (relPos:dot(wRight) >= 0) and 1 or -1
	local idealSignY = (relPos:dot(yAxis) >= 0) and 1 or -1
	local idealPos = arenaCenter
		+ (wRight * rightDisp * idealSignX)
		+ (yAxis * forwardDisp * idealSignY)
		+ (wUp * upDisp)

	local preferredOrder = {idealPos}
	for _, pos in ipairs(candidatePos) do
		if pos ~= idealPos then
			table.insert(preferredOrder, pos)
		end
	end

	for _, camPos in ipairs(preferredOrder) do
		local toBall = ballPos - camPos
		local dist = toBall:length()
		if dist <= 22 then
			return camPos
		end

		local direction = toBall:getSafeNormal()
		local rayEnd = ballPos - (direction * 21)
		
		local hit = camera:castRay(camPos, rayEnd)
		if not (hit and hit.successful) then
			return camPos
		end

		return idealPos
	end
end

local function getPlayersInArenaByCenter(players, split)
	if #players < 1 then
		if split then
			return {}, {}
		else
			return {}
		end
	end

	local pixelPunks = {}
	local samurais = {}
	local allPlayers = {}

	local center = ARENAS[currentArena].transform.position
	local up, right, _, axisY = getWorldData(center)
	local halfWidth = 2929
	local halfLength = 4164
	local lowerHeight = -85
	local upperHeight = 1330

	for _, p in ipairs(players) do
		local root = p and p.root and p.root.position
		if root then
			local relativePos = root - center
			local lclX = relativePos:dot(right)
			local lclY = relativePos:dot(axisY)
			local lclZ = relativePos:dot(up)
			if
				math.abs(lclX) <= halfWidth
				and math.abs(lclY) <= halfLength
				and lclZ >= lowerHeight
				and lclZ <= upperHeight
			then
				local teamName = ""
				if p.playerColor and p.playerColor.teamName then
					teamName = p.playerColor.teamName
				end

				if split then
					local nameLower = string.lower(teamName)
					local isPixelPunks = string.find(nameLower, "pixel", 1, true) ~= nil
					local isSamurai = string.find(nameLower, "samurai", 1, true) ~= nil

					if isPixelPunks then
						table.insert(pixelPunks, p)
					end
					if isSamurai then
						table.insert(samurais, p)
					end
				else
					table.insert(allPlayers, p)
				end
			end
		end
	end

	if split then
		return pixelPunks, samurais
	end
	return allPlayers
end

local function getNearestPlayerToBall(ballPos: Vec3, players)
	-- This function returns the closest player to the ball IF
	-- the player is within the ball's searchRadiusMult.
	-- In other words, it finds the last player from the list
	-- who touched the ball.
	if #players < 1 or not ballPos then
		return nil
	end

	local bestDist = math.huge
	local closestPlayer = nil

	for _, p in ipairs(players) do
		if p.root then
			local dist = ballPos:distance(p.root.position)
			if dist < bestDist and dist <= (BALL_RADIUS * searchRadiusMult) then
				bestDist = dist
				closestPlayer = p
			end
		end
		if p.head then
			local dist = ballPos:distance(p.head.position)
			if dist < bestDist and dist <= (BALL_RADIUS * searchRadiusMult) then
				bestDist = dist
				closestPlayer = p
			end
		end
		if p.leftHand then
			local lH = p.root.position + p.root.rotation:rotateVector(p.leftHand.position)
			local dist = ballPos:distance(lH)
			if dist < bestDist and dist <= (BALL_RADIUS * searchRadiusMult) then
				bestDist = dist
				closestPlayer = p
			end
		end
		if p.rightHand then
			local rH = p.root.position + p.root.rotation:rotateVector(p.rightHand.position)
			local dist = ballPos:distance(rH)
			if dist < bestDist and dist <= (BALL_RADIUS * searchRadiusMult) then
				bestDist = dist
				closestPlayer = p
			end
		end
	end
	return closestPlayer
end

local function updateLastTouch(ballPos, players)
	if not ballPos then
		return
	end

	local arenaPlayers = getPlayersInArenaByCenter(players)
	local closestPlayer = getNearestPlayerToBall(ballPos, arenaPlayers)

	if closestPlayer then
		lastTouchPlayer = closestPlayer
		local touchList

		if closestPlayer.teamIndex == 0 then
			touchList = lastTouchesTeam0
		elseif closestPlayer.teamIndex == 1 then
			touchList = lastTouchesTeam1
		end

		if touchList then
			if #touchList == 0 or touchList[1].playerName ~= closestPlayer.playerName then
				table.insert(touchList, 1, closestPlayer)
				if #touchList > 2 then
					table.remove(touchList, 3)
				end
			end
		end
	end
end

--------------------------------------------------------------
-- ball trail
--------------------------------------------------------------
local function teamToRGB(teamName: string)
	local trailGlowMult = glowMultiplier
	if not teamName then
		return trailGlowMult, 0.5 * trailGlowMult, 0.5 * trailGlowMult
	end
	local teamLower = string.lower(teamName)
	if string.find(teamLower, "samurai") ~= nil then
		-- print("blue")
		return 0, 0.443 * trailGlowMult, 0.557 * trailGlowMult
	elseif string.find(teamLower, "pixel") ~= nil then
		-- print("pink")
		return trailGlowMult, 0.078 * trailGlowMult, 0.983 * trailGlowMult
	end
	return trailGlowMult, 0.5 * trailGlowMult, 0.5 * trailGlowMult
end

local function easeOutPow(headFrac: number, k: number)
	return headFrac ^ k
end

local function drawBallTrail(dt, ballPos, players)
	simTime += dt
	if ballPos == nil then
		return
	end

	trail[#trail + 1] = { p = ballPos, t = simTime }

	local cutoff = simTime - trailSeconds
	local firstAlive = 1
	while firstAlive <= #trail and trail[firstAlive].t < cutoff do
		firstAlive += 1
	end
	if firstAlive > 1 then
		for i = 1, firstAlive - 1 do
			trail[i] = nil
		end
		local j = 1
		for i = firstAlive, #trail do
			trail[j], j = trail[i], j + 1
		end
		for k = j, #trail do
			trail[k] = nil
		end
	end

	local teamName = nil
	if lastTouchPlayer then
		teamName = lastTouchPlayer.playerColor.teamName
	end

	WorldDraw.clear()
	local r, g, b = teamToRGB(teamName)

	for i = 2, #trail - TRAIL_HEAD_OFFSET do
		local a = trail[i - 1]
		local c = trail[i]

		local f = math.clamp((simTime - c.t) / trailSeconds, 0, 1)
		local headFrac = 1 - f
		local factor = easeOutPow(headFrac, 2) -- 3 = cubic
		local thickness = MIN_THICKNESS + (MAX_THICKNESS - MIN_THICKNESS) * factor

		WorldDraw.drawLine(a.p, c.p, r, g, b, thickness, 1e-4)
	end
end

local function debugDrawSearchSphere(center: Vec3, radius: number)
	local steps = 32
	local lifetime = 1e-4
	local r, g, b = 0, 1, 0
	local thick = 2
	local prev1, prev2, prev3 = nil, nil, nil
	for i = 0, steps do
		local a = (i / steps) * (2 * math.pi)
		local x, y = math.cos(a) * radius, math.sin(a) * radius
		local p1 = center + Vec3.new(x, y, 0)
		local p2 = center + Vec3.new(x, 0, y)
		local p3 = center + Vec3.new(0, x, y)
		if prev1 then
			WorldDraw.drawLine(prev1, p1, r, g, b, thick, lifetime)
		end
		if prev2 then
			WorldDraw.drawLine(prev2, p2, r, g, b, thick, lifetime)
		end
		if prev3 then
			WorldDraw.drawLine(prev3, p3, r, g, b, thick, lifetime)
		end
		prev1, prev2, prev3 = p1, p2, p3
	end
end

-- auto zoom
local function fovForScreenSize(distance: number, diameter: number, frac: number)
	if distance <= 1 then
		return camera.fieldOfView
	end
	frac = math.max(1e-4, math.min(frac, 0.95))
	frac = math.clamp(1e-3, frac, 0.95)
	local f = 2 * math.atan(diameter / (frac * distance))
	return math.deg(f)
end

local function autoZoomUpdate(ballPos: Vec3, dt)
	if not autozoom.enabled then
		return fieldOfView
	end

	local camPos = camera:getSmoothedPosition()
	local dx, dy, dz = ballPos.x - camPos.x, ballPos.y - camPos.y, ballPos.z - camPos.z
	local dist = math.sqrt(dx * dx + dy * dy + dz * dz)

	local target = fovForScreenSize(dist, autozoom.ballDiameter, autozoom.targetFrac)
	target = math.max(MINFOV, math.min(MAXFOV, target))
	local a = math.min(1.0, autozoom.followSpeed * dt)

	local smoothedFOV = camera:getSmoothedFieldOfView()
	return smoothedFOV + (target - smoothedFOV) * a
end

--------------------------------------------------
-- main tick helpers
--------------------------------------------------
local function updateScoreTracking(dt, slotId)
	if not slotId then
		return
	end

	local gameData = SpectatorGamemodes.getGamemodeData(slotId)
	if gameData and gameData.teams and #gameData.teams >= 2 then
		-- local status = gameData.isGameRunning -- don't really need rn
		local newScore0 = gameData.teams[1].score
		local newScore1 = gameData.teams[2].score
		local goalScored = false

		-- check for pink team goal
		if newScore0 > prevScore0 then
			lastGoalTeam = 0
			goalScored = true
			local lastGoalAssisterName = "N/A"

			-- scorer is 1st player in list
			if lastTouchesTeam0[1] then
				lastGoalScorerName = lastTouchesTeam0[1].playerName
			else
				lastGoalScorerName = "N/A"
			end
			
			-- assister is 2nd player (if they exist)
			if lastTouchesTeam0[2] then
				lastGoalAssisterName = lastTouchesTeam0[2].playerName
			end

			-- assign goal to player
			if lastGoalScorerName ~= "N/A" then
				playerGoalCounts[lastGoalScorerName] = (playerGoalCounts[lastGoalScorerName] or 0) + 1
			end

			-- assign assist to player
			if lastGoalAssisterName ~= "N/A" then
				playerAssistCounts[lastGoalAssisterName] = (playerAssistCounts[lastGoalAssisterName] or 0) + 1
			end

			-- auto-clip check
			if isClipAllowed(lastGoalScorerName) then
				print("GOAL_SCORED_MEDAL_TRIGGER")
			end
			print(string.format("[%s] Goal for pixelpunks by: %s (Assist: %s)", formatTime(gameData.timeSeconds), lastGoalScorerName, lastGoalAssisterName))
		
			-- check for blue team goal
		elseif newScore1 > prevScore1 then
			lastGoalTeam = 1
			goalScored = true
			local lastGoalAssisterName = "N/A"

			-- scorer is 1st player in the list
			if lastTouchesTeam1[1] then
				lastGoalScorerName = lastTouchesTeam1[1].playerName
			else
				lastGoalScorerName = "N/A"
			end
			
			-- assister is 2nd player (if they exist)
			if lastTouchesTeam1[2] then
				lastGoalAssisterName = lastTouchesTeam1[2].playerName
			end

			-- assign goal to player
			if lastGoalScorerName ~= "N/A" then
				playerGoalCounts[lastGoalScorerName] = (playerGoalCounts[lastGoalScorerName] or 0) + 1
			end

			-- assign assist to player
			if lastGoalAssisterName ~= "N/A" then
				playerAssistCounts[lastGoalAssisterName] = (playerAssistCounts[lastGoalAssisterName] or 0) + 1
			end

			-- auto-clip check
			if isClipAllowed(lastGoalScorerName) then
				print("GOAL_SCORED_MEDAL_TRIGGER")
			end
			print(string.format("[%s] Goal for samurais by: %s (Assist: %s)", formatTime(gameData.timeSeconds), lastGoalScorerName, lastGoalAssisterName))
			-- print(string.format("[%s] Goal for samurais by: %s", gameTime, lastGoalScorerName))
		end

		prevScore0 = newScore0
		prevScore1 = newScore1

		if goalScored then
			lastTouchPlayer = nil
			lastTouchesTeam0 = {}
			lastTouchesTeam1 = {}
		end
	end
end

local function calculateSidelineCameraPosition(ballPos, origin, worldUp, worldRight, yAxis, dt)
	local dollyPos

	if isBallInSewer(ballPos, origin, worldUp, worldRight, yAxis) then
		sewerCooldownTimer = math.max(0, sewerCooldownTimer - dt)
		local idealSewerPos = getSewerCameraPos(ballPos, origin, worldUp, worldRight, yAxis)
		if not currentSewerCamPos then
			currentSewerCamPos = idealSewerPos
		end

		if sewerCooldownTimer <= 0 and idealSewerPos ~= currentSewerCamPos then
			currentSewerCamPos = idealSewerPos
			sewerCooldownTimer = sewerSwitchCooldown
		end
		dollyPos = currentSewerCamPos
	else
		-- project ball to origin frame
		local rel = ballPos - origin
		local ballWidth = rel:dot(worldRight)
		local ballLen = rel:dot(yAxis)
		local ballH = rel:dot(worldUp)
		
		-- auto-switch sides
		autoSwitchSidesUpdate(ballWidth)
		
		-- endzone hook adjustment
		local x_hook_offset, y_hook_offsest = endzoneHookAdjust(ballLen, sidelineLength)
		local y_sign = (ballLen >= 0) and 1 or -1

		-- set dolly coords in origin frame
		local dollyWidth = (currentSide * sideSwitchDistance) - (x_hook_offset * currentSide)
		local dollyLen = math.clamp(ballLen, -sidelineLength, sidelineLength) - (y_hook_offsest * y_sign)
		-- local dollyLen = math.clamp(ballLen, arenaYMin - origin.y, arenaYMax - origin.y)
		local dollyHgt = ballH + ballHeightOffset
		
		-- endzone height adjustment
		local extraHeight = endzoneHeightAdjust(ballPos, origin)
		dollyHgt += extraHeight

		-- clamp
		local dollyHgtClamped = math.clamp(dollyHgt, -85, maxBallHeight)
		
		-- reconstruct position in origin frame
		dollyPos = origin + (worldRight * dollyWidth) + (yAxis * dollyLen) + (worldUp * dollyHgtClamped)

		local gravityDown = -worldUp
		local fixedRayStartHeight = 463.697
		local absStartHeight = (origin + (worldUp * fixedRayStartHeight)):dot(worldUp)
		local currentDollyHeight = dollyPos:dot(worldUp)
		local heightAdj = absStartHeight - currentDollyHeight
		local rayStart = dollyPos + (worldUp * heightAdj)
		local rayEnd = dollyPos + (gravityDown * 5000)
		local hit = camera:castRay(rayStart, rayEnd)
		if hit and hit.successful then
			local groundHitPosition = hit.position
			local minSafePosition = groundHitPosition - (gravityDown * minHeightAboveGround)

			local currentHeight = dollyPos:dot(worldUp)
			local minSafeHeight = minSafePosition:dot(worldUp)

			if currentHeight < minSafeHeight then
				local heightDiff = minSafeHeight - currentHeight
				dollyPos = dollyPos + (worldUp * heightDiff)
			end
		end
	end
	return dollyPos
end

local function updateCameraState(dollyPos, ballPos, ballVel, worldForward, prevSide, currSide, newFieldOfView)
	local rawTarget = ballPos
	if rotationSmoothing > 0.0 then
		rawTarget += (ballVel * 0.45)
	end
	local aimDir = rawTarget - dollyPos

	local target = aimDir:isNearlyZero() and (dollyPos + worldForward) or (dollyPos + aimDir:getSafeNormal())

	-- update camera
	if prevSide ~= currSide and sideSwitchInstant then
		camera.positionSmoothing = 0.0
		camera.rotationSmoothing = 0.0
		rawTarget = ballPos
		aimDir = rawTarget - dollyPos
		target = aimDir:isNearlyZero() and (dollyPos + worldForward) or (dollyPos + aimDir:getSafeNormal())
	else
		camera.positionSmoothing = positionSmoothing
		camera.rotationSmoothing = rotationSmoothing
	end

	camera.position = dollyPos
	camera:lookAt(target, gravity.upDirection)
	camera.fieldOfView = fieldOfView
end

-- kbm helper
local function getInputs()
	if Input.getKeyDown(saveKey) then
		saveToConfig()
		print("Saved current settings")
	end

	if Input.getKeyDown(nameKey) then
		camera.showNameTags = not camera.showNameTags
	end

	if Input.getKeyDown(sideKey) then
		currentSide *= -1
	end

	local arenaChanged = false
	if Input.getKeyDown(arenaSwapKey) then
		currentArena = toggleEastWestName(currentArena)
		arenaChanged = true
	end
	if Input.getKeyDown(upKey) then
		currentArena = cycleArenaName(currentArena, false)
		arenaChanged = true
	end
	if Input.getKeyDown(downKey) then
		currentArena = cycleArenaName(currentArena, true)
		arenaChanged = true
	end
	if arenaChanged then
		playerGoalCounts = {}
		lastGoalScorerName = "N/A"
		lastGoalTeam = -1
		-- lastGoalScorerTeamName = ""
		print("Arena changed, goal counts reset.")
	end

	if Input.getKeyDown(autozoomKey) then
		autozoom.enabled = not autozoom.enabled
	end

	if Input.getKeyDown(endzoneKey) then
		arcEnabled = not arcEnabled
	end

	if Input.getKeyDown(hookKey) then
		endzoneHookEnabled = not endzoneHookEnabled
	end

	local wheel = Input.getAnalog(Input.Key.MouseWheelAxis)
	if autozoom.enabled then
		if wheel ~= 0 then
			autozoom.targetFrac = autozoom.targetFrac * math.exp(0.05 * wheel)
			autozoom.targetFrac = math.max(0.0005, math.min(0.9, autozoom.targetFrac))
		end
	else
		fieldOfView -= wheel * ZOOMSPEED
		fieldOfView = math.clamp(fieldOfView, MINFOV, MAXFOV)
	end
end

-- drawing helpers
local function drawCircleOnBallOverlay(
	camPos: Vec3,
	up: Vec3,
	right: Vec3,
	forward: Vec3,
	center: Vec3,
	radius: number,
	r,
	g,
	b,
	thickness,
	segments,
	lifetime,
	overlayDistance: number
)
	-- local camPos, _, right, up, forward = getCamValues()
	local dist = center - camPos
	local depth = dist:dot(forward)
	if depth <= 1e-3 then
		-- ball behind camera
		return
	end

	local L = overlayDistance
	local s = L / depth
	local x = dist:dot(right) * s
	local y = dist:dot(up) * s
	local overlayCenter = camPos + forward * L + right * x + up * y

	local ringRadius = radius * s

	local startP = overlayCenter + right * ringRadius
	for i = 1, segments do
		local angle = (i / segments) * (2 * math.pi)
		local ring = right * math.cos(angle) + up * math.sin(angle)
		local endP = overlayCenter + (ring * ringRadius)
		WorldDraw.drawLine(startP, endP, r, g, b, thickness, lifetime)
		startP = endP
	end
end

local function isBallVisible(camPos: Vec3, targetPos: Vec3, radius: number)
	local toTarget = targetPos - camPos
	local dist = toTarget:length()
	if dist <= 1e-3 then
		return true
	end
	local dir = toTarget / dist
	-- camPos = camPos + dir * 2000

	local eps = 2
	local endPos = targetPos - dir * (radius + eps)
	local hit = camera:castRay(camPos, endPos)
	return not (hit and hit.successful)
end

local function worldDrawDebug(
	aCoords: Vec3,
	ballPos: Vec3,
	camPos: Vec3,
	up: Vec3,
	right: Vec3,
	forward: Vec3,
	dt: number
)
	-- draw ball outline
	local radius = 19
	local w_thick = 0.6
	local radiusOffset = w_thick * 0.5
	local lt = dt * 0.5

	local safeStartOffset = 100.0
	local rayOrigin = camPos + (forward * safeStartOffset)

	visible = isBallVisible(rayOrigin, ballPos, radius)

	if not visible then
		drawCircleOnBallOverlay(
			camPos,
			up,
			right,
			forward,
			ballPos,
			radius + radiusOffset,
			1,
			1,
			1,
			w_thick,
			20,
			lt,
			400.0
		)
	end
end

function onGui()
	Gui.text("Current Server: " .. Network.getCurrentServer())
	Gui.separatorText("Auto Sideline Dolly - Ball Tracker (by Yuki.10 & Mozzy)")
	Gui.text(Icon.SatelliteDish .. Icon.SatelliteDish .. " READ THIS " .. Icon.SatelliteDish .. Icon.SatelliteDish)
	Gui.indent()
	Gui.text("To fix invisible arenas:")
	Gui.indent()
	Gui.text(Icon.MousePointer .. " Click 'Spectator' (top left)")
	Gui.text(Icon.MousePointer .. " Hover over 'Settings'")
	Gui.text(Icon.MousePointer .. " Toggle 'Enable LODs'")
	Gui.unindent()
	Gui.unindent()
	Gui.text(Icon.SatelliteDish .. Icon.SatelliteDish .. " READ THIS " .. Icon.SatelliteDish .. Icon.SatelliteDish)
	Gui.newLine()

	-- Gui.separatorText("Keyboard/Mouse Controls")
	if Gui.collapsingHeader("Keyboard/Mouse Controls") then
		Gui.text("'A':")
		Gui.sameLine()
		Gui.text("Switch between East and West arenas.")
		Gui.newLine()
		
		Gui.text("'L':")
		Gui.sameLine()
		Gui.text("Swap sideline.")
		Gui.newLine()
		
		Gui.text("'" .. Icon.ArrowUp .. "'" .. ", " .. "'" .. Icon.ArrowDown .. "':")
		Gui.sameLine()
		Gui.text("Cycle between arenas 1, 2, and 3.")
		Gui.newLine()

		Gui.text("'S':")
		Gui.sameLine()
		Gui.text("Save settings.")
		Gui.newLine()

		Gui.text("'N':")
		Gui.sameLine()
		Gui.text("Toggle nametags.")
		Gui.newLine()
		
		Gui.text("'Z':")
		Gui.sameLine()
		Gui.text("Toggle auto zoom.")
		Gui.newLine()
		
		Gui.text("'E':")
		Gui.sameLine()
		Gui.text("Toggle Endzone Riser.")
		Gui.newLine()
		
		Gui.text("'C':")
		Gui.sameLine()
		Gui.text("Toggle Endzone Inward Curve.")
		Gui.newLine()

		Gui.text(Icon.Mouse .. " Scroll:")
		Gui.sameLine()
		Gui.text("Zoom in/out.")
	end

	if Gui.collapsingHeader("Scoreboard") then
		local arena = (ARENAS and ARENAS[currentArena])
		local slotId = arena2Slot[currentArena]
		local gameData = (slotId and SpectatorGamemodes.getGamemodeData(slotId))

		if not arena or not gameData or not gameData.teams or #gameData.teams < 2 then
			Gui.text("Waiting for game data...")
		else
			-- get teams
			local pixelPunks, samurais = getPlayersInArenaByCenter(getGameData().players, true)
			local teamColors = arena:getTeamColorsArray()
			local team0Color = teamColors[1]
			local team1Color = teamColors[2]
			local team0Name = (team0Color and team0Color.teamName) or "pixelpunks"
			local team1Name = (team1Color and team1Color.teamName) or "samurais"

			-- get scores
			local score0 = gameData.teams[1].score
			local score1 = gameData.teams[2].score

			-- display scores
			Gui.text(string.format("%s   %d", team0Name, score0))
			Gui.sameLine()
			Gui.text("|")
			Gui.sameLine()
			Gui.text(string.format("%d   %s", score1, team1Name))

			-- display rosters
			Gui.separator()
			local team0List, team1List
			if string.find(string.lower(team0Name), "pixel") then
				team0List = pixelPunks
				team1List = samurais
			else
				team0List = samurais
				team1List = pixelPunks
			end

			-- display game clock
			local status = gameData.isGameRunning and "Running" or "Not Running"
			Gui.text(string.format("Clock: %s (%s)", formatTime(gameData.timeSeconds), status))

			-- display last scorer
			if lastGoalTeam == 0 then
				Gui.text(string.format("Last Goal: %s (%s)", lastGoalScorerName, team0Name))
			elseif lastGoalTeam == 1 then
				Gui.text(string.format("Last Goal: %s (%s)", lastGoalScorerName, team1Name))
			else
				Gui.text("Last Goal: N/A")
			end

			if Gui.button(Icon.Eraser .. " Reset Goal Counts") then
				playerGoalCounts = {}
			end
			Gui.setItemTooltip("Reset player goal counts in the roster below.")

			if Gui.beginTable("rosters", 2) then
				Gui.tableSetupColumn(team0Name)
				Gui.tableSetupColumn(team1Name)
				Gui.tableHeadersRow()

				local maxPlayers = math.max(#team0List, #team1List)
				for i = 1, maxPlayers do
					Gui.tableNextRow()

					Gui.tableNextColumn()
					if team0List[i] then
						local playerName = team0List[i].playerName
						local goals = playerGoalCounts[playerName] or 0
						local assists = playerAssistCounts[playerName] or 0
						Gui.text(string.format("%s (G: %d, A: %d)", playerName, goals, assists))
					end

					Gui.tableNextColumn()
					if team1List[i] then
						local playerName = team1List[i].playerName
						local goals = playerGoalCounts[playerName] or 0
						local assists = playerAssistCounts[playerName] or 0
						Gui.text(string.format("%s (G: %d, A: %d)", playerName, goals, assists))

					end
				end
				Gui.endTable()
			end
		end
		Gui.newLine()
		Gui.separator()
	end
	Gui.setItemTooltip("Show scoreboard (with stats).")

	if Gui.collapsingHeader("Medal Clipping") then
		-- Gui.separatorText("Medal Clipping Whitelist")
		whitelistEnabled = Gui.checkbox("Clip Whitelist Players Only", whitelistEnabled)
		Gui.setItemTooltip("If checked, clips will ONLY be triggered for players on the list. \nIf unchecked, all goals will be clipped.")
		
		if whitelistEnabled then
			Gui.indent()
			Gui.text("Only clip goals scored by these players:")
			local nameToRemove = nil
			if #whitelist == 0 then
				Gui.text("Whitelist is empty. No clips will be saved.")
			end

			for i, name in ipairs(whitelist) do
				Gui.text(name)
				Gui.sameLine()
				if Gui.smallButton(Icon.Trash .. "##" .. i) then
					nameToRemove = i
				end
			end

			if nameToRemove then
				table.remove(whitelist, nameToRemove)
			end

			Gui.separator()
			newWhitelistName = Gui.inputText("Player Name", newWhitelistName)
			Gui.sameLine()
			if Gui.button("Add") and newWhitelistName ~= "" then
				table.insert(whitelist, newWhitelistName)
				newWhitelistName = ""
			end
			Gui.unindent()
		end
	end
	Gui.setItemTooltip("This works IF you've downloaded and set up the Powershell script.")

	if Gui.button(Icon.Save .. " Save Current Settings") then
		-- updateConfig()
		saveToConfig()
		print("Saved current settings")
	end
	Gui.sameLine()
	if Gui.button(Icon.WindowClose .. " Leave Server") then
		Network.disconnectFromServer()
	end

	-- arena selection
	Gui.newLine()
	Gui.separatorText("Arena Selection")
	if Gui.beginCombo("Arena", currentArena) then
		for name, slot in pairs(arena2Slot) do
			local selected = (name == currentArena)
			if Gui.selectable(name, selected) then
				if currentArena ~= name then
					currentArena = name
					playerGoalCounts = {}
					lastGoalScorerName = "N/A"
					lastGoalTeam = -1
					-- lastGoalScorerTeamName = ""
					print("Arena changed, goal counts reset.")
				end
			end
			if selected then
				Gui.setItemDefaultFocus()
			end
		end
		Gui.endCombo()
	end

	-- east/west toggle
	if Gui.button(Icon.ArrowUp) then
		currentArena = cycleArenaName(currentArena, false)
	end
	Gui.setItemTooltip("Move to next arena on same side (" .. Icon.ArrowUp .. ")")
	Gui.sameLine()
	if Gui.button(Icon.ArrowDown) then
		currentArena = cycleArenaName(currentArena, true)
	end
	Gui.setItemTooltip("Move to next arena on same side (" .. Icon.ArrowDown .. ")")
	Gui.sameLine()
	if Gui.button("Toggle East / West Arena") then
		currentArena = toggleEastWestName(currentArena)
	end
	Gui.setItemTooltip("'a' to swap arenas")
	Gui.sameLine()
	if Gui.button("Switch Sideline") then
		currentSide *= -1
	end
	Gui.setItemTooltip("'s' to switch sides")
	autoSwitchSides = Gui.checkbox("Auto-switch Sideline", autoSwitchSides)
	Gui.setItemTooltip("Switch sidelines automatically when the ball gets too far")
	Gui.sameLine()
	if autoSwitchSides then
		sideSwitchInstant = Gui.checkbox("Instant side switch", sideSwitchInstant)
	end
	camera.showNameTags = Gui.checkbox("Show Nametags", camera.showNameTags)
	Gui.setItemTooltip("'n' to toggle")
	drawBallOutline = Gui.checkbox("Ball Outline when Hidden", drawBallOutline)
	Gui.setItemTooltip("Show ball outline when camera is obstructed")
	Gui.sameLine()
	if visible then
		Gui.text(Icon.DoorOpen)
	else
		Gui.text(Icon.DoorClosed)
	end

	-- camera settings
	Gui.separatorText("Camera Settings")
	yukiCamSets = Gui.checkbox("Yuki's camera settings", yukiCamSets)
	Gui.setItemTooltip("low exposure, low bloom")
	if yukiCamSets then
		postProcessSettings.bloomIntensity = 0.01
		postProcessSettings.autoExposureBias = -0.001
	end
	Gui.sameLine()
	if Gui.smallButton(Icon.Sync .. " reset exposure") then
		postProcessSettings:reset()
		yukiCamSets = false
	end

	-- auto zoom
	autozoom.enabled = Gui.checkbox("Auto Zoom", autozoom.enabled)
	Gui.newLine()

	-- endzone
	Gui.text("Endzone")
	arcEnabled = Gui.checkbox("Riser", arcEnabled)
	Gui.setItemTooltip(
		"Raise the camera when the ball gets closer to a goal. \nThis lowers the chance that the ball will be \nhidden by the Bridge and Nest geos. Press 'e' to enable/disable."
	)
	Gui.sameLine()
	endzoneHookEnabled = Gui.checkbox("Inward Hook", endzoneHookEnabled)
	Gui.setItemTooltip(
		"When the ball is close to the goal, the camera will move \ninwards from the sideline. This lowers the chance \nthat the ball will be hidden by geos. Press 'c' to enable/disable."
	)
	if endzoneHookEnabled then
		hookScaleX = Gui.sliderFloat("How much the camera moves inward", hookScaleX, 0, 10)
		Gui.setItemTooltip("When the ball is in the bubble, the camera will move towards the middle.")
		-- hookScaleY = Gui.sliderFloat("How much the camera moves backward", hookScaleY, 0, 10)
	end

	-- max camera height
	-- maxBallHeight = Gui.sliderInt("Max camera height", maxBallHeight, 300, 1329)
	-- sideline distance to arena center
	sideSwitchDistance = Gui.sliderInt("Sideline distance (x) from arena center", sideSwitchDistance, 100, 3000)
	Gui.setItemTooltip("Camera's position width")
	sidelineLength = Gui.sliderInt("Dolly rail length (y) from half field", sidelineLength, 200, 5000)
	Gui.setItemTooltip("Probably don't change this one unless you disable the endzone arc.")
	ballHeightOffset = Gui.sliderInt("Ball height offset", ballHeightOffset or 200, 0, 500)
	-- fov/zoom
	fieldOfView = Gui.sliderFloat("FOV", fieldOfView, MINFOV, MAXFOV)
	Gui.setItemTooltip("mouse scroll to increase/decrease FOV. Auto zoom must be disabled.")
	-- smoothing
	rotationSmoothing = Gui.sliderFloat("Ball tracking smoothing", rotationSmoothing, 0, 1)
	Gui.setItemTooltip("Make the camera turn more smoothly.")
	positionSmoothing = Gui.sliderFloat("Dolly smoothing", positionSmoothing, 0, 1)
	fieldOfViewSmoothing = Gui.sliderFloat("FOV Smoothing", fieldOfViewSmoothing, 0, 1)

	Gui.separatorText("Ball Trail")
	trailSeconds = Gui.sliderFloat("Trail length (s)", trailSeconds, 0, 2)
	MAX_THICKNESS = Gui.sliderFloat("Max Thickness", MAX_THICKNESS, 6, 30)
	MIN_THICKNESS = Gui.sliderFloat("Min Thickness", MIN_THICKNESS, 0.1, 5)
	TRAIL_HEAD_OFFSET = Gui.sliderInt("Ball Trail Start Offset", TRAIL_HEAD_OFFSET, 0, 5)
	glowMultiplier = Gui.sliderFloat("Glow Multiplier", glowMultiplier, 0.5, 5)
	
	Gui.separatorText("Debug")
	debugDrawSearch = Gui.checkbox("Debug draw search radius", debugDrawSearch)
	BALL_RADIUS = Gui.sliderFloat("Ball Radius", BALL_RADIUS, 5, 50)
	searchRadiusMult = Gui.sliderFloat("Search Radius x Ball Radius", searchRadiusMult, 1.0, 4.0)
	if Gui.button("Send Server Name to logs") then
		print("MYCURRENTSERVER: " .. Network.getCurrentServer())
	end
end

function tick(dt)
	-- 1. init and data fetch
	if not ARENAS or not ARENAS[currentArena] then 
		initializeArenas()
		if not ARENAS or not ARENAS[currentArena] then
			return 
		end
	end 
	local a = ARENAS[currentArena]
	local aCoords = a.transform.position
	local frame = getGameData()
	local balls = frame.balls
	local players = frame.players
	local camPos = camera:getSmoothedPosition()

	-- 2. kbm input handling
	getInputs()

	-- 3. world frame setup
	local origin = Vec3.new(aCoords.x, aCoords.y, aCoords.z)
	local worldUp, worldRight, worldForward, axisY = getWorldData(origin)

	-- 4. ball pos/vel
	local ballPos, ballVel = getBallPosVel(aCoords, balls, worldUp)
	if not ballPos then
		ballPos = origin
		ballVel = Vec3.zeroVector
	end

	-- 5. ball touch and trail
	updateLastTouch(ballPos, players)
	drawBallTrail(dt, ballPos, players)

	-- 6. score tracking
	local slotId = arena2Slot[currentArena]
	updateScoreTracking(dt, slotId)

	-- 7. camera pos calculation
	local prevSide = currentSide
	local dollyPos = calculateSidelineCameraPosition(ballPos, origin, worldUp, worldRight, axisY, dt)
	local currSide = currentSide

	-- 8. update camera state
	fieldOfView = autoZoomUpdate(ballPos, dt)
	updateCameraState(dollyPos, ballPos, ballVel, worldForward, prevSide, currSide, fieldOfView)

	-- 9. drawing
	if drawBallOutline then
		local camUp, camRight, camForward = getCamVectors()
		worldDrawDebug(aCoords, ballPos, camPos, camUp, camRight, camForward, dt)
	end

	if debugDrawSearch then
		debugDrawSearchSphere(ballPos, BALL_RADIUS * searchRadiusMult)
	end
end
