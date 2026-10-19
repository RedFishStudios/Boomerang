local HitboxLibrary = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local isServer = RunService:IsServer()

-- // Player attribute the server sets while a player is immune (Dash, spawn protection...). It replicates to every client, so
-- // clients read the server's answer instead of keeping their own timers. It is on the Player, not the character, because
-- // under Server Authority a server-only attribute on the predicted character would count as a misprediction.
local IMMUNE_ATTRIBUTE = "HitImmune"

local immunized: {
   [Player]: {
      [string]: any
   }
} = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-- // Server only: mirror the immunity table into the replicated attribute
local function refreshAttribute(player: Player)
   player:SetAttribute(IMMUNE_ATTRIBUTE, if immunized[player] then true else nil)
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-- // Server only (clients read the replicated attribute through isImmunized)
function HitboxLibrary.immunize(player: Player, source: string, id: any)
   if not isServer then
      return
   end
   if not immunized[player] then
      immunized[player] = {}
   end
   immunized[player][source] = id
   refreshAttribute(player)
end

function HitboxLibrary.unImmunize(player: Player, source: string, id: any)
   if not isServer then
      return
   end
   if immunized[player] then
      local current = immunized[player][source]
      if current == id then
         immunized[player][source] = nil
      end
      if not next(immunized[player]) then
         immunized[player] = nil
      end
      refreshAttribute(player)
   end
end

-- // The server's table on the server, the replicated attribute on a client
function HitboxLibrary.isImmunized(player: Player)
   if isServer then
      return immunized[player] ~= nil
   end
   return player:GetAttribute(IMMUNE_ATTRIBUTE) == true
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function HitboxLibrary.init()
   if not isServer then
      return
   end

   PlayersUtil.CharacterAdded:Add(function(player: Player, character: Model, humanoid: Humanoid, rootPart: BasePart)
      local immunizedId = math.random(10000000)
      HitboxLibrary.immunize(player, "SpawnProtection", immunizedId)
      task.wait(2)
      HitboxLibrary.unImmunize(player, "SpawnProtection", immunizedId)
   end)

   PlayersUtil.CharacterDestroying:Add(function(player: Player, character: Model)
      immunized[player] = nil
      refreshAttribute(player)
   end)

   PlayersUtil.CharacterDied:Add(function(player: Player, character: Model)
      immunized[player] = nil
      refreshAttribute(player)
   end)

   PlayersUtil.PlayerRemoving:Add(function(player: Player)
      immunized[player] = nil
   end)
end

return HitboxLibrary