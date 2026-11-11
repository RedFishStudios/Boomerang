--[[
	TauntController

	Description:
	Client side of taunts: owned and equipped taunts, equip requests, the "New taunt acquired!" popup, the Taunt input,
	and playing taunts.
	The input (T, gamepad Y, or a touch button) is bound only during the RoundEnded phase and asks the server
	(RequestTaunt). TauntService answers every client with PlayTaunt(player, tauntId, skinId); each client plays it on
	that player's visible body (CharacterRenderController's model) under Workspace.Taunts. The taunting player's own
	client keeps their character planted for the taunt (no walking, jumping or turning).
	Each taunt is a module in Taunts/ named after its id: function(character, parent, skinId) -> duration (ported from
	the client's scripter package; helpers: Pose, Props, Effects).
]]

local TauntController = {}

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local TauntLibrary = require(ReplicatedStorage.Shared.Library.TauntLibrary)
local CosmeticLibrary = require(ReplicatedStorage.Shared.Library.CosmeticLibrary)
local GameStateLibrary = require(ReplicatedStorage.Shared.Library.GameStateLibrary)
local GameplayPhases = require(ReplicatedStorage.Shared.Constants.Enums.GameplayPhases)
local PlayerDataController = require(ReplicatedStorage.Client.Core.PlayerDataController)
local CharacterRenderController = require(ReplicatedStorage.Client.Core.CharacterRenderController)
local ItemAcquiredGui = require(ReplicatedStorage.Client.UI.Gui.ItemAcquired)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type TauntTask = (tauntId: string) -> ()
type TauntFunction = (character: Model, parent: Instance, skinId: string) -> number

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local ACTION_NAME = "Taunt"
local HELPERS = { Pose = true, Props = true, Effects = true } -- // Modules in Taunts/ that aren't taunts

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local localPlayer = Players.LocalPlayer
local equipTauntRemoteFunction = SimpleRemotes.getFunction("EquipTaunt")
local requestTauntRemote = SimpleRemotes.getEvent("RequestTaunt")
local playTauntRemote = SimpleRemotes.getEvent("PlayTaunt")

-- // Known owned taunts, so only new ones show the popup
local knownOwnedTaunts: { [string]: boolean } = {}

local taunts: { [string]: TauntFunction } = {}
local tauntsFolder: Folder? = nil
local playing: { [Model]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local inputBound = false

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

TauntController.TauntGrantedTasks = TasksList.new() :: TasksList.TasksList<TauntTask>
TauntController.TauntEquippedTasks = TasksList.new() :: TasksList.TasksList<TauntTask>

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-- // Keeps the local character planted (no walking, jumping or turning) for `duration`, then gives movement back
local function plantLocalCharacter(duration: number)
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local walkSpeed, jumpHeight, jumpPower, autoRotate =
		humanoid.WalkSpeed, humanoid.JumpHeight, humanoid.JumpPower, humanoid.AutoRotate
	local endsAt = os.clock() + duration
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function()
		if os.clock() >= endsAt or not humanoid.Parent or humanoid.Health <= 0 then
			connection:Disconnect()
			if humanoid.Parent then
				humanoid.WalkSpeed, humanoid.JumpHeight, humanoid.JumpPower, humanoid.AutoRotate =
					walkSpeed, jumpHeight, jumpPower, autoRotate
			end
			return
		end
		-- // Held every frame, so nothing else gives the character its speed back mid-taunt
		humanoid.WalkSpeed, humanoid.JumpHeight, humanoid.JumpPower, humanoid.AutoRotate = 0, 0, 0, false
	end)
end

local function onTauntInput(_actionName: string, inputState: Enum.UserInputState): Enum.ContextActionResult
	if inputState == Enum.UserInputState.Begin then
		requestTauntRemote:FireServer()
	end
	return Enum.ContextActionResult.Pass -- // Gamepad Y is also Recall
end

-- // The Taunt input exists only while taunting is possible (the RoundEnded phase), so its touch button does too
local function updateInputBinding(gameplayPhase: number?)
	local shouldBind = gameplayPhase == GameplayPhases.RoundEnded
	if shouldBind == inputBound then
		return
	end
	inputBound = shouldBind
	if shouldBind then
		ContextActionService:BindAction(ACTION_NAME, onTauntInput, true, Enum.KeyCode.T, Enum.KeyCode.ButtonY)
		ContextActionService:SetTitle(ACTION_NAME, "Taunt")
	else
		ContextActionService:UnbindAction(ACTION_NAME)
	end
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function TauntController.ownsTaunt(tauntId: string): boolean
	return TauntLibrary.dataOwns(PlayerDataController.get(), tauntId)
end

function TauntController.getEquippedId(): string
	return TauntLibrary.getEquippedId(localPlayer)
end

--- Asks the server to equip an owned taunt. Yields; returns whether it succeeded.
function TauntController.requestEquip(tauntId: string): boolean
	return equipTauntRemoteFunction:InvokeServer(tauntId) == true
end

--- Plays a taunt on a player's visible body, on this client only.
function TauntController.play(player: Player, tauntId: string, skinId: string)
	local run = taunts[tauntId]
	if not run or not tauntsFolder then
		return
	end
	if player == localPlayer then
		plantLocalCharacter(TauntLibrary.DURATION)
	end
	local character = CharacterRenderController.getCharacterModel(player, false, true)
	if not character or not character.Parent or playing[character] then
		return
	end
	playing[character] = true
	local folder = tauntsFolder
	task.spawn(function()
		local duration = run(character, folder, skinId)
		task.wait(duration)
		playing[character] = nil
	end)
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function TauntController.init()
	for _, child in script.Taunts:GetChildren() do
		if child:IsA("ModuleScript") and not HELPERS[child.Name] then
			taunts[child.Name] = require(child) :: any
		end
	end

	PlayerDataController.getAsync(function(data)
		for tauntId, owned in data.OwnedTaunts or {} do
			knownOwnedTaunts[tauntId] = owned == true
		end
	end)
	PlayerDataController.UpdatedTasks:Add(function(index, value, path)
		if path[1] ~= "OwnedTaunts" or #path ~= 1 or type(index) ~= "string" then
			return
		end
		local wasOwned = knownOwnedTaunts[index] == true
		knownOwnedTaunts[index] = value == true
		if value == true and not wasOwned then
			local taunt = TauntLibrary.getTaunt(index)
			ItemAcquiredGui.acquiredCustomItem(taunt and taunt.Icon, "New taunt acquired!", if taunt then taunt.Name else index)
			TauntController.TauntGrantedTasks:Execute("parallel", index)
		end
	end)
	CosmeticLibrary.observe(localPlayer, "Taunt", function()
		TauntController.TauntEquippedTasks:Execute("parallel", TauntController.getEquippedId())
	end)
end

function TauntController.start()
	local folder = Instance.new("Folder")
	folder.Name = "Taunts"
	folder.Parent = Workspace
	tauntsFolder = folder

	playTauntRemote.OnClientEvent:Connect(function(player: Player, tauntId: string, skinId: string)
		if typeof(player) == "Instance" and player:IsA("Player") and type(tauntId) == "string" then
			TauntController.play(player, tauntId, if type(skinId) == "string" then skinId else "")
		end
	end)

	local gameplayPhase = GameStateLibrary.getGameStateData().GameplayPhase
	gameplayPhase:Subscribe(updateInputBinding)
	updateInputBinding(gameplayPhase:Get())
end

return TauntController
