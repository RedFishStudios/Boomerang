local ItemAcquiredGui = {}
ItemAcquiredGui.Type = "HUD"
ItemAcquiredGui.Open = false

local Player = game:GetService("Players").LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedMods = ReplicatedStorage.Shared

local Gamemodes = require(SharedMods.Constants.Gamemodes)
local GameplayPhases = require(SharedMods.Constants.Enums.GameplayPhases)
local GameStateLibrary = require(SharedMods.Library.GameStateLibrary)
local SimpleRemotes = require(SharedMods.Networking.SimpleRemotes)

--[[local Gui = script:WaitForChild("ItemAcquired") :: ScreenGui
Gui.ResetOnSpawn = false
Gui.IgnoreGuiInset = true]]

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function ItemAcquiredGui.open()
	--ItemAcquiredGui.Open = true
	--Gui.Enabled = true
end

function ItemAcquiredGui.close(_instant: boolean?)
	--ItemAcquiredGui.Open = false
	--Gui.Enabled = false
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

local function _init()
	--Gui.Parent = Player.PlayerGui
	--Gui.Enabled = false
end
_init()

function ItemAcquiredGui.start()
end

return ItemAcquiredGui
