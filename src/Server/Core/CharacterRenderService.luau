-- // Manages replication states of player characters

local CharacterRenderService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local GlobalInstanceService = require(ServerStorage.Server.Services.GlobalInstanceService)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local BufferUtil = require(ReplicatedStorage.Shared.Utils.BufferUtil)
local unreliableEvent = SimpleRemotes.getUnreliableEvent("CharacterReplication")

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function CharacterRenderService.init()
end

function CharacterRenderService.start()
end

function CharacterRenderService.test() end

return CharacterRenderService
