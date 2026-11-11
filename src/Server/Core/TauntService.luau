--[[
	TauntService

	Description:
	Owns taunts on the server: granting, buying and equipping them (profile `OwnedTaunts` / `EquippedTaunt`), published
	as the `EquippedTaunt` Player attribute (CosmeticLibrary).
	A player asks to taunt (RequestTaunt, the T key); the server checks it's allowed (TauntLibrary.canTauntNow: the
	RoundEnded phase with enough of it left), that the player is alive and not already taunting, then tells every client
	to play it (PlayTaunt(player, tauntId, skinId)). The character carries the `Taunting` attribute while it plays.
	The taunting player's own client keeps them planted (their client owns their movement).
	Taunt data: Shared/Referential/Taunts.
]]

local TauntService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local TauntLibrary = require(ReplicatedStorage.Shared.Library.TauntLibrary)
local SkinLibrary = require(ReplicatedStorage.Shared.Library.SkinLibrary)
local CosmeticLibrary = require(ReplicatedStorage.Shared.Library.CosmeticLibrary)
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)
local EconomyService = require(ServerStorage.Server.Core.EconomyService)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type TauntTask = (player: Player, tauntId: string) -> ()

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local equipTauntRemoteFunction = SimpleRemotes.getFunction("EquipTaunt")
local requestTauntRemote = SimpleRemotes.getEvent("RequestTaunt")
local playTauntRemote = SimpleRemotes.getEvent("PlayTaunt")

local busyUntil: { [Player]: number } = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

TauntService.TauntGrantedTasks = TasksList.new() :: TasksList.TasksList<TauntTask>
TauntService.TauntEquippedTasks = TasksList.new() :: TasksList.TasksList<TauntTask>

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function applyEquippedTaunt(player: Player, tauntId: string)
	CosmeticLibrary.setEquipped(player, "Taunt", tauntId)
	TauntService.TauntEquippedTasks:Execute("parallel", player, tauntId)
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function TauntService.ownsTaunt(player: Player, tauntId: string): boolean
	return TauntLibrary.dataOwns(PlayerDataService.get(player), tauntId)
end

--- Gives the player a taunt. Returns false if it doesn't exist, the data isn't loaded, or it's already owned.
function TauntService.grantTaunt(player: Player, tauntId: string): boolean
	local data = PlayerDataService.get(player)
	if not data or not TauntLibrary.getTaunt(tauntId) or TauntLibrary.dataOwns(data, tauntId) then
		return false
	end

	data.OwnedTaunts[tauntId] = true
	TauntService.TauntGrantedTasks:Execute("parallel", player, tauntId)
	return true
end

--- Buys a taunt with Currency. Returns false if it's off sale, already owned, or can't be afforded.
function TauntService.purchaseTaunt(player: Player, tauntId: string): boolean
	local taunt = TauntLibrary.getTaunt(tauntId)
	if not taunt or taunt.OffSale or not PlayerDataService.get(player) or TauntService.ownsTaunt(player, tauntId) then
		return false
	end

	if not EconomyService.spendCurrency(player, taunt.Price) then
		return false
	end

	return TauntService.grantTaunt(player, tauntId)
end

--- Equips an owned taunt. Returns false if the player doesn't own it or the data isn't loaded.
function TauntService.equipTaunt(player: Player, tauntId: string): boolean
	local data = PlayerDataService.get(player)
	if not data or not TauntLibrary.dataOwns(data, tauntId) then
		return false
	end

	if data.EquippedTaunt ~= tauntId then
		data.EquippedTaunt = tauntId
	end
	if CosmeticLibrary.getEquippedRaw(player, "Taunt") ~= tauntId then
		applyEquippedTaunt(player, tauntId)
	end
	return true
end

--- Plays the player's equipped taunt for everyone. With `ignoreWindow`, it also plays outside the RoundEnded phase
--- (Cmdr testing). Returns false if they can't taunt right now.
function TauntService.play(player: Player, ignoreWindow: boolean?): boolean
	local now = os.clock()
	if (busyUntil[player] or 0) > now then
		return false
	end
	if not ignoreWindow and not TauntLibrary.canTauntNow() then
		return false
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (character and humanoid) or humanoid.Health <= 0 then
		return false
	end

	local tauntId = TauntLibrary.getEquippedId(player)
	busyUntil[player] = now + TauntLibrary.DURATION
	character:SetAttribute(TauntLibrary.CHARACTER_ATTRIBUTE, tauntId)
	playTauntRemote:FireAllClients(player, tauntId, SkinLibrary.getEquippedSkinId(player))
	task.delay(TauntLibrary.DURATION, function()
		if character.Parent then
			character:SetAttribute(TauntLibrary.CHARACTER_ATTRIBUTE, nil)
		end
	end)
	return true
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function TauntService.init()
	equipTauntRemoteFunction.OnServerInvoke = function(player: Player, tauntId: unknown)
		if type(tauntId) ~= "string" then
			return false
		end
		return TauntService.equipTaunt(player, tauntId)
	end

	requestTauntRemote.OnServerEvent:Connect(function(player: Player)
		TauntService.play(player)
	end)

	PlayerDataService.ProfileAddedTasks:Add(function(player: Player, data)
		-- // Fall back to the default if the saved taunt no longer exists or isn't owned
		local tauntId = data.EquippedTaunt
		if type(tauntId) ~= "string" or not TauntLibrary.dataOwns(data, tauntId) then
			tauntId = TauntLibrary.getDefaultId()
			data.EquippedTaunt = tauntId
		end
		applyEquippedTaunt(player, tauntId)
	end)

	Players.PlayerRemoving:Connect(function(player)
		busyUntil[player] = nil
	end)
end

function TauntService.start() end

return TauntService
