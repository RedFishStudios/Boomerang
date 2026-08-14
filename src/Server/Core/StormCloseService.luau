--[[
  StormCloseService

  Description:
  Handles server-side player data

  Author:
  @SixthAtom

  Date:
  20-02-2026
]]

local StormCloseService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local ArenaService = require(game.ServerStorage.Server.Core.ArenaService)
local Gamemodes = require(ReplicatedStorage.Shared.Constants.Gamemodes)
local Maps = require(ReplicatedStorage.Shared.Constants.Maps)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local StormCloseLibrary = require(ReplicatedStorage.Shared.Library.StormCloseLibrary)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local RECTANGLE_TWEEN_INFO = TweenInfo.new(
	1, -- Duration
	Enum.EasingStyle.Quad,
	Enum.EasingDirection.Out
)

local PLAYER_DAMAGE_INTERVAL = 1
local DAMAGE_AMOUNT = 10

-- Seconds between each closure step, in order of closure steps
local CLOSURE_INTERVALS = {
   5,
   5,
   5,
   5,
   5,
   5
}

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local paused = false

local livingStormConnection: RBXScriptConnection? = nil
local nextDamageAt: number? = nil

local lastClosureStepTimestamp: number? = nil
local lastClosureStepIndex: number? = nil

local stormCloseRemote = SimpleRemotes.getEvent(StormCloseLibrary.REMOTE_EVENT_NAME)

local stormState = {
	centerPosition = Vector3.new(),
	initialWidth = 0,
	initialHeight = 0,
	startWidth = 0,
	startHeight = 0,
	targetWidth = 0,
	targetHeight = 0,
	tweenStartTime = 0,
	tweenDuration = RECTANGLE_TWEEN_INFO.Time,
	currentWidth = 0,
	currentHeight = 0,
}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function disconnect()
   if livingStormConnection then
      livingStormConnection:Disconnect()
      livingStormConnection = nil
   end
end

local function clear()
	stormCloseRemote:FireAllClients(StormCloseLibrary.REMOTE_ACTION_CLEAR)
   disconnect()
   lastClosureStepTimestamp = nil
   lastClosureStepIndex = nil
	nextDamageAt = nil
	stormState.initialWidth = 0
	stormState.initialHeight = 0
	stormState.startWidth = 0
	stormState.startHeight = 0
	stormState.targetWidth = 0
	stormState.targetHeight = 0
	stormState.currentWidth = 0
	stormState.currentHeight = 0
end

local function setStormTarget(newWidth: number, newHeight: number)
	stormState.startWidth = stormState.currentWidth
	stormState.startHeight = stormState.currentHeight
	stormState.targetWidth = newWidth
	stormState.targetHeight = newHeight
	stormState.tweenStartTime = os.clock()
	stormState.tweenDuration = RECTANGLE_TWEEN_INFO.Time
	stormCloseRemote:FireAllClients(StormCloseLibrary.REMOTE_ACTION_SHIFT, newWidth, newHeight)
end

local function updateCurrentStormApproximation(now: number)
	local alpha = StormCloseLibrary.getTweenAlpha(stormState.tweenStartTime, stormState.tweenDuration, now)
	stormState.currentWidth, stormState.currentHeight = StormCloseLibrary.lerpDimensions(
		stormState.startWidth,
		stormState.startHeight,
		stormState.targetWidth,
		stormState.targetHeight,
		alpha
	)
end

local function damagePlayersOutsideStorm(livingPlayers: { Player })
	for _, player in ipairs(livingPlayers) do
		local character = player.Character
		if not character then
			continue
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			continue
		end

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if not rootPart or not rootPart:IsA("BasePart") then
			continue
		end

		if not StormCloseLibrary.isPointInsideRectangle(rootPart.Position, stormState.centerPosition, stormState.currentWidth, stormState.currentHeight) then
			humanoid:TakeDamage(DAMAGE_AMOUNT)
		end
	end
end

