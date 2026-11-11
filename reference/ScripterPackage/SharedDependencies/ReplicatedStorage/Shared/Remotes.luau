-- Named RemoteEvents in ReplicatedStorage.Remotes. The server creates them; clients wait for them.
--
-- local setAfk = Remotes.event(Remotes.SetAfk)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

-- Event names, so client and server can't drift apart.
Remotes.SetAfk = "SetAfk" -- client -> server: (isAfk: boolean)
Remotes.Equip = "Equip" -- client -> server: (categoryId: string, itemId: string), see Shared.Cosmetics
Remotes.ClaimQuest = "ClaimQuest" -- client -> server: (questId: string), see Shared.QuestData
Remotes.KillEffect = "KillEffect" -- server -> all clients: (character: Model, effect: string), see Client.KillEffects
Remotes.Taunt = "Taunt" -- client -> server: () play my equipped taunt; see Server.Taunts
Remotes.PlayTaunt = "PlayTaunt" -- server -> all clients: (character: Model, taunt: string, skinId: string), see Client.Taunts

local FOLDER = "Remotes"

function Remotes.event(name: string): RemoteEvent
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = FOLDER
			folder.Parent = ReplicatedStorage
		end
		local remote = folder:FindFirstChild(name)
		if not remote then
			remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
		return remote :: RemoteEvent
	end
	return ReplicatedStorage:WaitForChild(FOLDER):WaitForChild(name) :: RemoteEvent
end

return Remotes
