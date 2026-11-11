-- Quest catalog: three quests per tab. Progress and claims live on the server (Server.Quests), which mirrors them
-- into player attributes "Quest_<id>" (progress number) and "QuestClaimed_<id>" (bool).
--
-- The quest card art has the reward icon baked in: slot 1 shows the XP badge, slots 2 and 3 the coin badge. Keep
-- `reward.kind` matching ("XP" in slot 1, "Coins" in slots 2-3) until there's separate icon art.

export type Quest = {
	id: string,
	title: string,
	stat: string, -- what counts towards it; game code calls Quests.addProgress(player, stat, amount)
	goal: number,
	reward: { kind: "XP" | "Coins", amount: number },
}

export type Tab = {
	id: string,
	quests: { Quest },
}

local QuestData = {}

QuestData.Tabs = {
	{
		id = "Daily",
		quests = {
			{ id = "D1", title = "Earn 500 XP", stat = "XP", goal = 500, reward = { kind = "XP", amount = 125 } },
			{
				id = "D2",
				title = "Get 3 Knockouts",
				stat = "Knockouts",
				goal = 3,
				reward = { kind = "Coins", amount = 200 },
			},
			{
				id = "D3",
				title = "Open an Egg!",
				stat = "EggsOpened",
				goal = 1,
				reward = { kind = "Coins", amount = 125 },
			},
		},
	},
	{
		id = "Weekly",
		quests = {
			{ id = "W1", title = "Earn 5,000 XP", stat = "XP", goal = 5000, reward = { kind = "XP", amount = 750 } },
			{
				id = "W2",
				title = "Get 25 Knockouts",
				stat = "Knockouts",
				goal = 25,
				reward = { kind = "Coins", amount = 1000 },
			},
			{
				id = "W3",
				title = "Open 5 Eggs",
				stat = "EggsOpened",
				goal = 5,
				reward = { kind = "Coins", amount = 600 },
			},
		},
	},
	{
		id = "Season",
		quests = {
			{ id = "S1", title = "Earn 50,000 XP", stat = "XP", goal = 50000, reward = { kind = "XP", amount = 5000 } },
			{
				id = "S2",
				title = "Get 250 Knockouts",
				stat = "Knockouts",
				goal = 250,
				reward = { kind = "Coins", amount = 7500 },
			},
			{
				id = "S3",
				title = "Open 30 Eggs",
				stat = "EggsOpened",
				goal = 30,
				reward = { kind = "Coins", amount = 4000 },
			},
		},
	},
} :: { Tab }

-- Season end (UTC). Daily resets at UTC midnight, Weekly on Monday 00:00 UTC.
QuestData.SeasonEndsAt = DateTime.fromUniversalTime(2027, 1, 1, 0, 0, 0).UnixTimestamp

-- Start of the current period for a tab, and when it ends.
function QuestData.period(tabId: string, now: number): (number, number)
	local day = 86400
	if tabId == "Daily" then
		local start = now - now % day
		return start, start + day
	elseif tabId == "Weekly" then
		-- Unix day 0 (1970-01-01) was a Thursday; shift so weeks start on Monday.
		local days = now // day
		local start = (days - (days + 3) % 7) * day
		return start, start + 7 * day
	end
	return 0, QuestData.SeasonEndsAt
end

QuestData.byId = {} :: { [string]: Quest }
QuestData.tabOf = {} :: { [string]: string }
for _, tab in QuestData.Tabs do
	for _, quest in tab.quests do
		QuestData.byId[quest.id] = quest
		QuestData.tabOf[quest.id] = tab.id
	end
end

return QuestData
