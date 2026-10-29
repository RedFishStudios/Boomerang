--[[
	Quests (T-143)

	Description:
	Every quest the game can hand out, and the pools they're drawn from. QuestService (server) gives each player
	`Slots` quests from each pool, drawn at random from that pool's quests, and draws new ones when the pool resets.
	The text, progress and reward logic is shared (QuestLibrary), so a new pool (e.g. an event) only needs an entry in
	Pools and its quests in List.

	Objective types (what counts, and where it's counted in QuestService):
	- Eliminations: eliminating another player, or a bot whose behavior counts (decoys don't). Optional Gamemode.
	- Wins: winning a round (team wins count for every member). Optional Gamemode.
	- RoundsPlayed: being in a round from its start to its finish. Optional Gamemode.
	- MinutesPlayed: minutes alive in the arena during a round.
	- Throws: accepted weapon throws in a round.
	- AbilityUses: uses of AbilityId (e.g. "Dash", "Stab") in a round.
	- Pickups: pickups collected; PickupId limits it to one kind (a PickupLogics module name).
	- PickupUses: uses of the pickup PickupId (T-148): pressing its use button (Decoy, Explosive Boomerang...), or
	  collecting one that takes effect at once (Shield, Speedup...).

	Rewards use the shared reward shape (RewardLibrary): Currency, Skin, ChargeUpEffect, Emote or Item. A quest
	without its own Reward gives its pool's Reward. Daily and weekly quests only give Currency in practice; cosmetics
	are for event quests.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RewardLibrary = require(ReplicatedStorage.Shared.Library.RewardLibrary)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type ObjectiveType = "Eliminations" | "Wins" | "RoundsPlayed" | "MinutesPlayed" | "Throws" | "AbilityUses" | "Pickups" | "PickupUses"

export type Objective = {
	Type: ObjectiveType,
	Goal: number,
	Gamemode: string?, -- // Gamemode id (Shared/Constants/Gamemodes); only rounds of it count
	AbilityId: string?, -- // AbilityUses: which ability
	PickupId: string?, -- // Pickups: which pickup (nil = any). PickupUses: which pickup (required)
}

export type Quest = {
	Id: string, -- // Saved in the profile: don't rename a quest that has shipped
	Pool: string, -- // Key in Pools
	Objective: Objective,
	Text: string?, -- // Shown instead of the generated text (QuestLibrary.getText)
	Reward: RewardLibrary.Reward?, -- // nil = the pool's Reward
}

export type ResetPeriod = "Day" | "Week" | "Never"

export type Pool = {
	DisplayName: string,
	Slots: number, -- // Quests a player has from this pool at once
	ResetPeriod: ResetPeriod, -- // Day: UTC midnight. Week: UTC midnight between Sunday and Monday. Never: event pools
	Reward: RewardLibrary.Reward, -- // Default reward for the pool's quests
	Order: number, -- // Display order in the Quests menu
}

-------------------------------------------------------------------------------
-- POOLS
-------------------------------------------------------------------------------

local Pools: { [string]: Pool } = {
	Daily = {
		DisplayName = "Daily Quests",
		Slots = 3,
		ResetPeriod = "Day",
		Reward = { Type = "Currency", Value = 100 },
		Order = 1,
	},
	Weekly = {
		DisplayName = "Weekly Quests",
		Slots = 3,
		ResetPeriod = "Week",
		Reward = { Type = "Currency", Value = 500 },
		Order = 2,
	},
}

-------------------------------------------------------------------------------
-- QUESTS
-------------------------------------------------------------------------------

local List: { Quest } = {
	-- // Daily
	{ Id = "DailyEliminations", Pool = "Daily", Objective = { Type = "Eliminations", Goal = 5 } },
	{ Id = "DailyWins", Pool = "Daily", Objective = { Type = "Wins", Goal = 1 } },
	{ Id = "DailyRounds", Pool = "Daily", Objective = { Type = "RoundsPlayed", Goal = 3 } },
	{ Id = "DailyMinutes", Pool = "Daily", Objective = { Type = "MinutesPlayed", Goal = 15 } },
	{ Id = "DailyThrows", Pool = "Daily", Objective = { Type = "Throws", Goal = 50 } },
	{ Id = "DailyDashes", Pool = "Daily", Objective = { Type = "AbilityUses", AbilityId = "Dash", Goal = 25 } },
	{ Id = "DailyStabs", Pool = "Daily", Objective = { Type = "AbilityUses", AbilityId = "Stab", Goal = 15 } },
	{ Id = "DailyPickups", Pool = "Daily", Objective = { Type = "Pickups", Goal = 5 } },

	-- // Weekly
	{ Id = "WeeklyEliminations", Pool = "Weekly", Objective = { Type = "Eliminations", Goal = 50 } },
	{ Id = "WeeklyWins", Pool = "Weekly", Objective = { Type = "Wins", Goal = 10 } },
	{ Id = "WeeklyRounds", Pool = "Weekly", Objective = { Type = "RoundsPlayed", Goal = 25 } },
	{ Id = "WeeklyMinutes", Pool = "Weekly", Objective = { Type = "MinutesPlayed", Goal = 120 } },
	{ Id = "WeeklyThrows", Pool = "Weekly", Objective = { Type = "Throws", Goal = 400 } },
	{ Id = "WeeklyPickups", Pool = "Weekly", Objective = { Type = "Pickups", Goal = 40 } },
	{ Id = "WeeklyShields", Pool = "Weekly", Objective = { Type = "Pickups", PickupId = "Shield", Goal = 5 } },
	{ Id = "WeeklyEliminationWins", Pool = "Weekly", Objective = { Type = "Wins", Gamemode = "Elimination", Goal = 2 } },
	{ Id = "WeeklyTeamClassicWins", Pool = "Weekly", Objective = { Type = "Wins", Gamemode = "TeamClassic", Goal = 3 } },
}

-- // T-148: "Use <pickup> N times" quests, one per pickup in each pool (ids "DailyUse<Pickup>" / "WeeklyUse<Pickup>").
-- // Only pickups that can spawn (not Disabled in their PickupLogics module).
local USE_PICKUP_IDS = {
	"Decoy",
	"Disguise",
	"ElectricBoomerang",
	"ExplosiveBoomerang",
	"FireBoomerang",
	"HomingBoomerang",
	"Shield",
	"Speedup",
	"Telekinesis",
	"TeleportBoomerang",
}
local USE_PICKUP_GOALS = { Daily = 3, Weekly = 6 }
for _, pickupId in USE_PICKUP_IDS do
	for _, poolName in { "Daily", "Weekly" } do
		table.insert(List, {
			Id = `{poolName}Use{pickupId}`,
			Pool = poolName,
			Objective = { Type = "PickupUses", PickupId = pickupId, Goal = USE_PICKUP_GOALS[poolName] },
		})
	end
end

return {
	Pools = Pools,
	List = List,
}
