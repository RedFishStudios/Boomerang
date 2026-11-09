local Gamemodes = require(script.Parent.Parent.Constants.Gamemodes)

export type MapData = {
   Id: string,
   ForGamemodes: {string},
   DisguiseAssets: {string}, -- Names of disguise asset models
   DisabledPickups: {string}?, -- Pickup Ids that are disabled on this map (ie. map has no water for water-based pickups)
   Debug: true?,
}

local MapData = {
   ["Debug"] = {
      Id = "Debug",
      Debug = true,
      ForGamemodes = {
         Gamemodes.Classic.Id,
         Gamemodes.Elimination.Id,
         Gamemodes.HotPotato.Id,
         Gamemodes.TeamElimination.Id,
         Gamemodes.TeamClassic.Id,
         Gamemodes.Assassin.Id
      },
      DisguiseAssets = {},
   },
   -- // Dev testing: a 600x600 open floor with only border walls (fast recalls, boomerang replication). Debug maps are only
   -- // played when picked with Cmdr `setnextmap TestField`
   ["TestField"] = {
      Id = "TestField",
      Debug = true,
      ForGamemodes = {
         Gamemodes.Classic.Id,
         Gamemodes.Elimination.Id,
         Gamemodes.HotPotato.Id,
         Gamemodes.TeamElimination.Id,
         Gamemodes.TeamClassic.Id,
         Gamemodes.Assassin.Id
      },
      DisguiseAssets = {},
   },
   -- // Dev testing: moving platforms players can stand on. Spawns on a still platform; a moving platform shuttles across
   -- // the gap beside it to a second platform
   ["MovingPlatformTest"] = {
      Id = "MovingPlatformTest",
      Debug = true,
      ForGamemodes = {
         Gamemodes.Classic.Id,
         Gamemodes.Elimination.Id,
         Gamemodes.HotPotato.Id,
         Gamemodes.TeamElimination.Id,
         Gamemodes.TeamClassic.Id,
         Gamemodes.Assassin.Id
      },
      DisguiseAssets = {},
   },
   ["GenericA"] = {
      Id = "GenericA",
      ForGamemodes = {
         Gamemodes.Classic.Id,
         Gamemodes.Elimination.Id,
         Gamemodes.HotPotato.Id,
         Gamemodes.TeamElimination.Id,
         Gamemodes.TeamClassic.Id,
         Gamemodes.Assassin.Id
      },
      DisguiseAssets = {},
   },
   --[[["GenericB"] = {
      Id = "GenericB",
      ForGamemodes = {
         Gamemodes.Classic.Id,
         Gamemodes.Elimination.Id,
         Gamemodes.HotPotato.Id,
         Gamemodes.TeamElimination.Id,
         Gamemodes.TeamClassic.Id,
         Gamemodes.Assassin.Id
      },
      DisguiseAssets = {},
   },]]
   ["GenericC"] = {
      Id = "GenericC",
      ForGamemodes = {
         Gamemodes.Classic.Id,
         Gamemodes.Elimination.Id,
         Gamemodes.HotPotato.Id,
         Gamemodes.TeamElimination.Id,
         Gamemodes.TeamClassic.Id,
         Gamemodes.Assassin.Id
      },
      DisguiseAssets = {},
   },
   ["PartsTest"] = {
      Id = "PartsTest",
      ForGamemodes = {
         Gamemodes.Classic.Id,
         Gamemodes.Elimination.Id,
         Gamemodes.HotPotato.Id,
         Gamemodes.TeamElimination.Id,
         Gamemodes.TeamClassic.Id,
         Gamemodes.Assassin.Id
      },
      DisguiseAssets = {},
   },
   ["TerrainTest"] = {
      Id = "TerrainTest",
      ForGamemodes = {
         Gamemodes.Classic.Id,
         Gamemodes.Elimination.Id,
         Gamemodes.HotPotato.Id,
         Gamemodes.TeamElimination.Id,
         Gamemodes.TeamClassic.Id,
         Gamemodes.Assassin.Id
      },
      DisguiseAssets = {},
   }
}

return MapData