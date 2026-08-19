--[[
  ChatController

  Description:
  Handles client player data state

  Author:
  @SixthAtom

  Date:
  20-02-2026
]]

local ChatController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local ProfileTemplate = require(ReplicatedStorage.Shared.Data.ProfileTemplate)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local printMessageEvent = SimpleRemotes.getEvent("PrintMessage")

local TextChannels = TextChatService:WaitForChild("TextChannels")
local GeneralChannel: TextChannel = TextChannels:WaitForChild("RBXGeneral")

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------


-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function ChatController.init()
   printMessageEvent.OnClientEvent:Connect(function(message: string, color: string)
      -- Print the message with the color or a default color to the default chat channel
      local chatColor = color or Color3.fromRGB(255, 255, 255):ToHex()
      message = `<font color=\"#{chatColor}\">{message}</font>`
      GeneralChannel:DisplaySystemMessage(message)
   end)
end

function ChatController.start()
end

return ChatController
