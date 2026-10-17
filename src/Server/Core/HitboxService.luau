--[[
  Handles player team assignment

  TODO:
  - When a player joins, if currently in a team-based match, assign to the team with the least players

TODO: figure out how teams should work
do i want to deal with default roblox bs or do i want to override it completely
dealing with default roblox system might be good for an MVP since it visualizes in the UI. it should just be very easy to modify for the future.

  Author:
  @Soulsplosion
]]

local HitboxService = {}

local _Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local _ServerStorage = game:GetService("ServerStorage")

local CollisionGroupConstants = require(ReplicatedStorage.Shared.Constants.CollisionGroupConstants)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)
local HitboxLibrary = require(ReplicatedStorage.Shared.Library.HitboxLibrary)
local GlobalConfig = require(ReplicatedStorage.Shared.Constants.GlobalConfig)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------



-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local hitboxes: {[Player]: Part} = {}
local characterDescendantAddedConnections: {[Player]: RBXScriptConnection} = {}

local HITBOX_COLLISION_GROUP = CollisionGroupConstants.Players
local HITBOX_VISIBLE_TRANSPARENCY = 0.6 -- // Transparency of a hitbox while Cmdr `viewhitbox` has them shown (they are invisible otherwise)
local hitboxesVisible = false
local HITBOX_HEIGHT = 10 -- // Studs tall, centered on the root part
local hitboxRadius: number = GlobalConfig.PlayerHitboxRadius

-- // A cylinder part's axis is X and its width is the SMALLER of Y and Z, so both are set to the diameter on purpose
local function getHitboxSize(): Vector3
   local diameter = hitboxRadius * 2
   return Vector3.new(HITBOX_HEIGHT, diameter, diameter)
end

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function onCharacterLoaded(player: Player, character: Model, humanoid: Humanoid, rootPart: BasePart)
   if characterDescendantAddedConnections[player] then
      characterDescendantAddedConnections[player]:Disconnect()
      characterDescendantAddedConnections[player] = nil
   end

   for _, descendant in pairs(character:GetDescendants()) do
      if descendant:IsA("BasePart") then
         descendant.CollisionGroup = HITBOX_COLLISION_GROUP
      end
   end

   characterDescendantAddedConnections[player] = character.DescendantAdded:Connect(function(descendant)
      if descendant:IsA("BasePart") then
         descendant.CollisionGroup = HITBOX_COLLISION_GROUP
      end
   end)

   if hitboxes[player] then
      hitboxes[player]:Destroy()
      hitboxes[player] = nil
   end

   local hitbox = Instance.new("Part")
   hitbox.Size = getHitboxSize()
   hitbox.Shape = Enum.PartType.Cylinder
   hitbox.Massless = true
   hitbox.Anchored = false
   -- multiply the pivot to angle by 90 degrees so that the cylinder is oriented correctly (vertically)
   hitbox:PivotTo(rootPart.CFrame * CFrame.Angles(0, 0, math.rad(90)))
   hitbox.Parent = character
   hitbox.CanCollide = false
   hitbox.CanTouch = true
   hitbox.CanQuery = true
   hitbox.Transparency = if hitboxesVisible then HITBOX_VISIBLE_TRANSPARENCY else 1
   hitbox.Color = Color3.new(1, 0, 0)
   hitbox.Name = "Hitbox"
   hitbox.CollisionGroup = HITBOX_COLLISION_GROUP

   local weld = Instance.new("WeldConstraint")
   weld.Part0 = hitbox
   weld.Part1 = rootPart
   weld.Parent = hitbox

   hitboxes[player] = hitbox
end

local function everyFrame(deltaTime)
   for player, hitbox in pairs(hitboxes) do
      if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
         --hitbox.CFrame = player.Character.HumanoidRootPart.CFrame
      else
         hitboxes[player]:Destroy()
         hitboxes[player] = nil
      end
   end
end

------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function HitboxService.getHitbox(player)
   return hitboxes[player]
end

-- // Shows or hides every player's Hitbox (debug; the part replicates, so everyone sees it). Applies to hitboxes created later too.
function HitboxService.setVisible(visible: boolean)
   hitboxesVisible = visible
   for _, hitbox in pairs(hitboxes) do
      hitbox.Transparency = if visible then HITBOX_VISIBLE_TRANSPARENCY else 1
   end
end

-- // Radius (studs) of the player Hitbox. Setting it resizes every existing Hitbox (the part is welded to the root, so it stays
-- // centered) and is used for hitboxes created from now on (respawns). Not saved.
function HitboxService.setRadius(radius: number)
   hitboxRadius = radius
   local size = getHitboxSize()
   for _, hitbox in pairs(hitboxes) do
      hitbox.Size = size
   end
end

function HitboxService.getRadius(): number
   return hitboxRadius
end

function HitboxService.getDefaultRadius(): number
   return GlobalConfig.PlayerHitboxRadius
end

function HitboxService.isVisible(): boolean
   return hitboxesVisible
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function HitboxService.init()
   for _, p in pairs(PlayersUtil.getPlayersWithLoadedCharacters()) do
      print(p)
      onCharacterLoaded(p, p.Character, p.Character.Humanoid, p.Character.PrimaryPart)
   end

   PlayersUtil.CharacterLoaded:Add(onCharacterLoaded)

   PlayersUtil.CharacterDestroying:Add(function(player: Player, character: Model)
		if characterDescendantAddedConnections[player] then
			characterDescendantAddedConnections[player]:Disconnect()
			characterDescendantAddedConnections[player] = nil
		end

		if hitboxes[player] then
         hitboxes[player]:Destroy()
         hitboxes[player] = nil
      end
	end)

   PlayersUtil.PlayerRemoving:Add(function(player: Player)
      if characterDescendantAddedConnections[player] then
         characterDescendantAddedConnections[player]:Disconnect()
         characterDescendantAddedConnections[player] = nil
      end

      if hitboxes[player] then
         hitboxes[player]:Destroy()
         hitboxes[player] = nil
      end
   end)

   PlayersUtil.CharacterDied:Add(function(player: Player, character: Model)
      if hitboxes[player] then
         hitboxes[player].CanTouch = false
         hitboxes[player].CanQuery = false
         -- This prevents the hitbox from from falling through the world and taking the client's camera with it
         -- If you remove this anchoring, you have to configure what happens with the root part and the player's camera when the player dies
         hitboxes[player].Anchored = true
      end
   end)

   RunService.Heartbeat:Connect(everyFrame)
end

function HitboxService.start()

end

function HitboxService.test()

end

return HitboxService