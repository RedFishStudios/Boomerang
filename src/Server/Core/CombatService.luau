-- // Handles behavior of thrown weapons

--[[
  Handles equipping/unequipping of tools to the character
  - Boomerangs, shuricans, fans, special weapons, etc
]]

local CombatService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)
local ProfileTemplate = require(ReplicatedStorage.Shared.Data.ProfileTemplate)
local RemoteCodes = require(ReplicatedStorage.Shared.Networking.RemoteCodes)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local ThrownWeapons = require(ReplicatedStorage.Shared.Referential.ThrownWeapons)
local Tools = require(ReplicatedStorage.Shared.Constants.Tools)
local CurrentGameState = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local ArenaService = require(ServerStorage.Server.Core.ArenaService)
local HitboxLibrary = require(ReplicatedStorage.Shared.Library.HitboxLibrary)
local CombatLibrary = require(ReplicatedStorage.Shared.Library.CombatLibrary)
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function CombatService.init()
   local elimMessageRemote = SimpleRemotes.getEvent("ElimMessage")
   
   -- Map weapon IDs to ElimType strings
   local function getElimType(weaponId: string): string?
      -- Check if this is a thrown weapon by looking at the Tools table
      local tool = Tools[weaponId]
      if tool and tool.LogicClass == "Boomerang" then
         return "Boomerang"
      elseif weaponId == "Stab" then
         return "Stab"
      elseif weaponId == "FireEffect" then
         return "Burned"
      end
      return nil
   end
   
   CombatLibrary.PlayerKilledPlayerTasks:Add(function(killer: Player, victim: Player, weaponId: string)
      warn(`combatservice detected kill`)
      if not killer or not victim then
         print("NO KILLER OR VICTIM")
         print(killer, victim)
         return
      end
      local killerProfile = PlayerDataService.get(killer)
      if not killerProfile then
         print("NO KILLER PROFILE")
         return
      end
      killerProfile.Elims += 1
      
      -- Fire ElimMessage to all players
      local elimType = getElimType(weaponId)
      print(weaponId)
      if elimType then
         print("SENDING")
         elimMessageRemote:FireAllClients(killer.UserId, victim.UserId, elimType)
      end
   end)
end

return CombatService