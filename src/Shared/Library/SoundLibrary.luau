--[[
]]

local SoundLibrary = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)

local isServer = game:GetService("RunService"):IsServer()

local SoundData = require(ReplicatedStorage.Shared.Constants.Sounds)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local DEFAULT_HOST = SoundService
local SOUND_REMOTE = SimpleRemotes.getEvent("SoundLibrary")
local ACTION_PLAY = "Play"
local ACTION_STOP = "Stop"

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type AudioChannelId = string

type AudioChannelData = {
   Instance: Sound,
   SoundName: string,
   CurrentTween: Tween?,
   StateOwnerKey: string,
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local lastPlayedAt: {
   [string]: number
} = {}

local activeAudios: {
   [AudioChannelId]: AudioChannelData
} = {}

local didInitclient = false

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function generateAudioId(): string
   return HttpService:GenerateGUID(false)
end

local function generateStateKey(): string
   return HttpService:GenerateGUID(false)
end

-- // Fades out and destroys this current audio channel
local function destroy(audioChannelId: string, audioChannel: AudioChannelData, seconds: number?, createStateId: boolean?)
   activeAudios[audioChannelId] = nil
   local sound = audioChannel.Instance
   local Tween = TweenService:Create(sound, TweenInfo.new(seconds or .25), {Volume = 0})
   Tween:Play()
   Tween.Completed:Once(function()
      sound:Destroy()
      Tween:Destroy()
      Tween = nil
   end)
end

local function playLocal(audioChannelId: AudioChannelId?, soundName: string, host: Instance?, fadeSeconds: number?, bypassLimits: boolean?): (AudioChannelId?, Sound?)
   local thisSoundData = SoundData[soundName]
   if not thisSoundData then
      warn(`Sound data for {soundName} not found`)
      return nil, nil
   end

   if thisSoundData.NoDuplicates and not bypassLimits then
      for _, soundInstanceData in pairs(activeAudios) do
         if soundInstanceData.SoundName == soundName then
            warn(`Sound {soundName} is already playing and noDuplicates is set`)
            return nil, nil
         end
      end
   end

   local currentTime = os.clock()

   if thisSoundData.Throttle and not bypassLimits then
      if lastPlayedAt[soundName] and currentTime - lastPlayedAt[soundName] < thisSoundData.Throttle then
         warn(`Sound {soundName} is being throttled`)
         return nil, nil
      end
      lastPlayedAt[soundName] = currentTime
   end

   local thisStateKey = generateStateKey()

   local oldChannel = activeAudios[audioChannelId]
   if oldChannel then
      if oldChannel.SoundName == soundName then
         -- This sound is already playing on this channel
         print("cancelling sound already playing on this channel")
         return audioChannelId, oldChannel.Instance
      end
      destroy(audioChannelId, oldChannel, fadeSeconds)
   end

   audioChannelId = audioChannelId or generateAudioId()
   local soundInstance = Instance.new("Sound")
   soundInstance.SoundId = `rbxassetid://{thisSoundData.Id}`
   soundInstance.Looped = thisSoundData.Looping
   activeAudios[audioChannelId] = {
      Instance = soundInstance,
      CurrentTween = nil,
      StateOwnerKey = thisStateKey,
      SoundName = soundName,
   }
   soundInstance.Parent = host or DEFAULT_HOST

   if fadeSeconds then
      soundInstance.Volume = 0
      local Tween = TweenService:Create(soundInstance, TweenInfo.new(fadeSeconds), {Volume = thisSoundData.Volume or 1})
      activeAudios[audioChannelId].CurrentTween = Tween
      Tween:Play()
   else
      soundInstance.Volume = thisSoundData.Volume or 1
   end
   soundInstance:Play()
   soundInstance.Ended:Once(function()
      if activeAudios[audioChannelId] and activeAudios[audioChannelId].StateOwnerKey == thisStateKey then
         local Tween = activeAudios[audioChannelId].CurrentTween
         if Tween then
            Tween:Destroy()
            activeAudios[audioChannelId].CurrentTween = nil
         end
         activeAudios[audioChannelId].Instance:Destroy()
         activeAudios[audioChannelId] = nil
      end
   end)

   return audioChannelId, soundInstance
end

local function stopLocal(audioChannelId: AudioChannelId)
   local audioChannel = activeAudios[audioChannelId]
   if audioChannel and audioChannel.Instance then
      destroy(audioChannelId, audioChannel, nil)
   end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-- // Play a sound
function SoundLibrary.play(audioChannelId: AudioChannelId?, soundName: string, host: Instance?, fadeSeconds: number?, bypassLimits: boolean?): (AudioChannelId?, Sound?)
   if isServer then
      SOUND_REMOTE:FireAllClients(ACTION_PLAY, audioChannelId, soundName, host, fadeSeconds, bypassLimits)
      return audioChannelId, nil
   end
   return playLocal(audioChannelId, soundName, host, fadeSeconds, bypassLimits)
end

function SoundLibrary.stop(audioChannelId: AudioChannelId)
   if isServer then
      SOUND_REMOTE:FireAllClients(ACTION_STOP, audioChannelId)
      return
   end
   stopLocal(audioChannelId)
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function SoundLibrary.init()
   if isServer or didInitclient then
      return
   end

   didInitclient = true

   -- // Roblox memory clears sounds that are not currently loaded onto any sound instance
   -- This would create lag as the player would have to re-load a sound every time it is played
   local preloadedSounds = {}
   for _, soundData in pairs(SoundData) do
      if soundData.DoNotPreload then
         continue
      end
      local soundInstance = Instance.new("Sound")
      soundInstance.SoundId = `rbxassetid://{soundData.Id}`
      soundInstance.Looped = soundData.Looping
      soundInstance.Volume = soundData.Volume or 1
      soundInstance.Parent = DEFAULT_HOST
      preloadedSounds[soundData.Name] = soundInstance
   end

   SOUND_REMOTE.OnClientEvent:Connect(function(action: string, ...)
      if action == ACTION_PLAY then
         SoundLibrary.play(...)
         return
      end
      if action == ACTION_STOP then
         SoundLibrary.stop(...)
      end
   end)
end

-- function SoundLibrary.start() end

-- function SoundLibrary.test() end

return SoundLibrary