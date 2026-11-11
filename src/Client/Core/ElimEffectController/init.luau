--[[
	ElimEffectController

	Description:
	Client side of elimination effects ("Strike Effects"): owned and equipped effects, equip requests, the
	"New strike effect acquired!" popup, and playing the effects.
	ElimEffectService fires PlayElimEffect(victim, effectId) when a marked player dies; every client plays it on the
	victim's visible body (CharacterRenderController's model, a Disguise included), under Workspace.ElimEffects.
	Each effect is a module in Effects/ named after its id: function(character, parent), 3 s, cleans up after itself
	(ported from the client's scripter package; helpers: Fx, Rig, SharkRig).
]]

local ElimEffectController = {}

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local ElimEffectLibrary = require(ReplicatedStorage.Shared.Library.ElimEffectLibrary)
local CosmeticLibrary = require(ReplicatedStorage.Shared.Library.CosmeticLibrary)
local ElimEffectAssets = require(ReplicatedStorage.Shared.Constants.ElimEffectAssets)
local PlayerDataController = require(ReplicatedStorage.Client.Core.PlayerDataController)
local CharacterRenderController = require(ReplicatedStorage.Client.Core.CharacterRenderController)
local ItemAcquiredGui = require(ReplicatedStorage.Client.UI.Gui.ItemAcquired)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type ElimEffectTask = (elimEffectId: string) -> ()
type EffectFunction = (character: Model, parent: Instance) -> ()

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local HELPERS = { Fx = true, Rig = true, SharkRig = true } -- // Modules in Effects/ that aren't effects

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local localPlayer = Players.LocalPlayer
local equipElimEffectRemoteFunction = SimpleRemotes.getFunction("EquipElimEffect")
local playElimEffectRemote = SimpleRemotes.getEvent("PlayElimEffect")

-- // Known owned effects, so only new ones show the popup
local knownOwnedElimEffects: { [string]: boolean } = {}

local effects: { [string]: EffectFunction } = {}
local effectsFolder: Folder? = nil

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

ElimEffectController.ElimEffectGrantedTasks = TasksList.new() :: TasksList.TasksList<ElimEffectTask>
ElimEffectController.ElimEffectEquippedTasks = TasksList.new() :: TasksList.TasksList<ElimEffectTask>

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-- // Downloads every effect image in the background, so the first effect doesn't show blank sprites (Fx preloads the
-- // sounds when it loads)
local function preloadImages()
	local images = {}
	for _, value in ElimEffectAssets do
		if type(value) == "string" and string.find(value, "rbxassetid://", 1, true) then
			table.insert(images, value)
		end
	end
	pcall(function()
		ContentProvider:PreloadAsync(images)
	end)
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function ElimEffectController.ownsElimEffect(elimEffectId: string): boolean
	return ElimEffectLibrary.dataOwns(PlayerDataController.get(), elimEffectId)
end

function ElimEffectController.getEquippedId(): string
	return ElimEffectLibrary.getEquippedId(localPlayer)
end

--- Asks the server to equip an owned effect. Yields; returns whether it succeeded.
function ElimEffectController.requestEquip(elimEffectId: string): boolean
	return equipElimEffectRemoteFunction:InvokeServer(elimEffectId) == true
end

--- Plays an effect on a player's visible body, on this client only.
function ElimEffectController.play(victim: Player, elimEffectId: string)
	local run = effects[elimEffectId]
	if not run or not effectsFolder then
		return
	end
	local character = CharacterRenderController.getCharacterModel(victim, false, true)
	if character and character.Parent then
		task.spawn(run, character, effectsFolder)
	end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function ElimEffectController.init()
	for _, child in script.Effects:GetChildren() do
		if child:IsA("ModuleScript") and not HELPERS[child.Name] then
			effects[child.Name] = require(child) :: any
		end
	end

	PlayerDataController.getAsync(function(data)
		for elimEffectId, owned in data.OwnedElimEffects or {} do
			knownOwnedElimEffects[elimEffectId] = owned == true
		end
	end)
	PlayerDataController.UpdatedTasks:Add(function(index, value, path)
		if path[1] ~= "OwnedElimEffects" or #path ~= 1 or type(index) ~= "string" then
			return
		end
		local wasOwned = knownOwnedElimEffects[index] == true
		knownOwnedElimEffects[index] = value == true
		if value == true and not wasOwned then
			local elimEffect = ElimEffectLibrary.getElimEffect(index)
			ItemAcquiredGui.acquiredCustomItem(
				elimEffect and elimEffect.Icon,
				"New strike effect acquired!",
				if elimEffect then elimEffect.Name else index
			)
			ElimEffectController.ElimEffectGrantedTasks:Execute("parallel", index)
		end
	end)
	CosmeticLibrary.observe(localPlayer, "ElimEffect", function()
		ElimEffectController.ElimEffectEquippedTasks:Execute("parallel", ElimEffectController.getEquippedId())
	end)
end

function ElimEffectController.start()
	local folder = Instance.new("Folder")
	folder.Name = "ElimEffects"
	folder.Parent = Workspace
	effectsFolder = folder

	task.spawn(preloadImages)
	playElimEffectRemote.OnClientEvent:Connect(function(victim: Player, elimEffectId: string)
		if typeof(victim) == "Instance" and victim:IsA("Player") and type(elimEffectId) == "string" then
			ElimEffectController.play(victim, elimEffectId)
		end
	end)
end

return ElimEffectController
