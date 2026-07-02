local CurrentGameState: {
   IsInRound: boolean,
   RoundTypeId: string?, -- If in a round
   CurrentMapName: string?, -- If in a round
   RemainingTime: number?, -- If in a round

   -- Copied over from RoundTypes data when a round is set
   CanRespawn: boolean?
} = {
   IsInRound = false,
   RoundTypeId = nil,
   CurrentMapName = nil,
   RemainingTime = nil,
   CanRespawn = nil,
}
return CurrentGameState