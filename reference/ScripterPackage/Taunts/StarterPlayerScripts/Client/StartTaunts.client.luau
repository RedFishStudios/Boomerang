--@localscript
-- Starts the client side of taunts: plays the taunts the server announces (Remotes.PlayTaunt) on every character and
-- binds the Taunt key (T / gamepad Y, plus an on-screen button on touch devices). See Client.Taunts.
local Taunts = require(script.Parent:WaitForChild("Taunts"))

Taunts.start()
