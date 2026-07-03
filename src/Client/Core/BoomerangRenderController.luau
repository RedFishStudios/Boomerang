--[[
   Handles clientside boomerang rendering operations
   - Model assignment
   - Positioning assignment
]]

local BoomerangRenderController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local BufferUtil = require(ReplicatedStorage.Shared.Utils.BufferUtil)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)

local RenderedParts: {
   [number]: BasePart
} = {}

local ActiveTweens: {
   [number]: Tween
} = {}

local PendingTargets: {
   [number]: Vector3
} = {}

local LastPacketTimes: {
   [number]: number
} = {}

local LastPacketDeltas: {
   [number]: number
} = {}


local thrownBoomerangSpawnedRemote = SimpleRemotes.getEvent("ThrownBoomerangSpawned")
local thrownBoomerangDespawnedRemote = SimpleRemotes.getEvent("ThrownBoomerangDespawned")
local thrownWeaponReplicationRemote = SimpleRemotes.getUnreliableEvent("ThrownWeaponReplication")
local thrownWeaponsFolder = Workspace:FindFirstChild("ThrownWeapons") or Workspace

local MIN_TWEEN_TIME = 0.03
local MAX_TWEEN_TIME = 0.2
local EXPECTED_PACKET_DELTA = 1 / 30
-- TYPES

local function getRenderedPartName(userId: number): string
   return `RenderedBoomerang_{userId}`
end

local function stopActiveTween(userId: number)
   local tween = ActiveTweens[userId]
   if tween then
      tween:Cancel()
      ActiveTweens[userId] = nil
   end
end

local function clearRenderedBoomerang(userId: number)
   stopActiveTween(userId)

   local renderedPart = RenderedParts[userId]
   if renderedPart then
      renderedPart:Destroy()
      RenderedParts[userId] = nil
   end

   PendingTargets[userId] = nil
   LastPacketTimes[userId] = nil
   LastPacketDeltas[userId] = nil
end

local function playNextTweenIfAvailable(userId: number)
   local renderedPart = RenderedParts[userId]
   if not renderedPart or not renderedPart.Parent then
      PendingTargets[userId] = nil
      return
   end

   local targetPosition = PendingTargets[userId]
   if not targetPosition then
      return
   end

   PendingTargets[userId] = nil

   local distance = (targetPosition - renderedPart.Position).Magnitude
   if distance <= 0.001 then
      playNextTweenIfAvailable(userId)
      return
   end

   local packetDelta = LastPacketDeltas[userId] or EXPECTED_PACKET_DELTA
   local lagFactor = math.clamp(packetDelta / EXPECTED_PACKET_DELTA, 1, 6)
   local catchupSpeed = 40 * lagFactor
   local tweenDuration = math.clamp(distance / catchupSpeed, MIN_TWEEN_TIME, MAX_TWEEN_TIME)

   local tweenInfo = TweenInfo.new(tweenDuration, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
   local tween = TweenService:Create(renderedPart, tweenInfo, { Position = targetPosition })
   ActiveTweens[userId] = tween
   tween.Completed:Connect(function()
      if ActiveTweens[userId] == tween then
         ActiveTweens[userId] = nil
      end
      playNextTweenIfAvailable(userId)
   end)
   tween:Play()
end

local function createOrReplaceRenderedPart(userId: number, position: Vector3, boomerangId: string)
   local existing = RenderedParts[userId]
   if existing then
      stopActiveTween(userId)
      existing:Destroy()
      RenderedParts[userId] = nil
   end

   local renderedPart = Instance.new("Part")
   renderedPart.Name = getRenderedPartName(userId)
   renderedPart.Anchored = true
   renderedPart.CanCollide = false
   renderedPart.CanQuery = false
   renderedPart.CanTouch = false
   renderedPart.Material = Enum.Material.Neon
   renderedPart.Color = Color3.fromRGB(255, 170, 0)
   renderedPart.Size = Vector3.new(5, 5, 5)
   renderedPart.Shape = Enum.PartType.Ball
   renderedPart.Position = position
   renderedPart:SetAttribute("BoomerangId", boomerangId)
   renderedPart.Parent = thrownWeaponsFolder

   RenderedParts[userId] = renderedPart
   LastPacketTimes[userId] = os.clock()
   LastPacketDeltas[userId] = EXPECTED_PACKET_DELTA
   PendingTargets[userId] = nil
end

local function applyReplicationPayload(payload: buffer)
   local offset = 0
   local ownerUserId
   local currentPosition

   ownerUserId, offset = BufferUtil.readu32(payload, offset)
   currentPosition, offset = BufferUtil.readVector3_96(payload, offset)

   local renderedPart = RenderedParts[ownerUserId]
   if not renderedPart or not renderedPart.Parent then
      return
   end

   local now = os.clock()
   local previousPacketTime = LastPacketTimes[ownerUserId] or now
   local packetDelta = math.max(now - previousPacketTime, EXPECTED_PACKET_DELTA)
   LastPacketTimes[ownerUserId] = now
   LastPacketDeltas[ownerUserId] = packetDelta

   PendingTargets[ownerUserId] = currentPosition
   if not ActiveTweens[ownerUserId] then
      playNextTweenIfAvailable(ownerUserId)
   end
end

function BoomerangRenderController.init()
   thrownBoomerangSpawnedRemote.OnClientEvent:Connect(function(ownerUserId: number, position: Vector3, boomerangId: string)
      createOrReplaceRenderedPart(ownerUserId, position, boomerangId)
   end)

   thrownBoomerangDespawnedRemote.OnClientEvent:Connect(function(payload: buffer)
      local ownerUserId = BufferUtil.readu32(payload, 0)
      clearRenderedBoomerang(ownerUserId)
   end)

   thrownWeaponReplicationRemote.OnClientEvent:Connect(function(payload: buffer)
      applyReplicationPayload(payload)
   end)
end

function BoomerangRenderController.start() end

function BoomerangRenderController.test() end

return BoomerangRenderController
