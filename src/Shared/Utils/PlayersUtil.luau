local PlayersUtil = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TasksList = require(ReplicatedStorage.Shared.Classes.TasksList)

local ROOT_PART_LOAD_TIMEOUT_SECONDS = 10

PlayersUtil.PlayerAdded = TasksList.new() :: TasksList.TasksList<(player: Player) -> ()>
PlayersUtil.PlayerRemoving = TasksList.new() :: TasksList.TasksList<(player: Player) -> ()>
PlayersUtil.CharacterAdded = TasksList.new() :: TasksList.TasksList<(player: Player, character: Model) -> ()>
PlayersUtil.CharacterDestroying = TasksList.new() :: TasksList.TasksList<(player: Player, character: Model) -> ()>
PlayersUtil.CharacterDied = TasksList.new() :: TasksList.TasksList<(player: Player, character: Model, humanoid: Humanoid) -> ()>
PlayersUtil.CharacterLoaded = TasksList.new() :: TasksList.TasksList<(player: Player, character: Model, humanoid: Humanoid, rootPart: BasePart) -> ()> -- character's vitals (rootpart and humanoid) have loaded

local playerAddedConnections: { [Player]: RBXScriptConnection } = {}
local playerCharacterConnections: { [Player]: { [string]: RBXScriptConnection } } = {}

local function disconnectCharacterConnections(player: Player)
	local connections = playerCharacterConnections[player]
	if not connections then
		return
	end

	for _, connection in connections do
		connection:Disconnect()
	end

	playerCharacterConnections[player] = nil
end

local function onCharacterAdded(player: Player, character: Model)
	disconnectCharacterConnections(player)

	local didFireDestroying = false
	local didFireDied = false

	local function fireCharacterDestroying()
		if didFireDestroying then
			return
		end
		didFireDestroying = true
		PlayersUtil.CharacterDestroying:Execute("deferred", player, character)
	end

	PlayersUtil.CharacterAdded:Execute("deferred", player, character)

	local connections: { [string]: RBXScriptConnection } = {}

	connections.Destroying = character.Destroying:Connect(function()
		fireCharacterDestroying()
	end)

	connections.AncestryChanged = character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			fireCharacterDestroying()
		end
	end)

   local humanoid = character:WaitForChild("Humanoid", ROOT_PART_LOAD_TIMEOUT_SECONDS)
	local rootPart = character:WaitForChild("HumanoidRootPart", ROOT_PART_LOAD_TIMEOUT_SECONDS)
   if rootPart and humanoid and character.Parent then
      PlayersUtil.CharacterLoaded:Execute("deferred", player, character, humanoid, rootPart)
   end

   if not character.Parent then
      return
   end

	local humanoid = character:WaitForChild("Humanoid", 5)
	if humanoid then
		local function onHealthChanged(health: number)
			if didFireDied or health > 0 then
				return
			end
			didFireDied = true
			PlayersUtil.CharacterDied:Execute("deferred", player, character, humanoid)
		end

		connections.HealthChanged = humanoid.HealthChanged:Connect(onHealthChanged)
		onHealthChanged(humanoid.Health)
	end

	playerCharacterConnections[player] = connections
end

local function onPlayerAdded(player: Player, shouldFireAddedEvent: boolean?)
	if shouldFireAddedEvent ~= false then
		PlayersUtil.PlayerAdded:Execute("deferred", player)
	end

	if player.Character then
		onCharacterAdded(player, player.Character)
	end

	if playerAddedConnections[player] then
		playerAddedConnections[player]:Disconnect()
	end

	playerAddedConnections[player] = player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
end

local function onPlayerRemoving(player: Player)
	PlayersUtil.PlayerRemoving:Execute("deferred", player)

	if playerAddedConnections[player] then
		playerAddedConnections[player]:Disconnect()
		playerAddedConnections[player] = nil
	end

	disconnectCharacterConnections(player)
end

for _, player in Players:GetPlayers() do
	task.defer(onPlayerAdded, player, false)
end

Players.PlayerAdded:Connect(function(player)
	onPlayerAdded(player, true)
end)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function PlayersUtil.isAlive(player: Player)
	local character = player.Character
	if not character then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid and humanoid.Health > 0
end

function PlayersUtil.getHumanoid(player: Player): Humanoid?
	if PlayersUtil.isAlive(player) then
		return player.Character:FindFirstChildOfClass("Humanoid")
	end
	return nil
end

return PlayersUtil