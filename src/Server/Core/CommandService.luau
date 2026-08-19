
local CommandService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local function createCommand(name: string, primaryAlias: string?, secondaryAlias: string?, callback: (player: Player, args: {string}) -> ())
   local CommandInstance = Instance.new("TextChatCommand")
   CommandInstance.Parent = TextChatService
   CommandInstance.Name = name
   CommandInstance.PrimaryAlias = primaryAlias
   if secondaryAlias then
      CommandInstance.SecondaryAlias = secondaryAlias
   end
   CommandInstance.Triggered:Connect(function(textSource: TextSource, text: string)
      local player = Players:GetPlayerByUserId(textSource.UserId)
      if not player then
         warn(`CommandService: No player found for TextSource userId {textSource.UserId}`)
         return
      end
      local args = string.split(text, " ")
      table.remove(args, 1)
      callback(player, args)
   end)
end

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function CommandService.addCommand(name: string, primaryAlias: string?, secondaryAlias: string?, callback: (player: Player, args: {string}) -> ())
   createCommand(name, primaryAlias, secondaryAlias, callback)
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function CommandService.init()
end

return CommandService