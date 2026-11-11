--@script:server
-- Starts Server.Inventory: each player's equipped cosmetics (skin, kill effect, taunt) as player attributes, and the
-- Equip remote the Inventory screen uses. Taunts and kill effects read these attributes.
local Inventory = require(script.Parent:WaitForChild("Inventory"))

Inventory.start()
