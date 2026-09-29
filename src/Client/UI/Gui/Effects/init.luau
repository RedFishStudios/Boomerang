local EffectsGui = {}
EffectsGui.Type = "HUD"
EffectsGui.Open = false
EffectsGui.SupercededBy = {}

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Player = game:GetService("Players").LocalPlayer

-- // Modules // --

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SharedMods = ReplicatedStorage.Shared

local GameStateLibrary = require(SharedMods.Library.GameStateLibrary)
local PickupLibrary = require(SharedMods.Library.PickupLibrary)
local AcquirableThingData = require(SharedMods.Referential.AcquirableThingData)

-- // Gui Values // --

local Gui = script:WaitForChild("Effects") :: ScreenGui
local RootFrame = Gui:WaitForChild("Root") :: Frame
local EffectFrameTemplate = script:WaitForChild("EffectFrameTemplate") :: CanvasGroup

local EFFECT_FRAME_PADDING = 0.15 -- Gap between frames, as a fraction of RootFrame's width
local PERMANENT_EFFECT_TEXT = "-"
local MOVE_TWEEN_INFO = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FADE_IN_TWEEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local FADE_OUT_TWEEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

type ActiveEffect = {
   Frame: CanvasGroup,
   TimerLabel: TextLabel,
   EndsAt: number?,
   ShownSeconds: number?,
   MoveTween: Tween?,
   FadeTween: Tween?,
   Destroyed: boolean,
}

local activeEffects: {[PickupLibrary.LivePickupId]: ActiveEffect} = {}
local effectOrder: {PickupLibrary.LivePickupId} = {} -- Acquisition order; left to right

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Layout
-- // Simulates a centered horizontal list; frames glide to new slots, except a just-added frame which snaps into place

local function getEffectFramePosition(index: number, count: number): UDim2
   local offsetFromCenter = (index - (count + 1) / 2) * (1 + EFFECT_FRAME_PADDING)
   return UDim2.fromScale(0.5 + offsetFromCenter, 0.5)
end

local function layoutEffectFrames(newlyAddedEffect: ActiveEffect?)
   local count = #effectOrder
   for index, livePickupId in ipairs(effectOrder) do
      local effect = activeEffects[livePickupId]
      local goalPosition = getEffectFramePosition(index, count)
      if effect.MoveTween then
         effect.MoveTween:Cancel()
         effect.MoveTween = nil
      end
      if effect == newlyAddedEffect then
         effect.Frame.Position = goalPosition
      elseif effect.Frame.Position ~= goalPosition then
         local moveTween = TweenService:Create(effect.Frame, MOVE_TWEEN_INFO, { Position = goalPosition })
         effect.MoveTween = moveTween
         moveTween:Play()
      end
   end
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Fading

local function playFade(effect: ActiveEffect, tweenInfo: TweenInfo, goalTransparency: number): Tween
   if effect.FadeTween then
      effect.FadeTween:Cancel()
   end
   local fadeTween = TweenService:Create(effect.Frame, tweenInfo, { GroupTransparency = goalTransparency })
   effect.FadeTween = fadeTween
   fadeTween:Play()
   return fadeTween
end

local function destroyEffectFrame(effect: ActiveEffect)
   if effect.Destroyed then
      return
   end
   effect.Destroyed = true
   effect.Frame:Destroy()
end

local function fadeOutAndDestroy(effect: ActiveEffect)
   if effect.MoveTween then
      effect.MoveTween:Cancel()
      effect.MoveTween = nil
   end
   local fadeTween = playFade(effect, FADE_OUT_TWEEN_INFO, 1)
   -- // Fires on cancellation too, so the frame is never orphaned
   fadeTween.Completed:Once(function()
      destroyEffectFrame(effect)
   end)
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Local Functions

local function updateEffectTimer(effect: ActiveEffect, now: number)
   if not effect.EndsAt then
      if effect.ShownSeconds ~= nil or effect.TimerLabel.Text ~= PERMANENT_EFFECT_TEXT then
         effect.ShownSeconds = nil
         effect.TimerLabel.Text = PERMANENT_EFFECT_TEXT
      end
      return
   end
   local secondsLeft = math.max(0, math.ceil(effect.EndsAt - now))
   if effect.ShownSeconds ~= secondsLeft then
      effect.ShownSeconds = secondsLeft
      effect.TimerLabel.Text = tostring(secondsLeft)
   end
