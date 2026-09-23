local DailyClaimsGui = {}
DailyClaimsGui.Type = "HUD"
DailyClaimsGui.Open = false

local player = game:GetService("Players").LocalPlayer

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedMods = ReplicatedStorage.Shared
local ClientMods = ReplicatedStorage.Client
local Items = require(SharedMods.Referential.Items)
local DailyRewards = require(SharedMods.Referential.DailyRewards)
local PlayerDataController = require(ClientMods.Core.PlayerDataController)

local SECONDS_IN_DAY = 86400

local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local claimRemoteFunction = SimpleRemotes.getFunction("ClaimDailyReward")

local Gui: ScreenGui? = script:WaitForChild("DailyClaims")
local DayFrames: {Frame} = {}

local SessionConnections: {RBXScriptConnection} = {}

local container = Gui:WaitForChild("Container")
local mainContainer = container:WaitForChild("Main")
local gridLayout = mainContainer:WaitForChild("UIGridLayout")

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function updateDayIndicators()
   local playerData = PlayerDataController.get()
   if not playerData then return end
   
   local currentStreak = playerData.DailyRewards.Streak
   local lastClaim = playerData.DailyRewards.LastClaim
   
   -- Determine if the next day is claimable based on time elapsed
   local isClaimable = lastClaim == 0 or (os.time() - lastClaim >= SECONDS_IN_DAY)
   
   -- Calculate visual streak within current cycle (1-7)
   -- Rewards cycle loops back after day 7
   local visualStreak = ((currentStreak - 1) % DailyRewards.MaxStreakDays) + 1
   local nextVisualDay = (visualStreak % DailyRewards.MaxStreakDays) + 1

   for dayNum = 1, DailyRewards.MaxStreakDays do
      local dayFrame = DayFrames[dayNum]
      local claimedLabel = dayFrame:FindFirstChild("Claimed")
      local lockedLabel = dayFrame:FindFirstChild("Locked")
      local claimButton = dayFrame:FindFirstChild("Claim")
      
      if dayNum <= visualStreak then
         claimedLabel.Visible = true
         lockedLabel.Visible = false
         claimButton.Visible = false
      elseif dayNum == nextVisualDay and isClaimable then
         claimedLabel.Visible = false
         lockedLabel.Visible = false
         claimButton.Visible = true
      else
         claimedLabel.Visible = false
         lockedLabel.Visible = true
         claimButton.Visible = false
      end
   end
end

local function claim(day: number)
   local success = claimRemoteFunction:InvokeServer()
   if success then
      updateDayIndicators()
   end
end

local function setSizings()
   -- For 3 columns and 2 rows with equal padding
   local containerWidth = mainContainer.AbsoluteSize.X
   local containerHeight = mainContainer.AbsoluteSize.Y
   
   -- Number of items in grid
   local numCols = 3
   local numRows = 2
   local padding = 5 -- pixels
   
   -- Calculate cell dimensions (converting to UDim2)
   -- We use scale values for responsive sizing
   local cellWidthScale = (1 - (padding * numCols / containerWidth)) / numCols
   local cellHeightScale = (1 - (padding * numRows / containerHeight)) / numRows
   
   gridLayout.CellSize = UDim2.new(cellWidthScale, 0, cellHeightScale, 0)
   gridLayout.CellPadding = UDim2.new(0, padding, 0, padding)
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function DailyClaimsGui.open()
   setSizings()
   updateDayIndicators()

   table.insert(SessionConnections, workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(setSizings))

   Gui.Enabled = true
   DailyClaimsGui.Open = true
end

function DailyClaimsGui.close()
   Gui.Enabled = false
   DailyClaimsGui.Open = false

   for _, conn in ipairs(SessionConnections) do
      conn:Disconnect()
   end
   SessionConnections = {}
end

function DailyClaimsGui.toggle()
   if DailyClaimsGui.Open then
      DailyClaimsGui.close()
   else
      DailyClaimsGui.open()
   end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

local function _init()
   Gui.Enabled = false
   Gui.Parent = player:WaitForChild("PlayerGui")
end

function DailyClaimsGui.start()
   local day1Frame = mainContainer:WaitForChild("Day1")
   
   local function wireDayFrame(dayFrame, dayNum)
      DayFrames[dayNum] = dayFrame

      dayFrame:FindFirstChild("Claim").MouseButton1Click:Connect(function()
         claim(dayNum)
      end)

      -- Get reward info and update ItemLabel
      local reward = DailyRewards.Rewards[dayNum]
      local itemLabel = dayFrame:FindFirstChild("ItemLabel")
      if reward then
         if reward.Type == "Currency" then
            itemLabel.Text = tostring(reward.Value)
         elseif reward.Type == "Item" then
            local itemData = Items[reward.Value]
            if itemData then
               itemLabel.Text = itemData.Name or reward.Value
            else
               itemLabel.Text = reward.Value
            end
         end
      end

      -- Get day label and update its text
      local playerData = PlayerDataController.get()
      local currentStreak = playerData.DailyRewards.Streak
      local lastClaim = playerData.DailyRewards.LastClaim
      local isClaimable = lastClaim == 0 or (os.time() - lastClaim >= SECONDS_IN_DAY)
      
      -- Calculate visual streak within current cycle (1-7)
      local visualStreak = ((currentStreak - 1) % DailyRewards.MaxStreakDays) + 1
      local nextVisualDay = (visualStreak % DailyRewards.MaxStreakDays) + 1
      
      local dayLabel = dayFrame:FindFirstChild("DayLabel")
      if dayNum == nextVisualDay and isClaimable then
         dayLabel.Text = "Today"
      else
         dayLabel.Text = `Day {dayNum}`
      end
   end

   -- Create or update all 7 day frames
   for dayNum = 1, DailyRewards.MaxStreakDays-1 do
      local dayFrame
      
      if dayNum == 1 then
         dayFrame = day1Frame
      else
         -- Duplicate Day1 frame
         dayFrame = day1Frame:Clone()
         dayFrame.Name = `Day{dayNum}`
         dayFrame.Parent = mainContainer
      end
      
      wireDayFrame(dayFrame, dayNum)
   end

   wireDayFrame(container:WaitForChild("Day" .. DailyRewards.MaxStreakDays), DailyRewards.MaxStreakDays)

   if game:GetService("RunService"):IsStudio() then
      game:GetService("ContextActionService"):BindAction("testopendailyclaimsmenu", function(_, inputState)
         if inputState == Enum.UserInputState.Begin then
            DailyClaimsGui.toggle()
         end
      end, false, Enum.KeyCode.Y)
   else
      local playerData = PlayerDataController.get()
      local lastClaim = playerData.DailyRewards.LastClaim
      local isClaimable = lastClaim == 0 or (os.time() - lastClaim >= SECONDS_IN_DAY)
      if isClaimable then
         DailyClaimsGui.open()
      end
   end
end

_init()

return DailyClaimsGui