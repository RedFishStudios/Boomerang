local DailyClaimsGui = {}
DailyClaimsGui.Type = "HUD"
DailyClaimsGui.Open = false
DailyClaimsGui.RequiresMouse = true -- // Clickable menu: frees the mouse in the locked camera (MouseUnlockController)

local player = game:GetService("Players").LocalPlayer

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedMods = ReplicatedStorage.Shared
local ClientMods = ReplicatedStorage.Client
local Items = require(SharedMods.Referential.Items)
local DailyRewards = require(SharedMods.Referential.DailyRewards)
local Skins = require(SharedMods.Referential.Skins)
local PlayerDataController = require(ClientMods.Core.PlayerDataController)
local ItemAcquiredGui = require(ClientMods.UI.Gui.ItemAcquired)

local SECONDS_IN_DAY = 86400

local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local claimRemoteFunction = SimpleRemotes.getFunction("ClaimDailyReward")

local Gui: ScreenGui? = script:WaitForChild("DailyClaims")
local DayFrames: {GuiObject} = {}

local SessionConnections: {RBXScriptConnection} = {}

local container = Gui:WaitForChild("Container")
local content = container:WaitForChild("Content")
local mainContainer = content:WaitForChild("Main")
local streakNumber: TextLabel = container:WaitForChild("StreakNumber")

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-- Returns days claimed in the current cycle (0-7), the next claimable day, and whether it can be claimed now
local function getStreakState(playerData)
   local currentStreak = playerData.DailyRewards.Streak
   local lastClaim = playerData.DailyRewards.LastClaim
   local isClaimable = lastClaim == 0 or (os.time() - lastClaim >= SECONDS_IN_DAY)

   -- Server wraps back to day 1 after the final day is claimed
   local visualStreak = currentStreak
   if isClaimable and currentStreak >= DailyRewards.MaxStreakDays then
      visualStreak = 0
   end

   return visualStreak, visualStreak + 1, isClaimable
end

local function updateDayIndicators()
   local playerData = PlayerDataController.get()
   if not playerData then return end

   local visualStreak, nextVisualDay, isClaimable = getStreakState(playerData)

   -- // The day the player is on: the claimable day, or the day already claimed today
   streakNumber.Text = tostring(if isClaimable then nextVisualDay else math.max(visualStreak, 1))

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

-- // Item and skin rewards are announced by ShopController / SkinController (ItemAcquired), so only currency is shown here.
-- // A skin the player already owned was converted to its FallbackCurrency.
local function notifyReward(claimedDay: number, convertedToCurrency: boolean)
   local reward = DailyRewards.Rewards[claimedDay]
   if reward and reward.Type == "Currency" then
      ItemAcquiredGui.acquiredCustomItem(nil, "Daily reward claimed!", `+{reward.Value} Currency`)
   elseif reward and reward.Type == "Skin" and convertedToCurrency then
      ItemAcquiredGui.acquiredCustomItem(nil, "Daily reward claimed!", `+{reward.FallbackCurrency} Currency (skin already owned)`)
   end
end

local function claim(day: number)
   local success, claimedDay, convertedToCurrency = claimRemoteFunction:InvokeServer()
   if success then
      updateDayIndicators()
      if typeof(claimedDay) == "number" then
         notifyReward(claimedDay, convertedToCurrency == true)
      end
   end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function DailyClaimsGui.open()
   updateDayIndicators()

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
         elseif reward.Type == "Skin" then
            local skin = Skins[reward.Value]
            itemLabel.Text = if skin then `{skin.Name} Skin` else reward.Value
         end
      end

      -- Get day label and update its text
      local playerData = PlayerDataController.get()
      local _, nextVisualDay, isClaimable = getStreakState(playerData)

      local dayLabel = dayFrame:FindFirstChild("DayLabel")
      if dayNum == nextVisualDay and isClaimable then
         dayLabel.Text = "Today"
      else
         dayLabel.Text = `Day {dayNum}`
      end
   end

   -- // Days 1-6 are laid out in the .rbxmx; a missing day is cloned from Day1
   for dayNum = 1, DailyRewards.MaxStreakDays-1 do
      local dayFrame = mainContainer:FindFirstChild(`Day{dayNum}`)

      if not dayFrame then
         dayFrame = day1Frame:Clone()
         dayFrame.Name = `Day{dayNum}`
         dayFrame.LayoutOrder = dayNum
         dayFrame.Parent = mainContainer
      end

      wireDayFrame(dayFrame, dayNum)
   end

   wireDayFrame(content:WaitForChild("Day" .. DailyRewards.MaxStreakDays), DailyRewards.MaxStreakDays)

   container:WaitForChild("Exit").MouseButton1Click:Connect(DailyClaimsGui.close)

   -- // The claim's new Streak/LastClaim replicate after the remote returns, so refresh when they arrive
   PlayerDataController.UpdatedTasks:Add(function(_, _, path)
      if path[1] == "DailyRewards" and DailyClaimsGui.Open then
         updateDayIndicators()
      end
   end)

   -- // Opened from the Daily button in MenuButtons (T-037; was a Topbar button, T-055)

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