local HotPotato = {}

local RunService = game:GetService("RunService")

local GlobalConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"):WaitForChild("GlobalConfig"))
local ParticlesLibrary = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Library"):WaitForChild("ParticlesLibrary"))
local GameStateLibrary = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Library"):WaitForChild("GameStateLibrary"))
local SharedTasks = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"):WaitForChild("SharedTasks"))
local CombatLibrary = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Library"):WaitForChild("CombatLibrary"))
local SimpleRemotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Networking"):WaitForChild("SimpleRemotes"))
local SoundLibrary = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Library"):WaitForChild("SoundLibrary"))

local isServer = RunService:IsServer()
local PickupService
local CharacterRenderController
if isServer then
   PickupService = require(game:GetService("ServerStorage"):WaitForChild("Server"):WaitForChild("Core"):WaitForChild("PickupService"))
else
   CharacterRenderController = require(game:GetService("ReplicatedStorage"):WaitForChild("Client"):WaitForChild("Core"):WaitForChild("CharacterRenderController"))
end

--------------------------------------------------------------------------------
-- CONSTANTS
--------------------------------------------------------------------------------

local explodePlayerRemote = SimpleRemotes.getEvent("ExplodePlayerPotato")

--------------------------------------------------------------------------------
-- PER-SESSION VALUES
--------------------------------------------------------------------------------

local currentHolder: Player = nil
local hotPotatoActive = false
local Particles: {[Player]: Part} = {}
local originTime = 0
local elapsed = 0
local heartbeatConnection: RBXScriptConnection? = nil
local perSessionDestroyers: {()->()} = {}

local nextHolderElapsed = 0
local nextHolderRoundId: number? = nil

--------------------------------------------------------------------------------
-- CONFIGS
--------------------------------------------------------------------------------

local EXPLOSION_COUNTER_RANGE = NumberRange.new(3, 5)
local NEXT_HOLDER_DELAY = 3

--------------------------------------------------------------------------------
-- LOCAL FUNCTIONS
--------------------------------------------------------------------------------

local function teardown()
   if heartbeatConnection then
      heartbeatConnection:Disconnect()
      heartbeatConnection = nil
   end
   hotPotatoActive = false
   currentHolder = nil
   elapsed = 0
   originTime = 0
   nextHolderElapsed = 0
   nextHolderRoundId = nil
   
   CombatLibrary.removeAttackHitPlayerCallback("HotPotato")
end

local function explode(player: Player)
   print("player exploded")
   if not isServer then
      return
   end
   local character = player.Character
   if not character then
      return
   end
   local humanoid = character:FindFirstChildOfClass("Humanoid")
   if not humanoid then
      return
   end
   if humanoid.Health <= 0 then
      return
   end

   humanoid.Health = 0
   explodePlayerRemote:FireAllClients(player)

   local currentRoundData = GameStateLibrary.getGameStateData().CurrentRoundData:Get()
   nextHolderElapsed = 0
   nextHolderRoundId = currentRoundData and currentRoundData.CurrentRoundId
end

local function start()
   if isServer then
      originTime = game.Workspace:GetServerTimeNow()
      local explosionCounter = math.random(EXPLOSION_COUNTER_RANGE.Min, EXPLOSION_COUNTER_RANGE.Max)

      if heartbeatConnection then
         heartbeatConnection:Disconnect()
      end
      heartbeatConnection = game:GetService("RunService").Heartbeat:Connect(function(dt)
         elapsed += dt
         if elapsed >= explosionCounter and currentHolder then
            explode(currentHolder)
            currentHolder = nil
         end

         if nextHolderRoundId ~= nil then
            nextHolderElapsed += dt
            if nextHolderElapsed >= NEXT_HOLDER_DELAY then
               local roundIdAtExplosion = nextHolderRoundId
               nextHolderRoundId = nil
               nextHolderElapsed = 0

               local gameStateData = GameStateLibrary.getGameStateData()
               local currentRoundData = gameStateData.CurrentRoundData:Get()
               if currentRoundData and currentRoundData.Gamemode == "HotPotato" and currentRoundData.CurrentRoundId == roundIdAtExplosion then
                  local livingPlayers = gameStateData.LivingPlayersInArena:Get()
                  if #livingPlayers > 0 then
                     local randomPlayer = livingPlayers[math.random(1, #livingPlayers)]
                     PickupService.grantPickupClassId(randomPlayer, "HotPotato")
                  end
               end
            end
         end
      end)

      CombatLibrary.addAttackHitPlayerCallback("HotPotato", function(attacker: Player, attackerToolId: string?, victim: Player, victimHumanoid: Humanoid?, damageAmount: number)
         if attacker == currentHolder then
            PickupService.grantPickupClassId(victim, "HotPotato")
            return true
         end
         return false
      end)
   end
end

function HotPotato.onPickup(player: Player, position: CFrame)
   if isServer then
      -- Server context
      if not hotPotatoActive then
         start()
      end
      currentHolder = player
   else
      -- Client context
      Particles[player] = ParticlesLibrary.play(`{player.UserId}_HotPotato`, "HotPotato", player.Character)
   end
end

function HotPotato.onEnd(player: Player, position: CFrame)
   teardown()
   
   if isServer then
      -- Server context
   else
      -- Client context
      if Particles[player] then
         ParticlesLibrary.destroy(Particles[player])
         Particles[player] = nil
      end
   end
end

if isServer then
else
   explodePlayerRemote.OnClientEvent:Connect(function(player: Player)
      SoundLibrary.play(`{player.UserId}_HotPotato_Explode`, "Explosion", player.Character.PrimaryPart, nil, true)
      if Particles[player] then
         ParticlesLibrary.destroy(Particles[player], false)
         Particles[player] = nil
      end
      local character = CharacterRenderController.getCharacterModel(player)
      if character then
         for _, d in pairs(character:GetDescendants()) do
            if d:IsA("BallSocketConstraint") or d:IsA("Motor6D") then
               d:Destroy()
            elseif d:IsA("MeshPart") or d:IsA("Part") or d:IsA("BasePart") then
               d.Anchored = false
               local randomDirection = Vector3.new(
                  math.random(-10, 10),
                  math.random(5, 15),
                  math.random(-10, 10)
               ).Unit
               local power = math.random(30, 60)
               d.AssemblyLinearVelocity = randomDirection * power
            end
         end
      end
   end)
end

return HotPotato