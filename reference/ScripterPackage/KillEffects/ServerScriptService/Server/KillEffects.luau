-- Decides which kill effect plays when a character dies and tells every client to play it (Client.KillEffects
-- renders it locally, so tweens and particles are smooth).
--
-- The effect is the killer's equipped Kill Effect. Combat code marks the killer the classic Roblox way: an ObjectValue
-- named "creator" under the victim's Humanoid whose Value is the killing Player. Without one (falls, resets, tests)
-- the victim's own equipped effect is used.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local KillEffects = {}

local category = Cosmetics.byId.KillEffects

-- The effect name ("Stone", "Ashes") for a death, or nil for a plain death.
function KillEffects.effectFor(victim: Player?, humanoid: Humanoid): string?
	local creator = humanoid:FindFirstChild("creator")
	local killer = if creator
			and creator:IsA("ObjectValue")
			and creator.Value
			and creator.Value:IsA("Player")
		then creator.Value :: Player
		else victim
	if not killer then
		return nil
	end
	local item = category.byId[killer:GetAttribute(category.attribute) or category.default]
	return item and item.effect
end

-- Plays `effect` on any character (handy for testing and NPCs).
function KillEffects.play(character: Model, effect: string)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		-- Pin the body where it died; the clients replace it with the effect's copy.
		root.Anchored = true
	end
	Remotes.event(Remotes.KillEffect):FireAllClients(character, effect)
end

local function watch(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	-- Keep the body in one piece on death so the effects can freeze its exact pose.
	humanoid.BreakJointsOnDeath = false
	humanoid.Died:Once(function()
		local effect = KillEffects.effectFor(player, humanoid)
		if effect then
			KillEffects.play(character, effect)
		end
	end)
end

function KillEffects.start()
	Remotes.event(Remotes.KillEffect) -- create the remote before clients ask for it
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			watch(player, character)
		end)
		if player.Character then
			task.spawn(watch, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return KillEffects
