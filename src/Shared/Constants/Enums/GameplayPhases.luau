return {
   RoundActive = 0,
   RoundEnded = 1, -- Round over; players are still in the arena (alive or not) for ROUND_ENDED_DURATION, then go to the lobby. LivingPlayersInArena is already empty. The winner screen GUI is still called PreIntermission
   LobbyVoting = 2, -- In lobby, voting active
   LobbyEnded = 3, -- In lobby, voting ended, displaying results and loading up arena before next round
   PendingPlayers = -1, -- In lobby; game does not have enough players to activate LobbyVoting/LobbyEnded or to start the round
}