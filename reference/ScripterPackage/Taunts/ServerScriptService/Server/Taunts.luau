-- Taunts: a player asks to play their equipped taunt (Remotes.Taunt, e.g. the T key), the server checks it and tells
-- every client to play it on that character (Remotes.PlayTaunt); Client.Taunts animates it locally on each client, so
-- it's smooth for everyone, the same way kill effects work.
--
-- While a taunt plays (Taunts.DURATION) the character stays planted where it stood: no walking, jumping or turning.
-- One taunt at a time per player.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Taunts = {}

Taunts.DURATION = 6

local busyUntil: { [Player]: number } = {}

-- Plays `player`'s equipped taunt now. Returns false if they can't taunt right now.
function Taunts.play(player: Player): boolean
	local now = os.clock()
	if (busyUntil[player] or 0) > now then
		return false
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not (character and humanoid and root) or humanoid.Health <= 0 then
		return false
	end
	if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return false
	end
	local tauntCategory = Cosmetics.byId.Taunts
	local item = tauntCategory.byId[player:GetAttribute(tauntCategory.attribute) or tauntCategory.default]
	if not item or not item.taunt then
		return false
	end
	local skinCategory = Cosmetics.byId.Skins
	local skinId = player:GetAttribute(skinCategory.attribute) or skinCategory.default

	busyUntil[player] = now + Taunts.DURATION
	-- Keep the feet planted at the spot it started.
	local walkSpeed, jumpHeight, jumpPower, autoRotate =
		humanoid.WalkSpeed, humanoid.JumpHeight, humanoid.JumpPower, humanoid.AutoRotate
	humanoid.WalkSpeed, humanoid.JumpHeight, humanoid.JumpPower, humanoid.AutoRotate = 0, 0, 0, false
	root.AssemblyLinearVelocity = Vector3.zero
	character:SetAttribute("Taunting", item.taunt)

	Remotes.event(Remotes.PlayTaunt):FireAllClients(character, item.taunt, skinId)

	task.delay(Taunts.DURATION, function()
		if humanoid.Parent then
			humanoid.WalkSpeed, humanoid.JumpHeight, humanoid.JumpPower, humanoid.AutoRotate =
				walkSpeed, jumpHeight, jumpPower, autoRotate
		end
		if character.Parent then
			character:SetAttribute("Taunting", nil)
		end
	end)
	return true
end

function Taunts.start()
	Remotes.event(Remotes.PlayTaunt) -- create the remote before clients ask for it
	Remotes.event(Remotes.Taunt).OnServerEvent:Connect(function(player: Player)
		Taunts.play(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		busyUntil[player] = nil
	end)
end

return Taunts
