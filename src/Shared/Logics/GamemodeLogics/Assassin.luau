-- // Assassin: every player hunts one assigned target; hitting anyone besides your target or your assassin kills you instead

local AssassinRoundLogic = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local CombatLibrary = require(ReplicatedStorage.Shared.Library.CombatLibrary)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)

local isServer = RunService:IsServer()
local GameTeamService
local LeaderstatService
local CharacterRenderController
if isServer then
   GameTeamService = require(ServerStorage.Server.Core.GameTeamService)
   LeaderstatService = require(ServerStorage.Server.Core.LeaderstatService)
else
   CharacterRenderController = require(ReplicatedStorage.Client.Core.CharacterRenderController)
end

--------------------------------------------------------------------------------
-- CONSTANTS
--------------------------------------------------------------------------------

local ATTACK_CALLBACK_KEY = "Assassin"
local WRONG_TARGET_CAUSE_LABEL = "Attacking a non-target"
local POINTS_STAT = "Points"
local TARGET_HIGHLIGHT_COLOR = Color3.fromRGB(255, 0, 0)

local targetUpdatedRemote = SimpleRemotes.getEvent("AssassinTargetUpdated")

--------------------------------------------------------------------------------
-- PER-SESSION VALUES
--------------------------------------------------------------------------------

-- Server Only
local PerMatchDestroyerFunctions: {()->()} = {}
local Points: {[Player]: number} = {}
local Members: {[Player]: true} = {}
local Targets: {[Player]: Player} = {}

-- Client Only
local localTargetUserId: number? = nil
local targetHighlight: Highlight? = nil
local highlightedModel: Model? = nil
local highlightConnection: RBXScriptConnection? = nil

--------------------------------------------------------------------------------
-- SERVER: TARGETS
--------------------------------------------------------------------------------

local function countAssassins(player: Player): number
   local count = 0
   for _, target in pairs(Targets) do
      if target == player then
         count += 1
      end
   end
   return count
end

