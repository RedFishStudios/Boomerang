local ToolController = {}

local EquippedTools: {[Player]: Model} = {}

local ToolAssets = game:GetService("ReplicatedStorage").Shared.Assets.Tools

local function getEquippedTool(player: Player): Model?
	local equippedTool = EquippedTools[player]
	if equippedTool and equippedTool.Parent then
		return equippedTool
	end

	local character = player.Character
	if not character then
		return nil
	end

	local activeWeapon = character:FindFirstChild("ActiveWeapon")
	if activeWeapon and activeWeapon:IsA("Model") then
		EquippedTools[player] = activeWeapon
		return activeWeapon
	end

	return nil
end

local function equipTool(player: Player, tool: Model)
   print("EQUIPPING TOOL")
	local character = player.Character
	if not character then
		return
	end

	ToolController.unequipTool(player)

	-- Clone the model to the character
	local weaponClone = tool:Clone()
	weaponClone.Name = "ActiveWeapon"
	weaponClone.Parent = character
	EquippedTools[player] = weaponClone

	-- Find the hand and the weapon's handle
	local rightArm = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	local handle = weaponClone.PrimaryPart
	
	if rightArm and handle then
		local motor = Instance.new("Motor6D")
		motor.Name = "WeaponWeld"
		motor.Part0 = rightArm
		motor.Part1 = handle

      local Attributes = weaponClone:GetAttributes()
      if Attributes.MotorC0 then
         motor.C0 = Attributes.MotorC0
      end
		
		-- Optional: Adjust C0 and C1 properties here to change how the hand holds the item
		motor.Parent = handle
	end
   print("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~")
   print(weaponClone)
   print(weaponClone.Parent)
end

function ToolController.equipTool(player: Player, toolName: string)
	local tool = ToolAssets:FindFirstChild(toolName)
	if tool and tool:IsA("Model") then
		equipTool(player, tool)
	end
end

function ToolController.unequipTool(player: Player)
	local equippedTool = getEquippedTool(player)
	if not equippedTool then
		return
	end

	equippedTool:Destroy()
	EquippedTools[player] = nil
end

function ToolController.setToolVisible(player: Player, isVisible: boolean)
	local equippedTool = getEquippedTool(player)
	if not equippedTool then
		return
	end

	local transparency = if isVisible then 0 else 1
	for _, descendant in ipairs(equippedTool:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Transparency = transparency
		end
	end
end

return ToolController