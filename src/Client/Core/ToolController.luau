local ToolController = {}

local localPlayer = game.Players.LocalPlayer
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local CharacterRenderController = require(game.ReplicatedStorage.Client.Core.CharacterRenderController)
local SimpleRemotes = require(game.ReplicatedStorage.Shared.Networking.SimpleRemotes)
local PlayersUtil = require(game.ReplicatedStorage.Shared.Utils.PlayersUtil)
local ToolLibrary = require(game.ReplicatedStorage.Shared.Library.ToolLibrary)
local ThrownWeapons = require(game.ReplicatedStorage.Shared.Referential.ThrownWeapons)
local GameStateLibrary = require(game.ReplicatedStorage.Shared.Library.GameStateLibrary)

----------------------------------------------------------------------------------------------------------------------------------
-- Local variables
----------------------------------------------------------------------------------------------------------------------------------

local PlayerEquippedTools: {[Player]: string} = {}
local PlayerAimStates: {[Player]: boolean} = {}

local ApplyingToolInProcess: {[Player]: true} = {}
local PendingToolUpdate: {[Player]: true} = {}
local PendingEquippedToolFetch: {[Player]: true} = {}
local EquippedTools: {[Player]: Model} = {}
local DetachedTools: {[Player]: Model} = {}
local EquippedToolCharacters: {[Player]: Model} = {}
local DetachedToolCharacters: {[Player]: Model} = {}
local MotorC0ObserverConnections: {[Player]: RBXScriptConnection} = {}
local Highlights: {
   {
      Highlight: Highlight,
      In: true?,
      Out: true?
   }
} = {}

local ToolAssets = ToolLibrary.getToolAssetsFolder()
local WeaponsFolder = workspace:WaitForChild("Weapons")

----------------------------------------------------------------------------------------------------------------------------------
-- Local functions
----------------------------------------------------------------------------------------------------------------------------------

-- // Functions to observe changes to the C0 attribute for the purpose of adjusting attachment points during editing
local function disconnectMotorC0Observer(player: Player)
	local connection = MotorC0ObserverConnections[player]
	if connection then
		connection:Disconnect()
		MotorC0ObserverConnections[player] = nil
	end
end

local function setupMotorC0Observer(player: Player, toolModel: Model, weaponMotor: Motor6D)
	disconnectMotorC0Observer(player)

	MotorC0ObserverConnections[player] = toolModel:GetAttributeChangedSignal("MotorC0"):Connect(function()
		local updatedC0 = toolModel:GetAttribute("MotorC0")
		if typeof(updatedC0) ~= "CFrame" then
			return
		end

		if not weaponMotor.Parent then
			disconnectMotorC0Observer(player)
			return
		end

		weaponMotor.C0 = updatedC0
	end)
end

local function setModelAnchored(model: Model, anchored: boolean)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = anchored
		end
	end
end

local function removeWeaponWeld(model: Model)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Motor6D") and descendant.Name == "WeaponWeld" then
			descendant:Destroy()
		end
	end
end

local function attachToolModelToCharacter(player: Player, character: Model, toolModel: Model)
   --print(`ToolController: Attaching tool model {toolModel.Name} to character {character.Name} for player {player.Name}`)
	if not character or not character.Parent then
      warn(`no character`)
		return false
	end

	toolModel.Name = `Holstered_{player.UserId}`
	toolModel:SetAttribute("ToolName", toolModel:GetAttribute("ToolName") or toolModel.Name)
	toolModel.Parent = WeaponsFolder
	setModelAnchored(toolModel, false)

	local rightArm = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not rightArm then
      warn(`no right arm`)
		rightArm = character:WaitForChild("RightHand", 2) or character:WaitForChild("Right Arm", 2)
	end
	local handle = toolModel.PrimaryPart
	if not handle then
      warn(`no handle`)
		return false
	end

	local motor = Instance.new("Motor6D")
	motor.Name = "WeaponWeld"
	motor.Part0 = rightArm
	motor.Part1 = handle

	local attributes = toolModel:GetAttributes()
	if attributes["MotorC0"] then
		motor.C0 = attributes["MotorC0"]
	end

	motor.Parent = handle
	--setupMotorC0Observer(player, toolModel, motor)

   --print(toolModel)

   ToolController.applyHighlight(false)
	return true
