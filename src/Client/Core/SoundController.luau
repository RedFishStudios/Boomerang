--[[
]]

local SoundController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local HttpService = game:GetService("HttpService")

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type SoundProperties = {
   volume: number?,
   pitch: number?,
   speed: number?,
   noDuplicates: boolean?, -- true = cannot play multiple times at once
   throttle: number?, -- minimum seconds between plays
   -- etc
}

type SoundData = {
   id: number,
} & SoundProperties

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local soundData: {
   [string]: SoundData
} = {}

local sounds: {
   [string]: Sound
} = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function generateSoundInstanceId(): string
   return HttpService:GenerateGUID(false)
end

local function resolveSoundData(soundName: string | number): SoundData?
   if typeof(soundName) == "string" then
      return soundData[soundName]
   elseif typeof(soundName) == "number" then
      for _, sound in pairs(soundData) do
         if sound.id == soundName then
            return sound
         end
      end
   end
   return nil
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function SoundController.fade(soundInstanceId: string, fadeSeconds: number, toNewSoundName: string | number, host: Instance)
   local newSoundData = resolveSoundData(toNewSoundName)
   if not newSoundData then
      warn(`Sound data for {toNewSoundName} not found`)
      return
   end
   -- Identify the existing sound using soundInstanceId
   -- If it is found, fade it out while fading the new sound id in
   -- If it is not found, fade in the new sound id regardless
end

function SoundController.play(soundName: string | number): string?
   local soundData = resolveSoundData(soundName)
   if not soundData then
      warn(`Sound data for {soundName} not found`)
      return nil
   end

   if soundData.noDuplicates then
      for _, soundInstance in pairs(sounds) do
         if soundInstance.SoundId == `rbxassetid://{soundData.id}` then
            warn(`Sound {soundName} is already playing and noDuplicates is set`)
            return nil
         end
      end
   end

   if soundData.throttle then
      local currentTime = game.Workspace:GetServerTimeNow().Timestamp
      -- TODO: enforce throttle
   end

   local soundInstanceId = generateSoundInstanceId()
   local soundInstance = Instance.new("Sound")
   soundInstance.SoundId = `rbxassetid://{soundData.id}`
   soundInstance:Play()
   sounds[soundInstanceId] = soundInstance
   -- TODO: destroy when done playing but in a way that is safe and doesn't interfere with fade or sequences

   return soundInstanceId
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function SoundController.init()
end

-- function SoundController.start() end

-- function SoundController.test() end

return SoundController
