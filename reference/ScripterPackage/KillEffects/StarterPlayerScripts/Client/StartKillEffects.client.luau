--@localscript
-- Starts the client side of kill effects: silences Roblox's default death sound and plays the kill effect the server
-- announces for each death (Remotes.KillEffect). See Client.KillEffects and Client.DefaultDeathSound.
local DefaultDeathSound = require(script.Parent:WaitForChild("DefaultDeathSound"))
local KillEffects = require(script.Parent:WaitForChild("KillEffects"))

-- First, so a death right after joining is already silent.
DefaultDeathSound.start()
KillEffects.start()
