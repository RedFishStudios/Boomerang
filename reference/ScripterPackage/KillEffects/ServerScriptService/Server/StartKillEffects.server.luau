--@script:server
-- Starts Server.KillEffects: on every death, picks the killer's equipped kill effect and tells every client to play it
-- (Remotes.KillEffect).
local KillEffects = require(script.Parent:WaitForChild("KillEffects"))

KillEffects.start()
