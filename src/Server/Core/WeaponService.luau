-- // Handles behavior of thrown weapons

--[[
  Handles equipping/unequipping of tools to the character
  - Boomerangs, shuricans, fans, special weapons, etc
]]

local WeaponService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local ItemService = require(ServerStorage.Server.Core.ItemService)
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)
local ProfileTemplate = require(ReplicatedStorage.Shared.Data.ProfileTemplate)
local RoundService = require(ServerStorage.Server.Core.RoundService)
local RemoteCodes = require(ReplicatedStorage.Shared.Networking.RemoteCodes)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local ThrownWeapons = require(ServerStorage.Server.Referential.ThrownWeapons)
local Tools = require(ReplicatedStorage.Shared.Constants.Tools)

local ToolLogics = ServerStorage.Server.Logics
local ToolLogicModules = {}

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type Weapontask= (player: Player, itemName: string) -> ()

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local throwEvent = SimpleRemotes.getEvent("Weapon")
local recallEvent = SimpleRemotes.getEvent("WeaponRecall")

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function getLogic(toolId: string)
	if not ToolLogicModules[toolId] then
		local module = require(ToolLogics:WaitForChild(toolId))
		ToolLogicModules[toolId] = module
	end
	return ToolLogicModules[toolId]
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function WeaponService.init()
	throwEvent.OnServerEvent:Connect(function(player: Player, toolId: string)
      if not RoundService.isInRound() then
         print(`tried to throw weapon while not in round`)
         return
      end
      if ThrownWeapons.Data[player] then
         print(`player already has a thrown weapon`)
         return
      end
      local toolData = Tools[toolId]
      if not toolData then
         print(`invalid toolId`)
         return
      end

      -- TODO: validate that the player owns this weapon and has it equipped this round

      ThrownWeapons.Data[player] = {
         ToolId = toolId,
         State = ThrownWeapons.StateEnum.Outgoing,
         ReplicationPart = nil,
         TestRaycastVisualizers = {}
      }
      for i = 1, 3 do
         local part = Instance.new("Part")
         part.Size = Vector3.new(1, 1, 1)
         part.Anchored = true
         part.CanTouch = false
         part.CanQuery = false
         part.CanCollide = false
         part.Parent = workspace
         ThrownWeapons.Data[player].TestRaycastVisualizers[i] = part
      end

      local Logic = getLogic(toolData.LogicClass)
      Logic.throw(player, toolId, toolData, ThrownWeapons.Data[player])
	end)

   recallEvent.OnServerEvent:Connect(function(Player: Player)
      local thrownWeaponData = ThrownWeapons.Data[Player]
      if not thrownWeaponData then
         print(`player has no thrown weapon to recall`)
         return
      end
      thrownWeaponData.State = ThrownWeapons.StateEnum.Recalling

      local toolData = Tools[thrownWeaponData.ToolId]
      local Logic = getLogic(toolData.LogicClass)
      Logic.recall(Player, thrownWeaponData.ToolId, toolData, thrownWeaponData)
   end)
end

function WeaponService.start() end

function WeaponService.test() end

return WeaponService