--@script:server
-- Starts Server.Taunts: validates taunt requests (Remotes.Taunt), plants the character for 6 s and tells every client
-- to play the taunt (Remotes.PlayTaunt).
local Taunts = require(script.Parent:WaitForChild("Taunts"))

Taunts.start()
