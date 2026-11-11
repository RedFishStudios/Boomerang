-- Plays kill effects the server announces (Server.KillEffects). Each client renders its own copy, so it's smooth
-- for everyone.
--
-- Every ModuleScript in this folder except the helpers (Fx, Rig) is an effect, named as in Shared.Cosmetics' `effect`
-- field: Stone, Ashes, Sakura, Shark. To add one, drop a new module here; this file doesn't need editing (handy, as
-- Lync doesn't always resync edits to a folder's Init.luau).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local KillEffects = {}

local HELPERS = { Fx = true, Rig = true }

local EFFECTS: { [string]: (Model, Instance) -> () } = {}
for _, child in script:GetChildren() do
	if child:IsA("ModuleScript") and not HELPERS[child.Name] then
		EFFECTS[child.Name] = require(child) :: any
	end
end

local folder: Folder

function KillEffects.play(character: Model, effect: string)
	local run = EFFECTS[effect]
	if not run then
		warn(`[KillEffects] unknown effect "{effect}"`)
		return
	end
	if character and character.Parent then
		task.spawn(run, character, folder)
	end
end

-- Downloads every kill-effect texture and sound in the background, so the first death already shows the flames,
-- petals, splashes... instead of blank white sprites while they load.
local function preload()
	local Assets = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Assets"))
	-- The sound entries of Assets.KillFx (everything else there is an image). Sounds are preloaded as Sound objects;
	-- passing a sound id as a plain string makes ContentProvider try to load it as an image.
	local SOUNDS = {
		Swoosh = true,
		FireSwoosh = true,
		StoneGrind = true,
		StoneClunk = true,
		StoneCrumble = true,
		FireCrackle = true,
		AshCollapse = true,
		AirySwoosh = true,
		FireRoar = true,
		Gulp = true,
		Rumble = true,
		SplashBig = true,
		SplashSmall = true,
		Chomp = true,
	}
	local list: { any } = {}
	for key, value in Assets.KillFx do
		if typeof(value) == "string" and string.find(value, "rbxassetid://", 1, true) then
			if SOUNDS[key] then
				local sound = Instance.new("Sound")
				sound.SoundId = value
				table.insert(list, sound)
			else
				table.insert(list, value)
			end
		end
	end
	pcall(function()
		game:GetService("ContentProvider"):PreloadAsync(list)
	end)
end

function KillEffects.start()
	task.spawn(preload)
	folder = Instance.new("Folder")
	folder.Name = "KillEffects"
	folder.Parent = Workspace
	Remotes.event(Remotes.KillEffect).OnClientEvent:Connect(KillEffects.play)
end

return KillEffects
