--[[
	ChargeHoldLibrary (T-140)

	Holds a player still while they charge a throw in the Experimental control scheme (ControlSchemeController), the server
	authority way: the hold is a replicated input, so the server and the player's own client prediction stop the character on
	the same simulation frame and let it go on the same frame.

	- The server adds an InputAction "ChargeHoldAction" (a Bool with a Scriptable binding) to every player's CharacterContext,
	  next to the PlayerModule's own actions (InputContexts are made by the server and replicated; actions a client adds
	  itself aren't part of the replicated input).
	- The client presses it while charging and lets go when the boomerang is thrown (ChargeHoldLibrary.setHeld).
	- Inside the simulation step, on the server for every player and on the client for its own character: while it's held,
	  the character's move input is cancelled (Humanoid:Move(zero), after the ControlModule has applied the move input).
	  The MoveAction itself keeps tracking WASD the whole time, so movement is back the moment it's let go, keys still held
	  included, and WASD can aim meanwhile (WeaponController reads the MoveAction).
]]

local ChargeHoldLibrary = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ACTION_NAME = "ChargeHoldAction"
local BINDING_NAME = "ScriptableBinding"
local SIMULATION_PRIORITY = 2000 -- // After the ControlModule's move input in the same step

local isServer = RunService:IsServer()

local function getCharacterContext(player: Player): Instance?
	local inputContexts = player:FindFirstChild("InputContexts")
	return inputContexts and inputContexts:FindFirstChild("CharacterContext")
end

local function getHoldAction(player: Player): InputAction?
	local characterContext = getCharacterContext(player)
	local action = characterContext and characterContext:FindFirstChild(ACTION_NAME)
	return if action and action:IsA("InputAction") then action else nil
end

-- // Server: give this player's (replicated) CharacterContext the hold action once it exists
local function addHoldAction(player: Player)
	task.spawn(function()
		local inputContexts = player:WaitForChild("InputContexts", 60)
		local characterContext = inputContexts and inputContexts:WaitForChild("CharacterContext", 60)
		if not characterContext or characterContext:FindFirstChild(ACTION_NAME) then
			return
		end
		local action = Instance.new("InputAction")
		action.Name = ACTION_NAME
		action.Type = Enum.InputActionType.Bool
		local binding = Instance.new("InputBinding")
		binding.Name = BINDING_NAME
		binding.Type = Enum.InputBindingType.Scriptable
		binding.Parent = action
		action.Parent = characterContext
	end)
end

local function holdStill(player: Player)
	local action = getHoldAction(player)
	if not action or action:GetState() ~= true then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:Move(Vector3.zero)
	end
end

local function stepHolds()
	if isServer then
		for _, player in ipairs(Players:GetPlayers()) do
			holdStill(player)
		end
	else
		holdStill(Players.LocalPlayer)
	end
end

-- // Client: hold the local player still (true) or let go (false)
function ChargeHoldLibrary.setHeld(held: boolean)
	if isServer then
		return
	end
	local action = getHoldAction(Players.LocalPlayer)
	local binding = action and action:FindFirstChild(BINDING_NAME)
	if binding and binding:IsA("InputBinding") then
		pcall(function()
			binding:Fire(held)
		end)
	end
end

function ChargeHoldLibrary.isHeld(player: Player): boolean
	local action = getHoldAction(player)
	return action ~= nil and action:GetState() == true
end

function ChargeHoldLibrary.init()
	if isServer then
		Players.PlayerAdded:Connect(addHoldAction)
		for _, player in ipairs(Players:GetPlayers()) do
			addHoldAction(player)
		end
	end
	RunService:BindToSimulation(stepHolds, Enum.StepFrequency.Hz60, SIMULATION_PRIORITY)
end

function ChargeHoldLibrary.start() end

return ChargeHoldLibrary
