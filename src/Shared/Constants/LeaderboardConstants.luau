-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

-- // Player-facing wording: "Eliminations", never "Kills" (see CLAUDE.md)
local LeaderboardConstants = {
	RefreshInterval = 10 * 60, -- // Seconds between saving scores and reloading the top players
	DisplaySwapInterval = 10, -- // Seconds each board shows Monthly / All-Time before fading to the other
	FadeDuration = 1, -- // Seconds for a full swap: half fading out, half fading back in (T-053)
	EntriesShown = 30,

	-- // One physical board per stat, in workspace.Lobby.Leaderboards. Face = the large side facing the lobby floor
	Boards = {
		Elims = {
			StatField = "Elims", -- // Profile field (all-time) and MonthlyStats field (monthly)
			Title = "Eliminations",
			Face = Enum.NormalId.Right,
		},
		Wins = {
			StatField = "Wins",
			Title = "Wins",
			Face = Enum.NormalId.Left,
		},
	},

	-- // Each board shows these in turn
	Periods = { "Monthly", "AllTime" },
	PeriodTitles = {
		Monthly = "Monthly",
		AllTime = "All-Time",
	},
}

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type BoardId = "Elims" | "Wins"
export type Period = "Monthly" | "AllTime"
export type Entry = {
	Rank: number,
	UserId: number,
	DisplayName: string,
	Value: number,
}
-- // BoardId -> Period -> top entries
export type LeaderboardData = { [string]: { [string]: { Entry } } }

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

-- // The current month in UTC, e.g. "2026-10". Monthly boards reset when this changes
function LeaderboardConstants.getMonthKey(): string
	return os.date("!%Y-%m") :: string
end

return LeaderboardConstants
