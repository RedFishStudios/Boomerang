-- Player stats for the Stats panel, mirrored into player attributes so the client can draw them live:
--   current match: "MatchElims", "MatchDefeats"
--   all time:      "Elims", "Defeats", "Wins", "Losses" (saved in a DataStore)
--
-- Eliminations and defeats are counted automatically from deaths: the victim gets a defeat, and the killer (the
-- classic "creator" ObjectValue under the victim's Humanoid, as Server.KillEffects uses) gets an elimination.
-- Round code calls Stats.startMatch() when a match begins and Stats.endMatch(winners) when it ends.
-- In Studio without API access (or if the DataStore fails) stats still work, they just aren't saved.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Stats = {}

Stats.MATCH = { "MatchElims", "MatchDefeats" }
Stats.ALL_TIME = { "Elims", "Defeats", "Wins", "Losses" }

local STORE_NAME = "PlayerStats_v1"

local store: DataStore? = nil
local loaded: { [Player]: boolean } = {} -- only save players whose saved stats loaded (never overwrite with zeros)

local function key(player: Player): string
	return "stats_" .. player.UserId
end

function Stats.add(player: Player, attribute: string, amount: number?)
	player:SetAttribute(attribute, (player:GetAttribute(attribute) or 0) + (amount or 1))
end

-- Resets every player's current-match counters.
function Stats.startMatch()
	for _, player in Players:GetPlayers() do
		for _, attribute in Stats.MATCH do
			player:SetAttribute(attribute, 0)
		end
	end
end

-- Records a win for each player in `winners` and a loss for everyone else in the server.
function Stats.endMatch(winners: { Player })
	local won: { [Player]: boolean } = {}
	for _, player in winners do
		won[player] = true
	end
	for _, player in Players:GetPlayers() do
		Stats.add(player, if won[player] then "Wins" else "Losses")
	end
end

local function load(player: Player)
	for _, attribute in Stats.MATCH do
		player:SetAttribute(attribute, 0)
	end
	for _, attribute in Stats.ALL_TIME do
		if player:GetAttribute(attribute) == nil then
			player:SetAttribute(attribute, 0)
		end
	end
	if not store then
		return
	end
	local ok, data = pcall(function()
		return (store :: DataStore):GetAsync(key(player))
	end)
	if not ok then
		warn("[Stats] couldn't load stats for", player.Name, data)
		return
	end
	if player.Parent ~= Players then
		return
	end
	if typeof(data) == "table" then
		for _, attribute in Stats.ALL_TIME do
			local value = data[attribute]
			if typeof(value) == "number" then
				-- Add, in case anything was counted while loading.
				Stats.add(player, attribute, value)
			end
		end
	end
	loaded[player] = true
end

local function save(player: Player)
	if not store or not loaded[player] then
		return
	end
	local data = {}
	for _, attribute in Stats.ALL_TIME do
		data[attribute] = player:GetAttribute(attribute) or 0
	end
	local ok, err = pcall(function()
		(store :: DataStore):SetAsync(key(player), data)
	end)
	if not ok then
		warn("[Stats] couldn't save stats for", player.Name, err)
	end
end

local function watch(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	humanoid.Died:Once(function()
		Stats.add(player, "Defeats")
		Stats.add(player, "MatchDefeats")
		local creator = humanoid:FindFirstChild("creator")
		local killer = creator and creator:IsA("ObjectValue") and creator.Value
		if killer and killer:IsA("Player") and killer ~= player and killer.Parent == Players then
			Stats.add(killer, "Elims")
			Stats.add(killer, "MatchElims")
		end
	end)
end

function Stats.start()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[Stats] DataStore unavailable, stats won't be saved:", result)
	end

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			watch(player, character)
		end)
		if player.Character then
			task.spawn(watch, player, player.Character)
		end
		task.spawn(load, player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		save(player)
		loaded[player] = nil
	end)
	game:BindToClose(function()
		local pending = 0
		for _, player in Players:GetPlayers() do
			pending += 1
			task.spawn(function()
				save(player)
				pending -= 1
			end)
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do
			task.wait()
		end
	end)
end

return Stats
