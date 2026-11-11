--!strict
-- EXAMPLE (disabled LocalScript): how to connect FanTrails to the real weapon system. Adapt and enable it.
--
-- Assumes the weapon code gives each thrown fan's model (or part) a "FanState" attribute:
--   "Flying"    - left the hand (outward) or coming back (return): the trail runs
--   "Caught"    - back in the hand: the trail stops and fades
--   "Landed"    - stopped / hit the ground: the trail stops and fades
--   "Teleport"  - moved instantly (reset, respawn, knock-back snap): the trail clears at once and carries on
-- and that the model is named after the fan (BambooFan, SunsetFan, Surge, SakuraFan, MoonsongFan, SunfireFan), or has
-- a "FanTrail" attribute naming the style (Bamboo, SunsetPop, TidalSurge, SakuraDrift, Moonsong, SunfirePhoenix).
-- Set "FanState" before parenting the projectile into the Workspace. Run this on every client so everyone sees
-- everyone's trails; trails are purely visual (no collisions, no hitbox changes).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local FanTrails = require(ReplicatedStorage:WaitForChild("FanTrails"))

local trails: { [Instance]: any } = {}

local function attach(fan: Instance)
	if trails[fan] then
		return
	end
	local style = fan:GetAttribute("FanTrail") :: string? or FanTrails.StyleForFan[fan.Name]
	if not style then
		return
	end
	local trail = FanTrails.new(fan, style)
	trails[fan] = trail

	local function apply()
		local state = fan:GetAttribute("FanState")
		if state == "Flying" then
			trail:Start()
		elseif state == "Caught" or state == "Landed" then
			trail:Stop()
		elseif state == "Teleport" then
			trail:Reset()
		end
	end
	fan:GetAttributeChangedSignal("FanState"):Connect(apply)
	apply()

	-- When the projectile is removed: let what's left fade, then free the trail.
	fan.AncestryChanged:Connect(function(_, parent)
		if parent == nil and trails[fan] then
			trails[fan] = nil
			trail:Stop()
			task.delay(trail.style.FadeTime + 1.2, function()
				trail:Destroy()
			end)
		end
	end)
end

for _, d in Workspace:GetDescendants() do
	if d:GetAttribute("FanState") ~= nil then
		attach(d)
	end
end
Workspace.DescendantAdded:Connect(function(d)
	if d:GetAttribute("FanState") ~= nil then
		attach(d)
	end
end)
