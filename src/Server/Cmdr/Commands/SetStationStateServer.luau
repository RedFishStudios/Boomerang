local ServerStorage = game:GetService("ServerStorage")

local LobbyStationService = require(ServerStorage.Server.Core.LobbyStationService)

return function(_context, players: { Player }, stationId: string, state: string, promptEnabled: boolean?)
	local newState = if state:lower() == "clear" then nil else { State = state, PromptEnabled = promptEnabled }

	for _, player in players do
		LobbyStationService.setPlayerState(player, stationId, newState)
	end

	return if newState then `Set "{stationId}" to {state} for {#players} player(s).` else `Cleared "{stationId}" for {#players} player(s).`
end
