--[[
	BotController

	Renders bots. The server owns each bot's invisible rig under workspace.Bots (BotService).
	Each bot's visual is a clone of its owner's rendered avatar (as built by CharacterRenderController)
	that follows the bot's root every frame. Accessories don't replicate, so the look is client-only.
]]

local BotController = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local CollisionGroupConstants = require(ReplicatedStorage.Shared.Constants.CollisionGroupConstants)
local CharacterRenderController = require(ReplicatedStorage.Client.Core.CharacterRenderController)
local BotAnimator = require(ReplicatedStorage.Client.Core.BotAnimator)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local BOTS_FOLDER_NAME = "Bots"

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type RenderedBot = {
	Model: Model,
	Visual: Model?,
	Animator: BotAnimator.BotAnimator?,
	OwnerUserId: number,
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local rendered: { [Instance]: RenderedBot } = {}
local botDespawnedEvent = SimpleRemotes.getEvent("BotDespawned")

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-- // Clones the owner's rendered avatar as the bot's visual (root-anchored, non-interactive)
local function buildVisual(ownerUserId: number): Model?
	local owner = Players:GetPlayerByUserId(ownerUserId)
	if not owner then
		return nil
	end
	-- // Never the owner's Disguise model: a decoy looks like the real avatar
	local ownerModel = CharacterRenderController.getUndisguisedCharacterModel(owner, true)
	if not ownerModel then
		return nil
	end
	local clone = ownerModel:Clone()
	clone.Name = `Bot_{ownerUserId}_Visual`

	-- // Visual-only avatar, placed with PivotTo every frame. Anchor ONLY the root; anchored limbs freeze the animation.
	local renderedRoot = clone:FindFirstChild("HumanoidRootPart")
	if renderedRoot and renderedRoot:IsA("BasePart") then
		renderedRoot.Anchored = true
	end
	local renderedHumanoid = clone:FindFirstChildOfClass("Humanoid")
	if renderedHumanoid then
		renderedHumanoid.AutoRotate = false
	end
	for _, d in pairs(clone:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CollisionGroup = CollisionGroupConstants.Players
		end
	end

	local visualsFolder = workspace:FindFirstChild("BotVisuals")
	if not visualsFolder then
		visualsFolder = Instance.new("Folder")
		visualsFolder.Name = "BotVisuals"
		visualsFolder.Parent = workspace
	end
	clone.Parent = visualsFolder

	-- // Re-applied EVERY frame: the Humanoid resets body parts to CanCollide/CanQuery = true when it scales or
	--    applies appearance, which makes boomerangs bounce off and hit the decoy.
	task.spawn(function()
		repeat
			for _, d in pairs(clone:GetDescendants()) do
				if d:IsA("BasePart") then
					d.CanCollide = false
					d.CanQuery = false
					d.CanTouch = false
					d.CollisionGroup = CollisionGroupConstants.Players
				end
			end
			RunService.Stepped:Wait()
		until not clone.Parent
	end)

	return clone
end

local function onBotRemoved(botModel: Instance)
	local entry = rendered[botModel]
	if not entry then
		return
	end
	rendered[botModel] = nil
	if entry.Animator then
		entry.Animator:destroy()
	end
	if entry.Visual then
		entry.Visual:Destroy()
	end
end

local function onBotAdded(botModel: Instance)
	if not botModel:IsA("Model") then
		return
	end
	local ownerUserId = botModel:GetAttribute("OwnerUserId")
	if typeof(ownerUserId) ~= "number" then
		return
	end

	local entry: RenderedBot = { Model = botModel :: Model, Visual = nil, Animator = nil, OwnerUserId = ownerUserId }
	rendered[botModel] = entry

	task.spawn(function()
		local visual = buildVisual(ownerUserId)
		if not rendered[botModel] then
			-- // the bot was removed while its visual was being built
			if visual then
				visual:Destroy()
			end
			return
		end
		entry.Visual = visual
		if visual then
			entry.Animator = BotAnimator.new(visual)
		end
	end)
end

local function everyFrame()
	for botModel, entry in pairs(rendered) do
		if not botModel.Parent then
			onBotRemoved(botModel)
			continue
		end
		local visual = entry.Visual
		local model = botModel :: Model
		local root = model.PrimaryPart
		if visual and root then
			visual:PivotTo(model:GetPivot())
			if entry.Animator then
				entry.Animator:update(root:GetAttribute("pose") :: string?, root.AssemblyLinearVelocity)
			end
		end
	end
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function BotController.init()
	task.spawn(function()
		local botsFolder = workspace:WaitForChild(BOTS_FOLDER_NAME)
		for _, child in pairs(botsFolder:GetChildren()) do
			onBotAdded(child)
		end
		botsFolder.ChildAdded:Connect(onBotAdded)
		botsFolder.ChildRemoved:Connect(onBotRemoved)
	end)

	botDespawnedEvent.OnClientEvent:Connect(function(_botId: string, _reason: string?)
		-- // TODO: when reason == "eliminated", play a smoke poof at the bot's last position
	end)

	RunService.RenderStepped:Connect(everyFrame)
end

function BotController.start() end

return BotController
