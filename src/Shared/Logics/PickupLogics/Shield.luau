-- Gives the player an extra hit. If the player is hit, the shield is removed.

local Shield = {}

local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GlobalConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"):WaitForChild("GlobalConfig"))
local PickupCancelCodeEnum = require(ReplicatedStorage.Shared.Constants.Enums.PickupCancelCodes)
local ParticlesLibrary = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Library"):WaitForChild("ParticlesLibrary"))

local isServer = RunService:IsServer()

local CharacterRenderController

if isServer then
else
   CharacterRenderController = require(ReplicatedStorage:WaitForChild("Client"):WaitForChild("Core"):WaitForChild("CharacterRenderController"))
end

local highlights: {[Player]: Highlight} = {}
local particles: {[Player]: Part} = {}

local SHIELD_DURATION_SECONDS = 4

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
      if particles[player] then
         particles[player]:Destroy()
         particles[player] = nil
      end

      local particle = ParticlesLibrary.play(`{player.UserId}_Shield`, "Shield", character.PrimaryPart, 1)
      particles[player] = particle

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
      local localCharacter = CharacterRenderController.getCharacterModel(player)
      if not localCharacter then
         return
      end

      -- Client context
      if highlights[player] then
         highlights[player]:Destroy()
         highlights[player] = nil
      end
      if particles[player] then
         particles[player]:Destroy()
         particles[player] = nil
      end
      if cancelCode then
         if cancelCode == PickupCancelCodeEnum.ShieldBroken then
            -- Shield was broken by combat; play a more dramatic break effect and sound?
            ParticlesLibrary.emit(`{player.UserId}_Shield`, "ShieldBreak", localCharacter.PrimaryPart, 1)
         end
      else
         ParticlesLibrary.emit(`{player.UserId}_Shield`, "ShieldBreak", localCharacter.PrimaryPart, 1)
      end
   end
end

return Shield