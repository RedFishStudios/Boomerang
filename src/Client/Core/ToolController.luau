local ToolController = {}

local localPlayer = game.Players.LocalPlayer
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local CharacterRenderController = require(game.ReplicatedStorage.Client.Core.CharacterRenderController)

----------------------------------------------------------------------------------------------------------------------------------
-- Local variables
----------------------------------------------------------------------------------------------------------------------------------

local EquippedTools: {[Player]: Model} = {}
local DetachedTools: {[Player]: Model} = {}
local EquippedToolCharacters: {[Player]: Model} = {}
local DetachedToolCharacters: {[Player]: Model} = {}
local Highlights: {
   {
      Highlight: Highlight,
      In: true?,
      Out: true?
   }
} = {}

local ToolAssets = game:GetService("ReplicatedStorage").Shared.Assets.Tools
local WeaponsFolder = workspace:WaitForChild("Weapons")

local PendingEquips: {[Player]: true} = {}

----------------------------------------------------------------------------------------------------------------------------------
-- Local functions
----------------------------------------------------------------------------------------------------------------------------------

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
	toolModel.Name = `Holstered_{player.UserId}`
	toolModel.Parent = WeaponsFolder
	setModelAnchored(toolModel, false)

	local rightArm = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not rightArm then
		rightArm = character:WaitForChild("RightHand", 2) or character:WaitForChild("Right Arm", 2)
	end
	local handle = toolModel.PrimaryPart
	if not (rightArm and handle) then
		return false
	end

	local motor = Instance.new("Motor6D")
	motor.Name = "WeaponWeld"
	motor.Part0 = rightArm
	motor.Part1 = handle

	local attributes = toolModel:GetAttributes()
	if attributes.MotorC0 then
		motor.C0 = attributes.MotorC0
	end

	motor.Parent = handle

   ToolController.applyHighlight(false)
	return true
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
	local detachedTool = getDetachedTool(player)
	if detachedTool then
		detachedTool:Destroy()
		DetachedTools[player] = nil
		DetachedToolCharacters[player] = nil
	end
end

local function destroyEquippedTool(player: Player)
   local equippedTool = getEquippedTool(player)
	if equippedTool then
		equippedTool:Destroy()
		EquippedTools[player] = nil
		EquippedToolCharacters[player] = nil
	end
end

local function shouldAffectCharacter(player: Player, expectedCharacter: Model?): boolean
	if not expectedCharacter then
		return true
	end

	local equippedCharacter = EquippedToolCharacters[player]
	if not equippedCharacter and EquippedTools[player] then
		equippedCharacter = getToolCharacter(EquippedTools[player])
		EquippedToolCharacters[player] = equippedCharacter
	end

	local detachedCharacter = DetachedToolCharacters[player]
	if not detachedCharacter and DetachedTools[player] then
		detachedCharacter = getToolCharacter(DetachedTools[player])
		DetachedToolCharacters[player] = detachedCharacter
	end

	if equippedCharacter and equippedCharacter ~= expectedCharacter then
		return false
	end
	if detachedCharacter and detachedCharacter ~= expectedCharacter then
		return false
	end

	return true
end

----------------------------------------------------------------------------------------------------------------------------------
-- Public functions
----------------------------------------------------------------------------------------------------------------------------------

function ToolController.equipTool(player: Player, toolName: string)
   if PendingEquips[player] then
      return
   end

   PendingEquips[player] = true
   local character = CharacterRenderController.getCharacterModel(player, true)
	if not character then
		local elapsed = 0
      repeat
         elapsed += RunService.RenderStepped:Wait()
      until CharacterRenderController.getCharacterModel(player, false) or elapsed > 20 or not PendingEquips[player]
      character = CharacterRenderController.getCharacterModel(player, false)

      if not character or not PendingEquips[player] then
         PendingEquips[player] = nil
         return
      end
	end

   -- There is a racing condition waiting for the character to load here for some reason.
   -- Even though attachToolModelToCharacter runs and claims to have successfully attached,
   -- it is possible for the attachment to have silently failed, and the tool's ancestry becomes nil immedately after this function
   -- No solution I've pursued has fixed this
   -- whatever. go my wait statement
   --task.wait(.1)

	local tool = ToolAssets:FindFirstChild(toolName)
	if tool and tool:IsA("Model") then
		ToolController.unequipTool(player, true)
      destroyDetachedTool(player)
      local weaponClone = tool:Clone()
      if attachToolModelToCharacter(player, character, weaponClone) then
         EquippedTools[player] = weaponClone
			EquippedToolCharacters[player] = character
      else
         weaponClone:Destroy()
      end
	end

   PendingEquips[player] = nil
end

function ToolController.unequipTool(player: Player, doNotCancelEquipment: boolean, expectedCharacter: Model?)
   if not doNotCancelEquipment then
      PendingEquips[player] = nil
   end
	if shouldAffectCharacter(player, expectedCharacter) then
		destroyEquippedTool(player)
		destroyDetachedTool(player)
	end
   if player == localPlayer then
      ToolController.applyHighlight(false)
   end
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

	removeWeaponWeld(equippedTool)
	setModelAnchored(equippedTool, true)
	equippedTool.Parent = WeaponsFolder

	EquippedTools[player] = nil
	DetachedTools[player] = equippedTool
	DetachedToolCharacters[player] = EquippedToolCharacters[player]
	EquippedToolCharacters[player] = nil
	return equippedTool, equippedTool:GetPivot().Position
end

function ToolController.finishToolThrow(player: Player)
	local detachedTool = getDetachedTool(player)
	if not detachedTool then
		return
	end
	removeWeaponWeld(detachedTool)
	if attachToolModelToCharacter(player, CharacterRenderController.getCharacterModel(player, false), detachedTool) then
		DetachedTools[player] = nil
		EquippedTools[player] = detachedTool
		EquippedToolCharacters[player] = CharacterRenderController.getCharacterModel(player, false)
		DetachedToolCharacters[player] = nil
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

function ToolController.init()
end

--function ToolController.start() 
--end

return ToolController