
local CommandService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-- // T-016: chat commands are obsolete. They had no permission check, so any player in a live server could use them.
-- // Every command now lives in Cmdr (F2), which is permission-checked by CmdrService: see Server/Cmdr/Commands.
-- // This switch stays off; the old addCommand blocks in RoundCyclingService and PickupService are kept only as a reference.
local CHAT_COMMANDS_ENABLED = false

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
   if not CHAT_COMMANDS_ENABLED then
      return
   end
   createCommand(name, primaryAlias, secondaryAlias, callback)
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function CommandService.init()
end

return CommandService