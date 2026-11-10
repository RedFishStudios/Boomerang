--[[
  GlobalInstanceController

  Description:
  Handles global instancing on the client

  Author:
  @SixthAtom
]]

local GlobalInstanceController = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteCodes = require(ReplicatedStorage.Shared.Networking.RemoteCodes)
local SimpleRemotes = require(ReplicatedStorage.Shared.Networking.SimpleRemotes)
local SimpleRemotesUtil = require(ReplicatedStorage.Shared.Networking.SimpleRemotesUtil)

-------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------

local EVENT_CODES = RemoteCodes.Instances.Events

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

type IdPair = { any } -- // { id, instance }; the instance is nil if this client doesn't have it

type UpdatePayload = {
	Add: { IdPair },
	Remove: { number },
}

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local remoteEvent = SimpleRemotes.getEvent("GlobalInstanceService")

local idList: { [number]: Instance } = {}
local idLUT: { [Instance]: number } = {}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

local function loadRemotes()
	SimpleRemotesUtil.bindRemoteEventActions(remoteEvent, {
		[EVENT_CODES.Update] = function(data: UpdatePayload)
			for _, pair in data.Add do
				local id, instance = pair[1], pair[2]
				if instance then
					idList[id] = instance
					idLUT[instance] = id
				end
			end

			for _, id in data.Remove do
				local instance = idList[id]
				if instance then
					idLUT[instance] = nil
				end

				idList[id] = nil
			end
		end,

		[EVENT_CODES.SendAll] = function(data: { IdPair })
			for _, pair in data do
				local id, instance = pair[1], pair[2]
				if instance then
					idList[id] = instance
					idLUT[instance] = id
				end
			end
		end,
	})
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function GlobalInstanceController.getId(instance: Instance)
	return idLUT[instance] or instance
end

function GlobalInstanceController.getInstance(idOrInstance: number | Instance): Instance?
	if typeof(idOrInstance) == "Instance" then
		return idOrInstance
	end

	return idList[idOrInstance]
end

function GlobalInstanceController.getIdList()
	return idList
end

function GlobalInstanceController.getIdLUT()
	return idLUT
end

-------------------------------------------------------------------------------
-- CORE FUNCTIONS
-------------------------------------------------------------------------------

function GlobalInstanceController.init()
	loadRemotes()
end

-- function GlobalInstanceController.start() end

-- function GlobalInstanceController.test() end

return GlobalInstanceController
