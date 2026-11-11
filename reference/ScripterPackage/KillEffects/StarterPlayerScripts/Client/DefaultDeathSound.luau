-- Silences Roblox's built-in death sound for every character, on every life.
--
-- Roblox's default RbxCharacterSounds script (which Studio always restores, so it can't be forked) gives each
-- character's HumanoidRootPart a set of sounds, one of them named "Died", and plays it when the Humanoid dies. This
-- empties that one sound the moment the default script creates it (one DescendantAdded hook per character, no
-- polling), so it never has any audio to play. Footsteps, jumping, landing, climbing, swimming and falling sounds are
-- untouched, and kill effects play their own audio; a death with no custom audio is silent.

local Players = game:GetService("Players")

local DefaultDeathSound = {}

local function silence(inst: Instance)
	if inst.Name ~= "Died" then
		return
	end
	if inst:IsA("Sound") then
		inst.Volume = 0
		inst.SoundId = ""
	elseif inst:IsA("AudioPlayer") then
		inst.Volume = 0
		inst.Asset = ""
	end
end

local function watchCharacter(character: Model)
	character.DescendantAdded:Connect(silence)
	for _, d in character:GetDescendants() do
		silence(d)
	end
end

local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		watchCharacter(player.Character)
	end
end

function DefaultDeathSound.start()
	Players.PlayerAdded:Connect(watchPlayer)
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
end

return DefaultDeathSound
