local AnticheatService = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local PlayerStatsLibrary = require(
    game:GetService("ReplicatedStorage").Shared.Library.PlayerStatsLibrary
)

local state = {}

local SAMPLE_INTERVAL = 0.1
local SPEED_TOLERANCE = 1.35

local function getState(player)
    local playerState = state[player]

    if not playerState then
        playerState = {
            position = nil,
            accumulator = 0,
            violation = 0,
        }

        state[player] = playerState
    end

    return playerState
end

local function checkPlayer(player, dt)
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local root = character and character:FindFirstChild("HumanoidRootPart")

    if not humanoid or not root then
        return
    end

    local s = getState(player)

    s.accumulator += dt

    -- Don't check every simulation step.
    if s.accumulator < SAMPLE_INTERVAL then
        return
    end

    local elapsed = s.accumulator
    s.accumulator = 0

    local position = root.Position

    if not s.position then
        s.position = position
        return
    end

    local delta = position - s.position
    s.position = position

    -- Only measure horizontal movement.
    local horizontalDistance =
        Vector3.new(delta.X, 0, delta.Z).Magnitude

    local speed = horizontalDistance / elapsed

    local expectedSpeed = PlayerStatsLibrary.getStat(player, "CurrentSpeed") or 16

    local maximumSpeed = expectedSpeed * SPEED_TOLERANCE

    if speed > maximumSpeed then
        s.violation += elapsed
    else
        -- Slowly forgive previous violations.
        s.violation = math.max(0, s.violation - elapsed * 2)
    end

    if s.violation >= 1 then
        warn(
            player.Name,
            "sustained excessive movement",
            "speed:", speed,
            "expected:", expectedSpeed
        )

        PlayerStatsLibrary.setStat(player, "CurrentSpeed", expectedSpeed, nil, nil)

        s.violation = 0
    end
end

function AnticheatService.init()
   if 1==1 then
      --- CURRENTLY DISABLED
      return
   end
    Players.PlayerRemoving:Connect(function(player)
        state[player] = nil
    end)

    RunService.Heartbeat:Connect(function(dt)
        for _, player in Players:GetPlayers() do
            checkPlayer(player, dt)
        end
    end)
end

return AnticheatService