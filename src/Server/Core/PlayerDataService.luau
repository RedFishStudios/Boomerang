--[[
  PlayerDataService

  Description:
  Handles server-side player data

  Author:
  @SixthAtom

  Date:
  20-02-2026
]]

local PlayerDataService = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)
local ProfileStore = require(ServerStorage.Packages.ProfileStore)
local ProfileTemplate = require(ReplicatedStorage.Shared.Data.ProfileTemplate)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local NON_WIPABLE_INDEXES: { string } = {} -- // Profile fields kept when a profile is wiped

local DATA_KEY = RunService:IsStudio() and "Dev" or "Live"

local REFRESH_SAVE_TIMEOUT_SECONDS = 30 -- // PlayerDataService.refresh gives up waiting for its save after this long

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type Profile = typeof(ProfileStore.New("", ProfileTemplate.get()):StartSessionAsync(...)) & { DataProxy: ProfileTemplate.Template }

export type Data = ProfileTemplate.Template

type UpdateTask = (player: Player, index: Index, value: any, path: { string | number }) -> ()
type ProfileAddedTask = (player: Player, data: ProfileTemplate.Template, profile: Profile) -> ()
type ProfileRemovedTask = (player: Player, profile: Profile) -> ()

type Index = string | number
type EventMeta = { [string]: any }

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local updateDataRemote = SimpleRemotes.getEvent("UpdateData")
local getDataRemote = SimpleRemotes.getFunction("GetData")

local store = ProfileStore.New(DATA_KEY, ProfileTemplate.get() :: any)

local profiles: { [Player]: Profile } = {}
local replicationSchedule: { [Player]: { { any } } } = {}
local refreshing: { [Player]: boolean } = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

PlayerDataService.UpdatedTasks = TasksList.new() :: TasksList.TasksList<UpdateTask>
PlayerDataService.ProfileAddedTasks = TasksList.new() :: TasksList.TasksList<ProfileAddedTask>
PlayerDataService.ProfileRemovedTasks = TasksList.new() :: TasksList.TasksList<ProfileRemovedTask>
-- // Runs (serially) before the profile session ends, while writes are still saved
PlayerDataService.ProfileRemovingTasks = TasksList.new() :: TasksList.TasksList<ProfileRemovedTask>

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function scheduleReplication(player: Player, path: { string | number }, i: any, v: any)
	if not replicationSchedule[player] then
		replicationSchedule[player] = {}
	end

	table.insert(replicationSchedule[player], { path, i, v })
end

local function loadReplication(player: Player, tbl: { [any]: any }, _path: { string | number }?)
	local path = _path or {}

	local childProxies = {}
	local proxy = setmetatable({}, {
		__newindex = function(_, i, v)
			-- // The value always goes into the real table (that is what the profile saves and __call returns). A table also
			-- // gets a child proxy wrapping that same table; any other value drops a child proxy left over from a table it replaces.
			tbl[i] = v
			if type(v) == "table" then
				local newPath = table.clone(path)
				table.insert(newPath, i)
				childProxies[i] = loadReplication(player, v, newPath)
			else
				childProxies[i] = nil
			end
			scheduleReplication(player, path, i, v)
			PlayerDataService.UpdatedTasks:Execute("parallel", player, i, v, path)
		end,

		__index = function(_, i)
			return childProxies[i] or tbl[i]
		end,

		__call = function()
			return tbl
		end,

		__iter = function()
			local lastKey: any
			return function()
				local i, v = next(tbl, lastKey)
				lastKey = i
				return i, v
			end
		end,
	})

	for i, v in tbl do
		if type(v) == "table" then
			local newPath = table.clone(path)
			table.insert(newPath, i)
			childProxies[i] = loadReplication(player, v, newPath)
		end
	end

	return proxy
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

--[[
	Returns the live data proxy for the given player.
	The returned table is a replicated proxy:
	- Writing to it automatically schedules client replication.
	- Nested tables are also proxied.
	@return ProfileTemplate.Template? -- The player's data proxy, or nil if the profile is not loaded.
]]
function PlayerDataService.get(player: Player)
	local profile = profiles[player]
	if profile then
		return profile.DataProxy
	end
	return nil
end

--[[
	Calls the callback() when the data is finished loading.
	The returned table is a replicated proxy:
	- Writing to it automatically schedules client replication.
	- Nested tables are also proxied.
	@return ProfileTemplate.Template? -- The player's data proxy, or nil if the profile is not loaded.
]]
function PlayerDataService.getAsync(player: Player, callback: (data: ProfileTemplate.Template) -> ())
	local profile = profiles[player]
	if not profile then
		player:GetAttributeChangedSignal("DataInitialized"):Once(function()
			callback(profiles[player].DataProxy)
		end)
		return
	end

	task.spawn(callback, profile.DataProxy)
end

--[[
	Completely resets a player's profile to the default template.
	This immediately overwrites stored data and forcibly removes the player
	from the server to prevent continued play with wiped data.
	@return nil
]]
function PlayerDataService.wipe(player: Player, dontKick: true?)
	local profile = profiles[player]
	if profile then
		local oldData = profile.Data
		local newData = ProfileTemplate.get()

		for _, v in next, NON_WIPABLE_INDEXES do
			if oldData[v] then
				newData[v] = oldData[v]
			end
		end

		profile.Data = newData
		profile:Save()

		if not dontKick then
			player:Kick(`DATA WIPED {player.Name}`)
		end
	end
