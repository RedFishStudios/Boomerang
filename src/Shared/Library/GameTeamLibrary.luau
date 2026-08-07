local GameTeamLibrary = {}

function GameTeamLibrary.hasFriendlyFire(Team: Team?): boolean
   if not Team then
      return false
   end
   local friendlyFire = Team:GetAttribute("FriendlyFire")
   return friendlyFire == true
end

function GameTeamLibrary.areEnemies(player: Player, otherPlayer: Player): boolean
   local playerTeam = player.Team
   local otherPlayerTeam = otherPlayer.Team

   if not playerTeam or not otherPlayerTeam then
      warn(`One or both players do not have a team assigned: ${player.Name} (${tostring(playerTeam)}), ${otherPlayer.Name} (${tostring(otherPlayerTeam)})`)
      return false
   end

   if playerTeam == otherPlayerTeam then
      return GameTeamLibrary.hasFriendlyFire(playerTeam)
   end

   return true
end

return GameTeamLibrary