end

local function getToolNameFromModel(toolModel: Model?): string?
	if not toolModel then
		return nil
	end

	local value = toolModel:GetAttribute("ToolName")
	if typeof(value) == "string" then
		return value
	end

	return nil
end

local function getReadyRenderedCharacter(player: Player, canYield: boolean): Model?
	local character = CharacterRenderController.getCharacterModel(player, canYield)
	if character and character.Parent and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")) then
		return character
	end

	if not canYield then
		return nil
	end

	local elapsed = 0
	repeat
		elapsed += RunService.RenderStepped:Wait()
		character = CharacterRenderController.getCharacterModel(player, false)
	until elapsed > 5 or (character and character.Parent and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")))

	if character and character.Parent and (character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")) then
		return character
	end

	return nil
end

local function getToolCharacter(tool: Model?): Model?
	if not tool then
		return nil
	end

	for _, descendant in ipairs(tool:GetDescendants()) do
		if descendant:IsA("Motor6D") and descendant.Name == "WeaponWeld" and descendant.Part0 then
			return descendant.Part0:FindFirstAncestorOfClass("Model")
		end
	end

	return nil
end

local function getEquippedTool(player: Player): Model?
	local equippedTool = EquippedTools[player]
	if equippedTool and equippedTool.Parent then
		return equippedTool
	end

	local character = CharacterRenderController.getCharacterModel(player, false)
	if not character then
		return nil
	end

	local activeWeapon = WeaponsFolder:FindFirstChild(`Holstered_{player.UserId}`)
	if activeWeapon and activeWeapon:IsA("Model") then
		EquippedTools[player] = activeWeapon
		return activeWeapon
	end

	return nil
end

local function getDetachedTool(player: Player): Model?
	local detachedTool = DetachedTools[player]
	if detachedTool and detachedTool.Parent then
		return detachedTool
	end

	DetachedTools[player] = nil
	return nil
end

local function destroyDetachedTool(player: Player)
	disconnectMotorC0Observer(player)
	local detachedTool = getDetachedTool(player)
	if detachedTool then
		detachedTool:Destroy()
		DetachedTools[player] = nil
		DetachedToolCharacters[player] = nil
	end
end

local function destroyEquippedTool(player: Player)
   disconnectMotorC0Observer(player)
   local equippedTool = getEquippedTool(player)
	if equippedTool then
		equippedTool:Destroy()
		EquippedTools[player] = nil
		EquippedToolCharacters[player] = nil
	end
end

local function clearRenderedTool(player: Player)
	destroyEquippedTool(player)
	destroyDetachedTool(player)
end

local function ensureDesiredToolModel(player: Player, toolName: string): Model?
	local equippedTool = getEquippedTool(player)
	local detachedTool = getDetachedTool(player)

	if equippedTool and getToolNameFromModel(equippedTool) ~= toolName then
		equippedTool:Destroy()
		EquippedTools[player] = nil
		EquippedToolCharacters[player] = nil
		equippedTool = nil
	end

	if detachedTool and getToolNameFromModel(detachedTool) ~= toolName then
		detachedTool:Destroy()
		DetachedTools[player] = nil
		DetachedToolCharacters[player] = nil
		detachedTool = nil
	end

	if equippedTool then
		return equippedTool
	end
	if detachedTool then
		return detachedTool
	end

	local toolAsset = ToolAssets:FindFirstChild(toolName)
	if not (toolAsset and toolAsset:IsA("Model")) then
		warn(`ToolController: Tool asset not found for {toolName}`)
		return nil
	end

	local newTool = toolAsset:Clone()
	newTool:SetAttribute("ToolName", toolName)
	newTool.Name = `Holstered_{player.UserId}`
	newTool.Parent = WeaponsFolder
	return newTool
end

local function requestToolUpdate(player: Player, shouldFetchEquippedTool: boolean?)
	if shouldFetchEquippedTool then
		PendingEquippedToolFetch[player] = true
	end

	PendingToolUpdate[player] = true

	if ApplyingToolInProcess[player] then
		return
	end

	task.defer(function()
		if not player.Parent then
			return
		end

		if not PendingToolUpdate[player] then
			return
		end

		if ApplyingToolInProcess[player] then
			return
		end

		if not PlayersUtil.isAlive(player) then
			return
		end

		if PendingEquippedToolFetch[player] then
			PlayerEquippedTools[player] = SimpleRemotes.getFunction("GetEquippedTool"):InvokeServer(player)
			PendingEquippedToolFetch[player] = nil
		end

		PendingToolUpdate[player] = nil
		ToolController.updateTool(player)
	end)
end

----------------------------------------------------------------------------------------------------------------------------------
-- Public functions
----------------------------------------------------------------------------------------------------------------------------------

-- // Apply tool to this character
--    > Correctly adjusts to any current aim state
--    > Correctly adjusts to any current tool equipped state, updating out-of-date tools and not touching accurate tools
function ToolController.updateTool(player: Player)
   if ApplyingToolInProcess[player] then
		PendingToolUpdate[player] = true
      return
   end
   ApplyingToolInProcess[player] = true

	local function finish()
		ApplyingToolInProcess[player] = nil
		if PendingToolUpdate[player] and PlayersUtil.isAlive(player) then
			requestToolUpdate(player)
		end
	end

   local character = getReadyRenderedCharacter(player, true)
   if not character then
		finish()
      return
   end

   local toolName = PlayerEquippedTools[player]
   if not toolName then
		clearRenderedTool(player)
		ToolController.applyHighlight(false)
		finish()
      return
   end

	local toolModel = ensureDesiredToolModel(player, toolName)
	if not toolModel then
		clearRenderedTool(player)
		finish()
		return
	end

	-- Detach/attach is not driven by aiming state
	-- While aiming/charging, tools remain attached; detachment occurs only during throw flow
	if DetachedTools[player] and DetachedTools[player] == toolModel and ThrownWeapons.Data[player] and GameStateLibrary.getGameStateData().IsInRound:Get() == true then
		DetachedToolCharacters[player] = character
		finish()
		return
	end

	removeWeaponWeld(toolModel)
	if attachToolModelToCharacter(player, character, toolModel) then
		DetachedTools[player] = nil
		EquippedTools[player] = toolModel
		EquippedToolCharacters[player] = character
		DetachedToolCharacters[player] = nil
	else
		toolModel:Destroy()
		clearRenderedTool(player)
	end

	finish()
end

function ToolController.setEquippedTool(player: Player, toolName: string?, code: string?)
	PlayerEquippedTools[player] = toolName
	requestToolUpdate(player, false)
end

function ToolController.setAimState(player: Player, isAiming: boolean)
	PlayerAimStates[player] = isAiming == true
end

function ToolController.clearRenderedTool(player: Player)
	clearRenderedTool(player)
	ToolController.applyHighlight(false)
end

function ToolController.setToolVisible(player: Player, isVisible: boolean)
	local tool = getEquippedTool(player) or getDetachedTool(player)
	if not tool then
		return
	end

	local transparency = if isVisible then 0 else 1
	for _, descendant in ipairs(tool:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Transparency = transparency
		end
	end
end

function ToolController.getToolPivotPosition(player: Player): Vector3?
	local tool = getEquippedTool(player) or getDetachedTool(player)
	if tool and tool.Parent then
		return tool:GetPivot().Position
	end
	return nil
end

function ToolController.prepareToolForThrow(player: Player): (Model?, Vector3?)
	local equippedTool = getEquippedTool(player)
	if not equippedTool then
		return nil, nil
	end

	disconnectMotorC0Observer(player)
	removeWeaponWeld(equippedTool)
	setModelAnchored(equippedTool, true)
	equippedTool.Parent = WeaponsFolder

	EquippedTools[player] = nil
	DetachedTools[player] = equippedTool
	DetachedToolCharacters[player] = EquippedToolCharacters[player]
	EquippedToolCharacters[player] = nil
	PlayerAimStates[player] = true
	return equippedTool, equippedTool:GetPivot().Position
end

function ToolController.finishToolThrow(player: Player)
	local detachedTool = getDetachedTool(player)
	if not detachedTool then
		return
	end
	removeWeaponWeld(detachedTool)
	local character = getReadyRenderedCharacter(player, true)
	if character and attachToolModelToCharacter(player, character, detachedTool) then
		DetachedTools[player] = nil
		EquippedTools[player] = detachedTool
		EquippedToolCharacters[player] = character
		DetachedToolCharacters[player] = nil
		PlayerAimStates[player] = false
	else
		detachedTool:Destroy()
		DetachedTools[player] = nil
		DetachedToolCharacters[player] = nil
	end
end

function ToolController.applyHighlight(enabled: boolean)
   if enabled then
      for _, highlightData in ipairs(Highlights) do
         if highlightData.In then
            return
         end
      end
      local myTool = getDetachedTool(localPlayer)
      if not myTool then
         return
      end
      local highlight = Instance.new("Highlight")
      highlight.Adornee = myTool
      highlight.Parent = myTool
      highlight.OutlineColor = Color3.new(0.976471, 0.247059, 1)
      highlight.OutlineTransparency = 0
      highlight.FillTransparency = 1
      highlight.Enabled = true
      table.insert(Highlights, {Highlight = highlight, In = true})
      TweenService:Create(highlight, TweenInfo.new(0.1), {OutlineTransparency = 0}):Play()
   else
      for _, highlightData in ipairs(Highlights) do
         if highlightData.In then
            local highlight = highlightData.Highlight
            TweenService:Create(highlight, TweenInfo.new(0.1), {OutlineTransparency = 1}):Play()
            highlightData.In = nil
            highlightData.Out = true
         end
      end
   end
end

function ToolController.isHolstered(model: Model)
   return model.Name:match(`Holstered_%d+`) ~= nil
end

-------------------------------------------------------------------------------
-- Core Functions
-------------------------------------------------------------------------------

function ToolController.init()
	SimpleRemotes.getEvent("SetEquippedTool").OnClientEvent:Connect(function(player: Player, toolName: string?)
		ToolController.setEquippedTool(player, toolName)
   end)

	GameStateLibrary.getGameStateData().IsInRound:Subscribe(function(_isInRound: boolean)
		if localPlayer.Parent then
			requestToolUpdate(localPlayer, true)
		end
	end)

	CharacterRenderController.CustomCharacterLoaded:Add(function(player: Player, character: Model)
      if PlayerEquippedTools[player] then
			requestToolUpdate(player, false)
      else
			requestToolUpdate(player, true)
      end
   end)

   PlayersUtil.CharacterDied:Add(function(player: Player, character: Model)
	ApplyingToolInProcess[player] = nil
	PendingToolUpdate[player] = nil
	PendingEquippedToolFetch[player] = nil
	disconnectMotorC0Observer(player)
   end)

   PlayersUtil.PlayerRemoving:Add(function(player: Player)
      PlayerEquippedTools[player] = nil
		PlayerAimStates[player] = nil
		ApplyingToolInProcess[player] = nil
		PendingToolUpdate[player] = nil
		PendingEquippedToolFetch[player] = nil
		disconnectMotorC0Observer(player)
		clearRenderedTool(player)
		EquippedToolCharacters[player] = nil
		DetachedToolCharacters[player] = nil
   end)

end

--function ToolController.start() 
--end

return ToolController