-- AFK state per player, stored in the player's "AFK" attribute so every client can see it.
-- Players set it through the HUD toggle (Remotes.SetAfk); round code should only pick from Afk.activePlayers().

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local Afk = {}

Afk.ATTRIBUTE = "AFK"

function Afk.isAfk(player: Player): boolean
	return player:GetAttribute(Afk.ATTRIBUTE) == true
end

-- Server-side override, e.g. to clear AFK. The player's toggle follows the attribute.
function Afk.set(player: Player, isAfk: boolean)
	player:SetAttribute(Afk.ATTRIBUTE, isAfk)
end

-- Players who should be placed into the next round.
function Afk.activePlayers(): { Player }
	local active = {}
	for _, player in Players:GetPlayers() do
		if not Afk.isAfk(player) then
			table.insert(active, player)
		end
	end
	return active
end

function Afk.start()
	local function init(player: Player)
		if player:GetAttribute(Afk.ATTRIBUTE) == nil then
			Afk.set(player, false)
		end
	end
	Players.PlayerAdded:Connect(init)
	for _, player in Players:GetPlayers() do
		init(player)
	end

	Remotes.event(Remotes.SetAfk).OnServerEvent:Connect(function(player: Player, isAfk: unknown)
		-- Remote arguments come from the client; accept only a plain boolean.
		if typeof(isAfk) ~= "boolean" then
			return
		end
		Afk.set(player, isAfk)
	end)
end

return Afk