end

--[[
	Returns the live profile object for the given player.
	This includes both `Data` and `DataProxy`.
	@return Profile? -- The player's profile, or nil if not loaded.
]]
function PlayerDataService.getProfile(player: Player): Profile?
	return profiles[player]
end

--[[
	Returns all currently loaded profiles keyed by Player.
	Returns live profile objects so callers CAN mutate internal state directly.
	@return { [Player]: Profile }
]]
function PlayerDataService.getProfiles()
	return profiles
end

--[[
	Simulates the player leaving and rejoining, without actually removing them (Cmdr `refreshdata`). Yields.
	1. Runs the same "leaving" tasks as PlayerRemoving (flushes pending stats into the data).
	2. Saves the profile to the datastore and waits for that save to finish.
	3. Reads the saved data back from the datastore.
	4. Replaces the profile's data and data proxy with what was read, sends it all to the client and runs the "joined" tasks.
	The profile session is kept the whole time, so if anything fails before step 4 the player's data is untouched.
	@return boolean, string -- success, and a message describing what happened
]]
function PlayerDataService.refresh(player: Player): (boolean, string)
	local profile = profiles[player]
	if not profile then
		return false, "data not loaded"
	end
	if refreshing[player] then
		return false, "already refreshing"
	end
	refreshing[player] = true

	local ok, result = pcall(function(): string
		PlayerDataService.ProfileRemovingTasks:Execute("serial", player, profile)

		-- // Save and wait. OnSave fires as our save starts, OnAfterSave once a save succeeds; only count one that follows ours.
		local started, saved = false, false
		local onSaveConnection = profile.OnSave:Connect(function()
			started = true
		end)
		local onAfterSaveConnection = profile.OnAfterSave:Connect(function()
			if started then
				saved = true
			end
		end)
		profile:Save()
		local deadline = os.clock() + REFRESH_SAVE_TIMEOUT_SECONDS
		while not saved and os.clock() < deadline and profiles[player] == profile do
			task.wait()
		end
		onSaveConnection:Disconnect()
		onAfterSaveConnection:Disconnect()
		if profiles[player] ~= profile then
			error("the player left or their profile ended")
		end
		if not saved then
			error(`the save didn't finish within {REFRESH_SAVE_TIMEOUT_SECONDS}s`)
		end

		-- // Read it back from the datastore (a view of the saved data; the live session is untouched)
		local loaded = store:GetAsync(`{player.UserId}`)
		if not loaded then
			error("couldn't read the saved data back from the datastore")
		end
		loaded:Reconcile()
		if profiles[player] ~= profile then
			error("the player left or their profile ended")
		end

		-- // Swap it in, tell the client, and let every system pick up the new data like it does on join
		profile.Data = loaded.Data
		profile.DataProxy = loadReplication(player, profile.Data)
		for index, value in profile.Data do
			scheduleReplication(player, {}, index, value)
			PlayerDataService.UpdatedTasks:Execute("parallel", player, index, value, {})
		end
		PlayerDataService.ProfileAddedTasks:Execute("parallel", player, profile.DataProxy, profile)

		return "saved and reloaded from the datastore"
	end)

	refreshing[player] = nil
	if ok then
		return true, result
	end
	return false, tostring(result)
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function PlayerDataService.start()
	-- On start, so this is absolute last.
	PlayersUtil.PlayerAdded:Add(function(player: Player)
		local profile = store:StartSessionAsync(`{player.UserId}`, {
			Cancel = function()
				return not Players:IsAncestorOf(player)
			end,
		}) :: Profile

		if profile then
			profile:AddUserId(player.UserId)
			profile:Reconcile()

			profile.OnSessionEnd:Connect(function()
				profiles[player] = nil
				player:Kick(`Profile session end - Please rejoin`)
			end)

			if Players:IsAncestorOf(player) then
				profiles[player] = profile

				profile.DataProxy = loadReplication(player, profile.Data)
				player:SetAttribute("DataInitialized", true)
				PlayerDataService.ProfileAddedTasks:Execute("parallel", player, profile.DataProxy, profile)

				--warn(`Loaded profile for {player.Name}: `, profile)
			else
				profile:EndSession()
			end
		else
			player:Kick("Profile load fail - Please rejoin")
		end
	end)
end

function PlayerDataService.init()
	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		if profile then
			PlayerDataService.ProfileRemovingTasks:Execute("serial", player, profile)
			profile:EndSession()
			PlayerDataService.ProfileRemovedTasks:Execute("parallel", player, profile)
			profiles[player] = nil
		end
	end)

	RunService.PostSimulation:Connect(function()
		task.defer(task.defer, function()
			for player, schedule in replicationSchedule do
				updateDataRemote:FireClient(player, schedule)
			end
			replicationSchedule = {}
		end)
	end)

	getDataRemote.OnServerInvoke = function(player: Player)
		if not player:GetAttribute("DataInitialized") then
			player:GetAttributeChangedSignal("DataInitialized"):Wait()
		end

		return profiles[player].Data
	end
end

return PlayerDataService
