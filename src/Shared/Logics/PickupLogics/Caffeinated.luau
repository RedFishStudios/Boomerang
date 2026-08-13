local Caffeinated = {}

local RunService = game:GetService("RunService")

local GlobalConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Constants"):WaitForChild("GlobalConfig"))

local isServer = RunService:IsServer()

local TIME_LASTS = 5

function Caffeinated.onPickup(player: Player, startedAt: number?)
   local endsAt = (startedAt or workspace:GetServerTimeNow()) + TIME_LASTS
   if isServer then
      -- Server context
      local character = player.Character
      if character then
         -- TODO: Do something so that this doesn't affect Dash. ie use a player stats table instead of setting walkspeed directly.
         -- Refer to PlayerStatService and the system it has set up there so far.
         local humanoid = character:FindFirstChildOfClass("Humanoid")
         if humanoid then
            humanoid.WalkSpeed = GlobalConfig.DefaultWalkSpeed * 2
            task.delay(TIME_LASTS, function()
               if humanoid then
                  humanoid.WalkSpeed = GlobalConfig.DefaultWalkSpeed
               end
            end)
         end
      end
   else
      -- Client context
      -- Maybe a sound, gui etc
   end

   return true, endsAt
end

function Caffeinated.simulateActivation(userId: number, activationTime: number)
   -- Client context
   local player = game:GetService("Players"):GetPlayerByUserId(userId)
   if player then
      Caffeinated.onPickup(player, activationTime)
   end
end

return Caffeinated