-- // Create rectangle of size
local function createRectangle(x, y, centerPosition: Vector3?)
	stormState.centerPosition = centerPosition or ArenaService.getCurrentArenaPosition() or Vector3.new()
	stormState.initialWidth = x
	stormState.initialHeight = y
	stormState.startWidth = x
	stormState.startHeight = y
	stormState.targetWidth = x
	stormState.targetHeight = y
	stormState.currentWidth = x
	stormState.currentHeight = y
	stormState.tweenStartTime = os.clock()
	stormState.tweenDuration = RECTANGLE_TWEEN_INFO.Time
	stormCloseRemote:FireAllClients(StormCloseLibrary.REMOTE_ACTION_CREATE, stormState.centerPosition, x, y)
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function StormCloseService.begin(x, y)
   clear()
   local gameStateData = GameStateLibrary.getGameStateData()

	local centerPosition: Vector3? = nil
	local width = x
	local height = y

	if typeof(x) == "Vector3" then
		centerPosition = x
		width = y or 100
		height = y or 100
	end

	createRectangle(width, height, centerPosition)
	nextDamageAt = os.clock() + PLAYER_DAMAGE_INTERVAL

	livingStormConnection = RunService.Heartbeat:Connect(function(dt)
      if paused then
         return
      end
      if not gameStateData.IsInRound:Get() then
         return
      end

		local currentTime = os.clock()
		updateCurrentStormApproximation(currentTime)

		if nextDamageAt and currentTime >= nextDamageAt then
			damagePlayersOutsideStorm(gameStateData.LivingPlayersInArena:Get())
			nextDamageAt = currentTime + PLAYER_DAMAGE_INTERVAL
		end

      if lastClosureStepTimestamp and lastClosureStepIndex then
         local elapsedTime = currentTime - lastClosureStepTimestamp
         local interval = CLOSURE_INTERVALS[lastClosureStepIndex]
         if not interval then
            -- No more closure steps, storm boundary is minimally sized
            return
         end
         if elapsedTime >= interval then
            lastClosureStepIndex = lastClosureStepIndex + 1
            lastClosureStepTimestamp = currentTime

            local newX = math.max(0, x - (lastClosureStepIndex * 10))
            local newY = math.max(0, y - (lastClosureStepIndex * 10))

			setStormTarget(newX, newY)
         end
      else
         -- Initialize closure step tracking
         lastClosureStepIndex = 1
         lastClosureStepTimestamp = currentTime
      end
   end)
end

function StormCloseService.teardown()
   clear()
end

-- // Cease or resume closure motion without tearing down
function StormCloseService.pause(newPaused: boolean)
   paused = newPaused
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function StormCloseService.init()
   local gameStateData = GameStateLibrary.getGameStateData()
	Players.PlayerAdded:Connect(function(player)
		if stormState.initialWidth <= 0 or stormState.initialHeight <= 0 then
			return
		end

		stormCloseRemote:FireClient(player, StormCloseLibrary.REMOTE_ACTION_CREATE, stormState.centerPosition, stormState.currentWidth, stormState.currentHeight)
	end)

   gameStateData.CurrentRoundId:Subscribe(function(newRoundId)
      warn(`change in round id detected`)
      StormCloseService.teardown()

      if newRoundId == nil then
         warn(`no round id for storm close`)
         return
      end

      local gamemode = gameStateData.Gamemode:Get()
      if not gamemode then
         warn(`no gamemode for round {gamemode}`)
         return
      end

      local gamemodeData = Gamemodes[gamemode]
      if not gamemodeData.StormClose then
         warn(`no storm close for gamemode {gamemode}`)
         return
      end
      
      local mapId = gameStateData.CurrentMapName:Get()
      local mapData = Maps[mapId]
      if not mapData then
      --   return
      end

		local stormCloseConfigPart = ArenaService.getConfig("StormClose")
		if not stormCloseConfigPart or not stormCloseConfigPart:IsA("BasePart") then
			warn("StormCloseService: missing StormClose config BasePart")
			return
		end

		StormCloseService.begin(stormCloseConfigPart.Size.X, stormCloseConfigPart.Size.Z)
   end)
end

return StormCloseService
