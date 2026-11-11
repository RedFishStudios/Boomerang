-- Plays taunts the server announces (Server.Taunts) on any character, locally on each client, and lets the local
-- player taunt with the T key (or the on-screen Taunt button on touch devices).
--
-- Every ModuleScript in this folder except the helpers (Pose, Props, Effects) is a taunt, named as in Shared.Cosmetics' `taunt`
-- field: TooEasy, Bonk, RoyalTreatment, NapTime. Each is function(character, propsFolder, skinId) -> duration.

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local Taunts = {}

local HELPERS = { Pose = true, Props = true, Effects = true }

local TAUNTS: { [string]: (Model, Instance, string) -> number } = {}
for _, child in script:GetChildren() do
	if child:IsA("ModuleScript") and not HELPERS[child.Name] then
		TAUNTS[child.Name] = require(child) :: any
	end
end

local folder: Folder
local playing: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any

function Taunts.play(character: Model, taunt: string, skinId: string)
	local run = TAUNTS[taunt]
	if not run then
		warn(`[Taunts] unknown taunt "{taunt}"`)
		return
	end
	if not character or not character.Parent or playing[character] then
		return
	end
	playing[character] = true
	task.spawn(function()
		local duration = run(character, folder, skinId)
		task.wait(duration)
		playing[character] = nil
	end)
end

function Taunts.start()
	folder = Instance.new("Folder")
	folder.Name = "Taunts"
	folder.Parent = Workspace
	Remotes.event(Remotes.PlayTaunt).OnClientEvent:Connect(Taunts.play)
	ContextActionService:BindAction("Taunt", function(_, state)
		if state == Enum.UserInputState.Begin then
			Remotes.event(Remotes.Taunt):FireServer()
		end
		return Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.T, Enum.KeyCode.ButtonY)
	ContextActionService:SetTitle("Taunt", "Taunt")
end

return Taunts
