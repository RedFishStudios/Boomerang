local ShopGui = {}
ShopGui.Type = "HUD"
ShopGui.Open = false

local player = game:GetService("Players").LocalPlayer

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HttpService = game:GetService("HttpService")
local SharedMods = ReplicatedStorage.Shared
local ClientMods = ReplicatedStorage.Client
local ShopItems = require(SharedMods.Referential.ShopItems)
local Items = require(SharedMods.Referential.Items)
local MarketplaceLibrary = require(SharedMods.Library.MarketplaceLibrary)
local PolicyLibrary = require(SharedMods.Library.PolicyLibrary)
local TweenService = game:GetService("TweenService")
local UIController = require(ClientMods.UI.UIController)

local ShopScreenGui: ScreenGui? = script:WaitForChild("Shop")
local TabButtons: Frame?
local Content: ScrollingFrame?
local CurrentTab: ShopItems.ShopTab?
local CurrentTabButtons: {TextButton} = {}
local CurrentListings: {Frame} = {}

local itemTypeToDisplay: {
   [Items.ItemType]: string
} = {
   Skin = "Weapon Skin",
   Weapon = "New Weapon"
}

local lastTabChangeId: string? = nil

local TabButtonSelected = 115399445238387
local TabButton = 77349291529962

local BUTTON_WIDTH = 0.23
local BUTTON_PADDING = 0.03
local BUTTON_TOTAL_WIDTH = BUTTON_WIDTH + BUTTON_PADDING
local ACTION_BUTTON_HOVER_SCALE = 1.05
local ACTION_BUTTON_HOVER_TILT = 3
local ACTION_BUTTON_HOVER_TWEEN_INFO = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Animation values
local Container: Frame?
local containerGoalPosition: UDim2?
local containerOffscreenPosition: UDim2?
local CONTAINER_TWEEN_INFO_IN = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local CONTAINER_TWEEN_INFO_OUT = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In)
local activeTween: Tween?

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function clearItemListings()
   for _, listing in ipairs(CurrentListings) do
      listing:Destroy()
   end
   CurrentListings = {}
end

local function clearTabButtons()
   for _, button in ipairs(CurrentTabButtons) do
      button:Destroy()
   end
   CurrentTabButtons = {}
end

local function setupActionButtonHover(button: GuiButton)
   local defaultSize = button.Size
   local defaultRotation = button.Rotation
   local hoverSize = UDim2.new(
      defaultSize.X.Scale * ACTION_BUTTON_HOVER_SCALE,
      defaultSize.X.Offset * ACTION_BUTTON_HOVER_SCALE,
      defaultSize.Y.Scale * ACTION_BUTTON_HOVER_SCALE,
      defaultSize.Y.Offset * ACTION_BUTTON_HOVER_SCALE
   )
   local activeHoverTween: Tween?

   local function tweenTo(size: UDim2, rotation: number)
      if activeHoverTween then
         activeHoverTween:Cancel()
      end
      activeHoverTween = TweenService:Create(button, ACTION_BUTTON_HOVER_TWEEN_INFO, {
         Size = size,
         Rotation = rotation,
      })
      activeHoverTween:Play()
   end

   button.MouseEnter:Connect(function()
      tweenTo(hoverSize, defaultRotation + ACTION_BUTTON_HOVER_TILT)
   end)

   button.MouseLeave:Connect(function()
      tweenTo(defaultSize, defaultRotation)
   end)
end

local function loadTab(tab: ShopItems.ShopTab)
   CurrentTab = tab
   clearItemListings()
   lastTabChangeId = HttpService:GenerateGUID(false)
   local thisTabChangeId = lastTabChangeId
   
   for _, itemId in ipairs(tab.Items) do
      local itemData = Items[itemId]
      if itemData and not itemData.OffSale then
         -- Check regional law restrictions
         if itemData.IsPaidRandomItem then
            local canAcquire = not PolicyLibrary.arePaidRandomItemsRestricted(game.Players.LocalPlayer)
            if not canAcquire then
               continue
            end
         end

         -- Create listing template
         local template = script:FindFirstChild("ItemListingTemplate")
         if not template then
            warn("ItemListingTemplate not found")
            continue
         end
         local listing = template:Clone()
         listing.Name = itemId
         
         listing.ItemName.Text = itemData.Name
         listing.ItemType.Text = itemTypeToDisplay[itemData.Type] or "type error"

         -- Toggle gifting based on regional law restrictions
         listing.Robux.Gift.Visible = false
         listing.Currency.Gift.Visible = false
         if PolicyLibrary.isPaidItemTradingAllowed(game.Players.LocalPlayer) then
            listing.Robux.Gift.Visible = true
            listing.Currency.Gift.Visible = true
         end
         
         -- Display robux price based on availability and regional law restrictions
         local productId = itemData.ProductId
         if productId then
            listing.Robux.Visible = true
            listing.Robux.PriceText.Text = "..."
            task.spawn(function()
               local productPrice = MarketplaceLibrary.getProductPrice(productId)
               if productPrice and lastTabChangeId == thisTabChangeId then 
                  local clientCanPurchaseItem = MarketplaceLibrary.playerCanPurchaseItem(game.Players.LocalPlayer, productId)
                  if clientCanPurchaseItem then
                     listing.Robux.PriceText.Text = productPrice
                  end
               end
            end)
         else
            listing.Robux.Visible = false
         end

         listing.Currency.PriceText.Text = itemData.Price
         setupActionButtonHover(listing.Currency)
         setupActionButtonHover(listing.Robux)
  
         listing.Parent = Content
         table.insert(CurrentListings, listing)
      end
   end
