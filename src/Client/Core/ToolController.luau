local ToolController = {}

local EquippedTools: {[Player]: Model} = {}
local DetachedTools: {[Player]: Model} = {}

local ToolAssets = game:GetService("ReplicatedStorage").Shared.Assets.Tools
local WeaponsFolder = workspace:WaitForChild("Weapons")

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

local function attachToolModelToCharacter(player: Player, toolModel: Model)
	local character = player.Character
	if not character then
		return false
	end

	toolModel.Name = `ActiveWeapon_{player.UserId}`
	toolModel.Parent = WeaponsFolder
	setModelAnchored(toolModel, false)

	local rightArm = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
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
	return true
end

local function getEquippedTool(player: Player): Model?
	local equippedTool = EquippedTools[player]
	if equippedTool and equippedTool.Parent then
		return equippedTool
	end

	local character = player.Character
	if not character then
		return nil
	end

	local activeWeapon = WeaponsFolder:FindFirstChild(`ActiveWeapon_{player.UserId}`)
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

local function equipTool(player: Player, tool: Model)
	local character = player.Character
	if not character then
		return
	end

	ToolController.unequipTool(player)
	local detachedTool = getDetachedTool(player)
	if detachedTool then
		detachedTool:Destroy()
		DetachedTools[player] = nil
	end

	-- Clone the model to the character
	local weaponClone = tool:Clone()
	if attachToolModelToCharacter(player, weaponClone) then
		EquippedTools[player] = weaponClone
	else
		weaponClone:Destroy()
	end
end

function ToolController.equipTool(player: Player, toolName: string)
	local tool = ToolAssets:FindFirstChild(toolName)
	if tool and tool:IsA("Model") then
		equipTool(player, tool)
	end
end

function ToolController.unequipTool(player: Player)
	local equippedTool = getEquippedTool(player)
	if equippedTool then
		equippedTool:Destroy()
		EquippedTools[player] = nil
	end

	local detachedTool = getDetachedTool(player)
	if detachedTool then
		detachedTool:Destroy()
		DetachedTools[player] = nil
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
	return equippedTool, equippedTool:GetPivot().Position
end

function ToolController.finishToolThrow(player: Player)
	local detachedTool = getDetachedTool(player)
	if not detachedTool then
		return
	end

	removeWeaponWeld(detachedTool)
	if attachToolModelToCharacter(player, detachedTool) then
		DetachedTools[player] = nil
		EquippedTools[player] = detachedTool
	else
		detachedTool:Destroy()
		DetachedTools[player] = nil
	end
end

return ToolController