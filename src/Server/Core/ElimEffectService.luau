--[[
	ElimEffectService

	Description:
	Owns elimination effects ("Strike Effects") on the server: granting, buying and equipping them (profile
	`OwnedElimEffects` / `EquippedElimEffect`), published as the `EquippedElimEffect` Player attribute (CosmeticLibrary).
	When a player's Humanoid dies with an effect marked on it (ElimEffectLibrary.markLethalHit, done by CombatLibrary
	for lethal hits from another player), tells every client to play it (PlayElimEffect); ElimEffectController renders
	it on the eliminated player's visible body.
	Effect data: Shared/Referential/ElimEffects.
]]

local ElimEffectService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local ElimEffectLibrary = require(ReplicatedStorage.Shared.Library.ElimEffectLibrary)
local CosmeticLibrary = require(ReplicatedStorage.Shared.Library.CosmeticLibrary)
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)
local EconomyService = require(ServerStorage.Server.Core.EconomyService)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type ElimEffectTask = (player: Player, elimEffectId: string) -> ()

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local equipElimEffectRemoteFunction = SimpleRemotes.getFunction("EquipElimEffect")
local playElimEffectRemote = SimpleRemotes.getEvent("PlayElimEffect")

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

ElimEffectService.ElimEffectGrantedTasks = TasksList.new() :: TasksList.TasksList<ElimEffectTask>
ElimEffectService.ElimEffectEquippedTasks = TasksList.new() :: TasksList.TasksList<ElimEffectTask>

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function applyEquippedElimEffect(player: Player, elimEffectId: string)
	CosmeticLibrary.setEquipped(player, "ElimEffect", elimEffectId)
	ElimEffectService.ElimEffectEquippedTasks:Execute("parallel", player, elimEffectId)
end

-- // Plays the marked effect for everyone when this character's Humanoid dies
local function watchCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	humanoid.Died:Once(function()
		local elimEffectId = ElimEffectLibrary.getMarked(humanoid)
		if elimEffectId then
			playElimEffectRemote:FireAllClients(player, elimEffectId)
		end
	end)
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function ElimEffectService.ownsElimEffect(player: Player, elimEffectId: string): boolean
	return ElimEffectLibrary.dataOwns(PlayerDataService.get(player), elimEffectId)
end

--- Gives the player an effect. Returns false if it doesn't exist, the data isn't loaded, or it's already owned.
function ElimEffectService.grantElimEffect(player: Player, elimEffectId: string): boolean
	local data = PlayerDataService.get(player)
	if not data or not ElimEffectLibrary.getElimEffect(elimEffectId) or ElimEffectLibrary.dataOwns(data, elimEffectId) then
		return false
	end

	data.OwnedElimEffects[elimEffectId] = true
	ElimEffectService.ElimEffectGrantedTasks:Execute("parallel", player, elimEffectId)
	return true
end

--- Buys an effect with Currency. Returns false if it's off sale, already owned, or can't be afforded.
function ElimEffectService.purchaseElimEffect(player: Player, elimEffectId: string): boolean
	local elimEffect = ElimEffectLibrary.getElimEffect(elimEffectId)
	if
		not elimEffect
		or elimEffect.OffSale
		or not PlayerDataService.get(player)
		or ElimEffectService.ownsElimEffect(player, elimEffectId)
	then
		return false
	end

	if not EconomyService.spendCurrency(player, elimEffect.Price) then
		return false
	end

	return ElimEffectService.grantElimEffect(player, elimEffectId)
end

--- Equips an owned effect. Returns false if the player doesn't own it or the data isn't loaded.
function ElimEffectService.equipElimEffect(player: Player, elimEffectId: string): boolean
	local data = PlayerDataService.get(player)
	if not data or not ElimEffectLibrary.dataOwns(data, elimEffectId) then
		return false
	end

	if data.EquippedElimEffect ~= elimEffectId then
		data.EquippedElimEffect = elimEffectId
	end
	if CosmeticLibrary.getEquippedRaw(player, "ElimEffect") ~= elimEffectId then
		applyEquippedElimEffect(player, elimEffectId)
	end
	return true
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function ElimEffectService.init()
	equipElimEffectRemoteFunction.OnServerInvoke = function(player: Player, elimEffectId: unknown)
		if type(elimEffectId) ~= "string" then
			return false
		end
		return ElimEffectService.equipElimEffect(player, elimEffectId)
	end

	PlayerDataService.ProfileAddedTasks:Add(function(player: Player, data)
		-- // Fall back to the default if the saved effect no longer exists or isn't owned
		local elimEffectId = data.EquippedElimEffect
		if type(elimEffectId) ~= "string" or not ElimEffectLibrary.dataOwns(data, elimEffectId) then
			elimEffectId = ElimEffectLibrary.getDefaultId()
			data.EquippedElimEffect = elimEffectId
		end
		applyEquippedElimEffect(player, elimEffectId)
	end)
end

function ElimEffectService.start()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			watchCharacter(player, character)
		end)
		if player.Character then
			task.spawn(watchCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
end

return ElimEffectService
