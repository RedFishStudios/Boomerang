local CollisionConstants = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GeneralUtil = require(ReplicatedStorage.Shared.Utils.GeneralUtil)

-------------------------------------------------------------------------------
-- TYPES
-------------------------------------------------------------------------------

export type Group = keyof<typeof(CollisionConstants.Groups)>

-------------------------------------------------------------------------------
-- PRIVATE VARIABLES
-------------------------------------------------------------------------------

local groups = GeneralUtil.deepFreeze({
	Default = "Default",
	Characters = "Characters",
	Debris = "Debris",
})

local relations: { [Group]: { Groups: { Group }, Collidables: { boolean } } } = {
	Debris = {
		Groups = { groups.Characters, groups.CarWheels, groups.CarBody, groups.Debris },
		Collidables = { false, false, false, false },
	},

	Characters = {
		Groups = { groups.Characters },
		Collidables = { false },
	},
}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

CollisionConstants.Groups = groups

-------------------------------------------------------------------------------
-- PUBLIC FUNCTIONS
-------------------------------------------------------------------------------

function CollisionConstants.getRelations(group: Group)
	return relations[group]
end

return CollisionConstants
