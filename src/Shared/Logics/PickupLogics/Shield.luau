-- STUD
-- TODO
-- Gives the player an extra hit. If the player is hit, the shield is removed.

local Shield = {}

local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GlobalConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"):WaitForChild("GlobalConfig"))
local PickupCancelCodeEnum = require(ReplicatedStorage.Shared.Constants.Enums.PickupCancelCodes)

local isServer = RunService:IsServer()

local CharacterRenderController

if isServer then
else
   CharacterRenderController = require(ReplicatedStorage:WaitForChild("Client"):WaitForChild("Core"):WaitForChild("CharacterRenderController"))
end

local highlights: {[Player]: Highlight} = {}

local SHIELD_DURATION_SECONDS = 20

function Shield.onPickup(player: Player, timestamp: number?): number?
   if isServer then
      -- Server context
   else
      -- Client context
      local character = CharacterRenderController.getCharacterModel(player)
      if not character then
         return
      end

      if highlights[player] then
         highlights[player]:Destroy()
         highlights[player] = nil
      end

      local highlight = Instance.new("Highlight")
      highlight.Adornee = character
      highlight.Parent = character
      highlight.FillColor = Color3.fromRGB(0, 255, 255)
      highlight.FillTransparency = .5
      highlight.OutlineTransparency = 1
      highlights[player] = highlight
   end

   return (timestamp or workspace:GetServerTimeNow()) + SHIELD_DURATION_SECONDS
end

function Shield.simulateActivation(player: Player, timestamp: number): number?
   if isServer then
      warn(`simulate activation is only for client contexts`)
      return nil
   else
      -- Client context
      return Shield.onPickup(player, timestamp)
   end
end

function Shield.onEnd(player: Player, cancelCode: string?)
   if isServer then
      -- Server context
   else
      -- Client context
      if highlights[player] then
         highlights[player]:Destroy()
         highlights[player] = nil
      end
      if cancelCode then
         if cancelCode == PickupCancelCodeEnum.ShieldBroken then
            warn(`CANCEL CODE: SHIELD EFFECT BROKEN FOR PLAYER {player.Name}`)
         end
      end
   end
end

return Shield