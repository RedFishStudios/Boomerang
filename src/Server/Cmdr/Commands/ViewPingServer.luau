return function(context)
	local player: Player = context.Executor
	return `Your ping (according to the server): {math.round(player:GetNetworkPing() * 1000)} ms`
end
