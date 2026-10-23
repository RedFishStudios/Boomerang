--[[
	CrateLibrary (T-112)

	Description:
	Shared helpers for the weapon crates (Shared/Referential/Crates): what a crate can give and with which chance, and the
	weighted roll. A crate's contents are the tools of its Category with a CrateWeight above 0 (Shared/Constants/Tools) that
	have a skin (the skin whose Model is the tool). Safe on server and client; only the server rolls (CrateService).
]]

local CrateLibrary = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Crates = require(ReplicatedStorage.Shared.Referential.Crates)
local Tools = require(ReplicatedStorage.Shared.Constants.Tools)
local Skins = require(ReplicatedStorage.Shared.Referential.Skins)

export type CrateEntry = {
	ToolId: string,
	SkinId: string, -- // What the player is given
	Weight: number,
	Chance: number, -- // 0..1 (Weight / total weight of the crate)
}

-------------------------------------------------------------------------------
-- PRIVATE FUNCTIONS
-------------------------------------------------------------------------------

-- // The skin that is this tool (Model == toolId); the lowest Order one if there are several
local function getSkinIdForTool(toolId: string): string?
	local bestId: string? = nil
	local bestOrder = math.huge
	for skinId, skin in Skins do
		if skin.Model == toolId and skin.Order < bestOrder then
			bestId = skinId
			bestOrder = skin.Order
		end
	end
	return bestId
end

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function CrateLibrary.getCrate(crateId: string?): Crates.Crate?
	return if crateId then Crates[crateId] else nil
end

-- // Every crate id, in display order
function CrateLibrary.getSortedCrateIds(): { string }
	local crateIds = {}
	for crateId in Crates do
		table.insert(crateIds, crateId)
	end
	table.sort(crateIds, function(a, b)
		return Crates[a].Order < Crates[b].Order
	end)
	return crateIds
end

-- // What the crate can give, sorted by chance (highest first). Empty for an unknown crate.
function CrateLibrary.getEntries(crateId: string): { CrateEntry }
	local crate = Crates[crateId]
	local entries: { CrateEntry } = {}
	if not crate then
		return entries
	end
	local totalWeight = 0
	for toolId, tool in Tools do
		local weight = tool.CrateWeight or 0
		local skinId = getSkinIdForTool(toolId)
		if tool.Category == crate.Category and weight > 0 and skinId then
			table.insert(entries, { ToolId = toolId, SkinId = skinId, Weight = weight, Chance = 0 })
			totalWeight += weight
		end
	end
	for _, entry in entries do
		entry.Chance = entry.Weight / totalWeight
	end
	table.sort(entries, function(a, b)
		if a.Weight ~= b.Weight then
			return a.Weight > b.Weight
		end
		return a.ToolId < b.ToolId
	end)
	return entries
end

-- // Weighted random pick from the crate. rng: optional Random (for tests). nil if the crate gives nothing.
function CrateLibrary.roll(crateId: string, rng: Random?): CrateEntry?
	local entries = CrateLibrary.getEntries(crateId)
	local totalWeight = 0
	for _, entry in entries do
		totalWeight += entry.Weight
	end
	if totalWeight <= 0 then
		return nil
	end
	local pick = (rng or Random.new()):NextNumber() * totalWeight
	for _, entry in entries do
		pick -= entry.Weight
		if pick < 0 then
			return entry
		end
	end
	return entries[#entries]
end

return CrateLibrary
