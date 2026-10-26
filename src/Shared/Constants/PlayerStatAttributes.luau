-- // T-130: stats every client can read for every player (the Stats panel), published by the server as attributes on each Player.
-- // Lifetime ones mirror the saved profile (LifetimeStatsService); round ones count the current round (reset when a round starts).
return table.freeze({
	RoundElims = "StatsRoundElims",
	RoundDefeats = "StatsRoundDefeats",
	Elims = "StatsElims",
	Defeats = "StatsDefeats",
	Wins = "StatsWins",
	Losses = "StatsLosses", -- // Rounds played that weren't won (ties count as not won)
})
