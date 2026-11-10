--!optimize 2

--[[
  GlobalInstanceService

  Description:
  Handles instance tagging

  Author:
  @SixthAtom
]]

local GlobalInstanceService = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Counter = require(ReplicatedStorage.Shared.Classes.Counter)
local RemoteCodes = require(ReplicatedStorage.Shared.Networking.RemoteCodes)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local BufferUtil = require(ReplicatedStorage.Shared.Utils.BufferUtil)
local PlayersUtil = require(ReplicatedStorage.Shared.Utils.PlayersUtil)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local EVENT_CODES = RemoteCodes.Instances.Events

local IGNORE_LIST: { Instance } = table.freeze({
	-- workspace.Map,
})

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local remoteEvent = SimpleRemotes.getEvent("GlobalInstanceService")

local idCounter = Counter.new(1)

local idList: { [number]: Instance } = {}
local idLUT: { [Instance]: number } = {}
-- // Add holds { id, instance } pairs, so an instance a client doesn't have can't shift the ids of the others
local thisFrameFireBuffer: { Add: { { any } }, Remove: { number } } = { Add = {}, Remove = {} }

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function isInstanceIgnored(instance: Instance)
	for _, v in next, IGNORE_LIST do
		if v:IsAncestorOf(instance) then
			return true
		end
	end
	return false
end

local function addInstance(instance: Instance)
	if isInstanceIgnored(instance) then
		return
	end

	local id = idCounter:Increment()

	idList[id] = instance
	idLUT[instance] = id

	table.insert(thisFrameFireBuffer.Add, { id, instance })
end

local function replicate()
	remoteEvent:FireAllClients(EVENT_CODES.Update, thisFrameFireBuffer)

	thisFrameFireBuffer = {
		Add = {},
		Remove = {},
	}
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function GlobalInstanceService.getId(instance: Instance)
	return idLUT[instance] or instance
end

function GlobalInstanceService.getInstance(idOrInstance: number | Instance): Instance?
	if typeof(idOrInstance) == "Instance" then
		return idOrInstance
	end

	return idList[idOrInstance]
end

function GlobalInstanceService.getIdList()
	return idList
end

function GlobalInstanceService.getIdLUT()
	return idLUT
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function GlobalInstanceService.init()
	PlayersUtil.PlayerAdded:Add(function(player)
		local pairsList = {}
		for id, instance in idList do
			table.insert(pairsList, { id, instance })
		end
		remoteEvent:FireClient(player, EVENT_CODES.SendAll, pairsList)
	end)

	RunService.PostSimulation:Connect(function()
		if #thisFrameFireBuffer.Add == 0 and #thisFrameFireBuffer.Remove == 0 then
			return
		end

		task.defer(replicate)
	end)

	workspace.DescendantAdded:Connect(function(instance)
		if not (instance:IsA("BasePart") or instance:IsA("Model")) then
			return
		end

		if idLUT[instance] then
			return
		end

		addInstance(instance)
	end)

	for _, instance in workspace:QueryDescendants("Model,BasePart") do
		if not idLUT[instance] then
			addInstance(instance)
		end
	end
end

function GlobalInstanceService.start()
	while task.wait(2) do
		local toRemove = {}
		local i = 1

		for id, instance in idList do
			if i % 500 == 0 then
				task.wait()
			end
			i += 1

			if instance.Parent then
				continue
			end

			idList[id] = nil
			idLUT[instance] = nil
			table.insert(toRemove, id)
		end

		for _, id in toRemove do
			table.insert(thisFrameFireBuffer.Remove, id)
		end
	end
end

-- function GlobalInstanceService.test()
-- end

return GlobalInstanceService
