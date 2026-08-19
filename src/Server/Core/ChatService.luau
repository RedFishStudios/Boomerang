
local ChatService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")

local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local printMessageEvent = SimpleRemotes.getEvent("PrintMessage")

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function ChatService.tellPlayerPrintMessage(player: Player, message: string, color: Color3?)
   printMessageEvent:FireClient(player, message, color:ToHex())
end

function ChatService.tellAllPlayersPrintMessage(message: string, color: Color3?)
   printMessageEvent:FireAllClients(message, color:ToHex())
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function ChatService.init()
end

return ChatService