end

local function updateAllEffectTimers()
   local now = workspace:GetServerTimeNow()
   for _, effect in pairs(activeEffects) do
      updateEffectTimer(effect, now)
   end
end

local function addEffect(livePickupId: PickupLibrary.LivePickupId, pickupClassId: PickupLibrary.PickupClassId, endsAt: number?)
   local existing = activeEffects[livePickupId]
   if existing then
      existing.EndsAt = endsAt
      updateEffectTimer(existing, workspace:GetServerTimeNow())
      return
   end

   local thingData = AcquirableThingData[pickupClassId]
   if not thingData then
      return
   end

   local frame = EffectFrameTemplate:Clone()
   frame.AnchorPoint = Vector2.new(0.5, 0.5)
   frame.Size = UDim2.fromScale(1, 1)
   local imageLabel = frame:WaitForChild("ImageLabel") :: ImageLabel
   imageLabel.Image = `rbxassetid://{thingData.Img}`

   local effect: ActiveEffect = {
      Frame = frame,
      TimerLabel = frame:WaitForChild("TextLabel") :: TextLabel,
      EndsAt = endsAt,
      ShownSeconds = nil,
      MoveTween = nil,
      FadeTween = nil,
      Destroyed = false,
   }
   updateEffectTimer(effect, workspace:GetServerTimeNow())

   activeEffects[livePickupId] = effect
   table.insert(effectOrder, livePickupId)
   layoutEffectFrames(effect)
   frame.GroupTransparency = 1
   frame.Parent = RootFrame
   playFade(effect, FADE_IN_TWEEN_INFO, 0)
end

local function removeEffect(livePickupId: PickupLibrary.LivePickupId)
   local effect = activeEffects[livePickupId]
   if not effect then
      return
   end
   activeEffects[livePickupId] = nil
   local index = table.find(effectOrder, livePickupId)
   if index then
      table.remove(effectOrder, index)
   end
   fadeOutAndDestroy(effect)
   layoutEffectFrames()
end

-- // Refresh hud display using current game state data
local function refreshUiFromGameState()
   if GameStateLibrary.getGameStateData().CurrentRoundData:Get() == nil then
      EffectsGui.close()
   else
      EffectsGui.open()
   end
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Public Functions

function EffectsGui.open()
   EffectsGui.Open = true
   if #EffectsGui.SupercededBy > 0 then
      return
   end
   Gui.Enabled = true
end

function EffectsGui.close(_Instant: boolean?)
   EffectsGui.Open = false
   Gui.Enabled = false
end

function EffectsGui.supercede()
   if not EffectsGui.Open then
      return
   end
   Gui.Enabled = false
end

----------------------------------------------------------------------------------------------------------------------------------------------------------------

local function _init()
   Gui.Parent = Player.PlayerGui
   Gui.Enabled = false
end
_init()

function EffectsGui.start()
   PickupLibrary.PickupEffectAddedTasks:Add(function(userId, livePickupId, pickupClassId, endsAt)
      if userId == Player.UserId then
         addEffect(livePickupId, pickupClassId, endsAt)
      end
   end)
   PickupLibrary.PickupEffectRemovedTasks:Add(function(userId, livePickupId, _pickupClassId)
      if userId == Player.UserId then
         removeEffect(livePickupId)
      end
   end)
   for livePickupId, effectData in pairs(PickupLibrary.UserPickupEffectsActive[Player.UserId] or {}) do
      addEffect(livePickupId, effectData.ClassId, effectData.EndsAt)
   end

   RunService.Heartbeat:Connect(updateAllEffectTimers)

   GameStateLibrary.GameStateSnapshotLoadedTasks:Add(function(_snapshot, _reason)
      refreshUiFromGameState()
   end)
   refreshUiFromGameState()
end

return EffectsGui
