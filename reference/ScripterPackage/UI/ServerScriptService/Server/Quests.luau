-- Quest progress, claiming and resets. State is kept per player and mirrored into attributes so the client can draw
-- it: "Quest_<id>" (progress), "QuestClaimed_<id>" (bool). Rewards add to the player's "Coins" / "XP" attributes.
--
-- Game code reports progress with Quests.addProgress(player, "Knockouts", 1) etc. (stats are in Shared.QuestData).
-- TODO: persist with a data store; for now progress resets when the player leaves.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestData = require(Shared:WaitForChild("QuestData"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local Quests = {}

type State = { periods: { [string]: number } } -- tabId -> period start the attributes belong to

local states: { [Player]: State } = {}

local function progressAttr(id: string): string
	return "Quest_" .. id
end

local function claimedAttr(id: string): string
	return "QuestClaimed_" .. id
end

-- Clears quests whose period (day / week / season) has rolled over.
local function rollover(player: Player)
	local state = states[player]
	if not state then
		return
	end
	local now = os.time()
	for _, tab in QuestData.Tabs do
		local start = QuestData.period(tab.id, now)
		if state.periods[tab.id] ~= start then
			state.periods[tab.id] = start
			for _, quest in tab.quests do
				player:SetAttribute(progressAttr(quest.id), 0)
				player:SetAttribute(claimedAttr(quest.id), false)
			end
		end
	end
end

function Quests.addProgress(player: Player, stat: string, amount: number)
	rollover(player)
	for _, quest in QuestData.byId do
		if quest.stat == stat and not player:GetAttribute(claimedAttr(quest.id)) then
			local current = player:GetAttribute(progressAttr(quest.id)) or 0
			player:SetAttribute(progressAttr(quest.id), math.min(quest.goal, current + amount))
		end
	end
end

function Quests.claim(player: Player, questId: string): boolean
	rollover(player)
	local quest = QuestData.byId[questId]
	if not quest or player:GetAttribute(claimedAttr(questId)) then
		return false
	end
	if (player:GetAttribute(progressAttr(questId)) or 0) < quest.goal then
		return false
	end
	player:SetAttribute(claimedAttr(questId), true)
	local kind = quest.reward.kind
	player:SetAttribute(kind, (player:GetAttribute(kind) or 0) + quest.reward.amount)
	return true
end

function Quests.start()
	local function init(player: Player)
		states[player] = { periods = {} }
		rollover(player)
	end
	Players.PlayerAdded:Connect(init)
	for _, player in Players:GetPlayers() do
		init(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)

	Remotes.event(Remotes.ClaimQuest).OnServerEvent:Connect(function(player: Player, questId: unknown)
		-- Remote arguments come from the client; the server checks progress itself.
		if typeof(questId) == "string" then
			Quests.claim(player, questId)
		end
	end)

	-- Daily/weekly resets for players who stay in the server across midnight.
	task.spawn(function()
		while true do
			task.wait(60)
			for player in states do
				rollover(player)
			end
		end
	end)
end

return Quests