local function pickRandom(players: {Player}): Player?
   if #players == 0 then
      return nil
   end
   return players[math.random(1, #players)]
end

local function setTarget(hunter: Player, target: Player?)
   Targets[hunter] = target
   if hunter.Parent == Players then
      targetUpdatedRemote:FireClient(hunter, if target then target.UserId else nil)
   end
end

-- // TARGET SELECTION: edit this to change how new targets are chosen.
-- // preferredTarget (the removed player's target) wins step 1 when eligible so the ring stays intact.
local function chooseTarget(hunter: Player, preferredTarget: Player?): Player?
   local candidates = {}
   for member in pairs(Members) do
      if member ~= hunter then
         table.insert(candidates, member)
      end
   end
   if #candidates == 0 then
      return nil
   end

   -- 1. Players without an assassin
   local unhunted = {}
   for _, candidate in ipairs(candidates) do
      if countAssassins(candidate) == 0 then
         table.insert(unhunted, candidate)
      end
   end
   if preferredTarget and table.find(unhunted, preferredTarget) then
      return preferredTarget
   end
   if #unhunted > 0 then
      return pickRandom(unhunted)
   end

   -- 2. Players whose own target has multiple assassins
   local backups = {}
   for _, candidate in ipairs(candidates) do
      local candidateTarget = Targets[candidate]
      if candidateTarget and countAssassins(candidateTarget) > 1 then
         table.insert(backups, candidate)
      end
   end
   if #backups > 0 then
      return pickRandom(backups)
   end

   -- 3. Players with the most points (random among ties)
   local leaders = {}
   local mostPoints = -1
   for _, candidate in ipairs(candidates) do
      local points = Points[candidate] or 0
      if points > mostPoints then
         mostPoints = points
         leaders = {candidate}
      elseif points == mostPoints then
         table.insert(leaders, candidate)
      end
   end
   return pickRandom(leaders)
end

local function assignTarget(hunter: Player, preferredTarget: Player?)
   Targets[hunter] = nil
   setTarget(hunter, chooseTarget(hunter, preferredTarget))
end

local function assignTargetlessMembers(except: Player?)
   for member in pairs(Members) do
      if member ~= except and not Targets[member] then
         assignTarget(member)
      end
   end
end

local function addMember(player: Player)
   if Members[player] then
      return
   end
   Members[player] = true
   -- // Targetless members (e.g. a lone survivor) choose first so the newcomer can fill their slot
   assignTargetlessMembers(player)
   assignTarget(player)
end

local function removeMember(player: Player)
   if not Members[player] then
      return
   end
   Members[player] = nil
   local removedTarget = Targets[player]
   setTarget(player, nil)

   local orphanedHunters = {}
   for hunter, target in pairs(Targets) do
      if target == player then
         table.insert(orphanedHunters, hunter)
      end
   end
   for _, hunter in ipairs(orphanedHunters) do
      assignTarget(hunter, removedTarget)
   end
   assignTargetlessMembers()
end

local function formInitialRing(players: {Player})
   local shuffled = table.clone(players)
   local random = Random.new()
   for i = #shuffled, 2, -1 do
      local j = random:NextInteger(1, i)
      shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
   end
   for _, player in ipairs(shuffled) do
      Members[player] = true
   end
   if #shuffled < 2 then
      return
   end
   for i, player in ipairs(shuffled) do
      setTarget(player, shuffled[(i % #shuffled) + 1])
   end
end

local function clear()
   for _, destroyer in ipairs(PerMatchDestroyerFunctions) do
      destroyer()
   end
   table.clear(PerMatchDestroyerFunctions)
   table.clear(Points)
   table.clear(Members)
   table.clear(Targets)
end

local function onAttackHitPlayer(attacker: Player?, _attackerToolId: string?, victim: Player, victimHumanoid: Humanoid?, _damageAmount: number): boolean
   if not attacker or attacker == victim then
      return false
   end
   -- // Already-dead victims would otherwise be credited twice
   if victimHumanoid and victimHumanoid.Health <= 0 then
      return true
   end
   local attackerHumanoid = PlayersUtil.getHumanoid(attacker)
   if not attackerHumanoid then
      return true
   end

   if Targets[attacker] == victim then
      Points[attacker] = (Points[attacker] or 0) + 1
      LeaderstatService.setValue(attacker, POINTS_STAT, Points[attacker])
      return false
   elseif Targets[victim] == attacker then
      return false
   end

   CombatLibrary.applyDamageToHumanoid(attacker, attackerHumanoid, 10000, nil, WRONG_TARGET_CAUSE_LABEL)
   return true
end

--------------------------------------------------------------------------------
-- CLIENT: TARGET HIGHLIGHT
--------------------------------------------------------------------------------

local function clearTargetHighlight()
   if targetHighlight then
      targetHighlight:Destroy()
      targetHighlight = nil
   end
   highlightedModel = nil
end

-- // The rendered model is rebuilt on respawn and swapped on disguise, so re-resolve it every frame
local function updateTargetHighlight()
   local target = localTargetUserId and Players:GetPlayerByUserId(localTargetUserId)
   local model = target and CharacterRenderController.getCharacterModel(target, false)
   if model == highlightedModel and targetHighlight and targetHighlight.Parent then
      return
   end
   clearTargetHighlight()
   if not model then
      return
   end
   local highlight = Instance.new("Highlight")
   highlight.FillColor = TARGET_HIGHLIGHT_COLOR
   highlight.OutlineColor = TARGET_HIGHLIGHT_COLOR
   highlight.Parent = model
   targetHighlight = highlight
   highlightedModel = model
end

--------------------------------------------------------------------------------
-- CORE
--------------------------------------------------------------------------------

function AssassinRoundLogic.setup()
   if not isServer then
      if highlightConnection then
         highlightConnection:Disconnect()
      end
      highlightConnection = RunService.Heartbeat:Connect(updateTargetHighlight)
      return
   end
   clear()
   GameTeamService.setFreeForAll()

   LeaderstatService.enableStat(POINTS_STAT)
   table.insert(PerMatchDestroyerFunctions, function()
      LeaderstatService.disableStat(POINTS_STAT)
   end)

   formInitialRing(GameStateLibrary.getGameStateData().LivingPlayersInArena:Get())

   CombatLibrary.addAttackHitPlayerCallback(ATTACK_CALLBACK_KEY, onAttackHitPlayer)
   table.insert(PerMatchDestroyerFunctions, function()
      CombatLibrary.removeAttackHitPlayerCallback(ATTACK_CALLBACK_KEY)
   end)

   table.insert(PerMatchDestroyerFunctions, GameStateLibrary.PlayerAddedToArenaTasks:Add(addMember))
   table.insert(PerMatchDestroyerFunctions, GameStateLibrary.PlayerRemovedFromArenaTasks:Add(removeMember))

   table.insert(PerMatchDestroyerFunctions, PlayersUtil.GameEnteredTooFewPlayers:Add(function()
      AssassinRoundLogic.teardown()
   end))
end

function AssassinRoundLogic.teardown()
   if not isServer then
      if highlightConnection then
         highlightConnection:Disconnect()
         highlightConnection = nil
      end
      localTargetUserId = nil
      clearTargetHighlight()
      return
   end
   local winner
   local highestPoints = 0
   local isTie = false
   for player, points in pairs(Points) do
      if points > highestPoints then
         highestPoints = points
         winner = player
         isTie = false
      elseif points == highestPoints and points > 0 then
         isTie = true
      end
   end
   if isTie then
      winner = nil
   end
   clear()
   GameStateLibrary.RoundFinishedTasks:Execute("parallel", winner, nil, isTie)
end

if not isServer then
   targetUpdatedRemote.OnClientEvent:Connect(function(targetUserId: number?)
      localTargetUserId = targetUserId
   end)
end

return AssassinRoundLogic
