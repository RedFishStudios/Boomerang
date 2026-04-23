--[[
  SoundController

  Description:
  Handles sound on the client

  Author:
  @SixthAtom

  Date:
  07-04-2026
]]

local SoundController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local soundsLUT: { [string]: Sound } = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function SoundController.play(name: string, pitch: number?)
	local sound = soundsLUT[name]
	if not sound then
		error(`Sound {name} doesn't exist`)
	end

	sound.PlaybackSpeed = pitch or 1
	sound:Play()
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function SoundController.init()
	for _, v in next, SoundService:QueryDescendants("Sound") :: { Sound } do
		soundsLUT[v.Name] = v
	end
end

-- function SoundController.start() end

-- function SoundController.test() end

return SoundController
