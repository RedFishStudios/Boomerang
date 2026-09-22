local ShopGui = {}
ShopGui.Type = "HUD"
ShopGui.Open = false

local player = game:GetService("Players").LocalPlayer

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HttpService = game:GetService("HttpService")
local SharedMods = ReplicatedStorage.Shared
local ShopItems = require(SharedMods.Referential.ShopItems)
local Items = require(SharedMods.Referential.Items)
local MarketplaceLibrary = require(SharedMods.Library.MarketplaceLibrary)
local PolicyLibrary = require(SharedMods.Library.PolicyLibrary)

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

local function loadTabButtons()
   clearTabButtons()
   
   if not TabButtons then return end
   
   -- Collect tabs in order
   local tabList = {}
   for tabName, tab in pairs(ShopItems.Tabs) do
      table.insert(tabList, { name = tabName, tab = tab, order = tab.Order or 0 })
   end
   table.sort(tabList, function(a, b) return a.order < b.order end)
   
   -- Create tab buttons
   local isFirstTab = true
   for _, tabEntry in ipairs(tabList) do
      local tabName = tabEntry.name
      local tab = tabEntry.tab
      
      local template = script:FindFirstChild("TabButtonTemplate")
      if not template then
         warn("TabButtonTemplate not found")
         continue
      end
      
      local tabButton = template:Clone()
      tabButton.Name = tabName
      tabButton.Text = tab.Name
      tabButton.BackgroundColor3 = isFirstTab 
         and Color3.fromRGB(255, 200, 100)
         or Color3.fromRGB(220, 200, 175)
      
      tabButton.MouseButton1Click:Connect(function()
         onTabButtonClicked(tabName)
      end)
      
      tabButton.Parent = TabButtons
      table.insert(CurrentTabButtons, tabButton)
      
      if isFirstTab and tab.AutoSelect then
         loadTab(tab)
         isFirstTab = false
      end
   end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function ShopGui.open()
   if not ShopScreenGui then
      return
   end
   
   lastTabChangeId = HttpService:GenerateGUID(false)
   ShopScreenGui.Enabled = true
   ShopGui.Open = true
   loadTabButtons()
end

function ShopGui.close()
   if not ShopScreenGui then
      return
   end
   
   ShopScreenGui.Enabled = false
   ShopGui.Open = false
   clearTabButtons()
   clearItemListings()
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
   
   local container = ShopScreenGui:FindFirstChild("Container")
   if not container then
      warn("Container not found in Shop ScreenGui")
      return
   end
   
   TabButtons = container:FindFirstChild("TabButtons")
   Content = container:FindFirstChild("Content")
   
   if not TabButtons or not Content then
      warn("TabButtons or Content not found in Container")
      return
   end
   
   -- Wire close button
   local closeButton = container:FindFirstChild("Close")
   if closeButton then
      closeButton.MouseButton1Click:Connect(function()
         ShopGui.close()
      end)
   end
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