end

local function onTabButtonClicked(tabName: string)
   local tab = ShopItems.Tabs[tabName]
   if tab then
      loadTab(tab)
      
      -- Update button appearances
      for _, button in ipairs(CurrentTabButtons) do
         button.BackgroundColor3 = button.Name == tabName 
            and Color3.fromRGB(255, 200, 100)
            or Color3.fromRGB(220, 200, 175)
      end
   end
end

local function setupTabButtonHover(button: ImageButton)
	button.MouseEnter:Connect(function()
		button.Image = "rbxassetid://" .. TabButtonSelected
	end)

	button.MouseLeave:Connect(function()
		button.Image = "rbxassetid://" .. TabButton
	end)
end

local function playContainerTween(tweenInfo: TweenInfo, goalPosition: UDim2)
	if activeTween then
		activeTween:Cancel()
	end
	activeTween = TweenService:Create(Container, tweenInfo, { Position = goalPosition })
	activeTween:Play()
end

local function loadTabButtons()
   clearTabButtons()
   
   -- Collect tabs in order
   local tabList = {}
   for tabName, tab in pairs(ShopItems.Tabs) do
      table.insert(tabList, { name = tabName, tab = tab, order = tab.Order or 0 })
   end
   table.sort(tabList, function(a, b) return a.order < b.order end)
   
   -- Create tab buttons
   local buttonIndex = 0
   for _, tabEntry in ipairs(tabList) do
      local tabName = tabEntry.name
      local tab = tabEntry.tab
      
      local template = script:WaitForChild("TabButtonTemplate")
      local tabButton = template:Clone()
      tabButton.Name = tabName
      tabButton.TextLabel.Text = tab.Name
      
      -- Manually position button based on index
      local xOffset = buttonIndex * BUTTON_TOTAL_WIDTH
      tabButton.Position = UDim2.new(xOffset, 0, 1, 0)
      
      tabButton.MouseButton1Click:Connect(function()
         onTabButtonClicked(tabName)
      end)
      
      setupTabButtonHover(tabButton)
      
      tabButton.Parent = TabButtons
      table.insert(CurrentTabButtons, tabButton)
      
      if buttonIndex == 0 and tab.AutoSelect then
         loadTab(tab)
      end
      
      buttonIndex = buttonIndex + 1
   end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function ShopGui.open()
   if not ShopScreenGui then
      return
   end
   
   ShopGui.Open = true
   ShopScreenGui.Enabled = true
   Container.Position = containerOffscreenPosition
   loadTabButtons()
   playContainerTween(CONTAINER_TWEEN_INFO_IN, containerGoalPosition)
   UIController.supercede("Shop", "GamemodeHud")
   
end

function ShopGui.close()
   if not ShopScreenGui then
      return
   end
   lastTabChangeId = HttpService:GenerateGUID(false)
   
   ShopGui.Open = false
   playContainerTween(CONTAINER_TWEEN_INFO_OUT, containerOffscreenPosition)
   clearTabButtons()
   clearItemListings()
   UIController.unSupercede("Shop", "GamemodeHud")
   
   task.spawn(function()
      task.wait(0.4)
      if not ShopGui.Open then
         ShopScreenGui.Enabled = false
      end
   end)
end

function ShopGui.toggleSaleIndicator(itemId: string, show: boolean)
   if not Content then return end

   local itemListing = Content:FindFirstChild(itemId)
   if itemListing then
      local saleIndicator = itemListing:FindFirstChild("SaleIndicator")
      if saleIndicator then
         saleIndicator.Visible = show
      end
   end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

local function _init()
   ShopScreenGui.Enabled = false
   ShopScreenGui.Parent = player:WaitForChild("PlayerGui")
   
   Container = ShopScreenGui:WaitForChild("Container")
   local imageLabel = Container:WaitForChild("ImageLabel")
   
   TabButtons = Container:WaitForChild("TabButtons")
   Content = imageLabel:WaitForChild("ListingsContent")
   
   -- Set up animation values
   containerGoalPosition = Container.Position
   containerOffscreenPosition = containerGoalPosition - UDim2.fromScale(0, 1)
   
   -- Wire close button
   local exitButton = imageLabel:WaitForChild("Exit")
   setupActionButtonHover(exitButton)
   exitButton.MouseButton1Click:Connect(function()
      warn(`exit click`)
      ShopGui.close()
   end)
end

function ShopGui.start()
   game:GetService("ContextActionService"):BindAction("testacquireitemnotif", function(_, inputState)
      if inputState == Enum.UserInputState.Begin then
          ShopGui.open()
      end
   end, false, Enum.KeyCode.B)
end

_init()

return ShopGui