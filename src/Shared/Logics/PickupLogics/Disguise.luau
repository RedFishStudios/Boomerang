-- STUD
-- TODO
-- Disguises player as a map object when idle

local Disguise = {}

Disguise.Disabled = false

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)
local MapData = require(ReplicatedStorage.Shared.Constants.MapData)
local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)

local isServer = RunService:IsServer()
local DISGUISE_DURATION_SECONDS = GlobalConfig.GenericEffectTimeout
local PLACEHOLDER_ASSET_ID = "Placeholder"
local disguiseStateRemote = SimpleRemotes.getEvent("DisguiseStateChanged")
local disguiseAssetByUserId: {[number]: string} = {}

Disguise.StateChanged = TasksList.new() :: TasksList.TasksList<(userId: number, active: boolean) -> ()>

local function getAssetForCurrentMap(): string
   local currentRoundData = GameStateLibrary.getGameStateData().CurrentRoundData:Get()
   local mapData = currentRoundData and MapData[currentRoundData.CurrentMapName]
   local assets = mapData and mapData.DisguiseAssets
   if assets and #assets > 0 then
      return assets[math.random(1, #assets)]
   end
   return PLACEHOLDER_ASSET_ID
end

function Disguise.getAssetId(player: Player): string?
   return disguiseAssetByUserId[player.UserId]
end

function Disguise.isActive(player: Player): boolean
   return disguiseAssetByUserId[player.UserId] ~= nil
end

function Disguise.onPickup(player: Player, startedAt: number?): number
   local endsAt = (startedAt or workspace:GetServerTimeNow()) + DISGUISE_DURATION_SECONDS
   if isServer then
      local assetId = getAssetForCurrentMap()
      disguiseAssetByUserId[player.UserId] = assetId
      disguiseStateRemote:FireAllClients(player.UserId, true, assetId)
   end
   return endsAt
end

function Disguise.onEnd(player: Player)
   disguiseAssetByUserId[player.UserId] = nil
   if isServer then
      disguiseStateRemote:FireAllClients(player.UserId, false)
   else
      Disguise.StateChanged:Execute("parallel", player.UserId, false)
   end
end


function Disguise.init()
   if isServer then
      return
   end

   disguiseStateRemote.OnClientEvent:Connect(function(userId: number, active: boolean, assetId: string?)
      if active then
         disguiseAssetByUserId[userId] = assetId or PLACEHOLDER_ASSET_ID
      else
         disguiseAssetByUserId[userId] = nil
      end
      Disguise.StateChanged:Execute("parallel", userId, active)
   end)
end

Disguise.init()

return Disguise