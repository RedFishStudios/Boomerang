local Gamemodes = require(script.Parent.Parent.Constants.Gamemodes)

export type MapData = {
   Id: string,
   ForGamemodes: {string},
   DisguiseAssets: {string},
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
         Gamemodes.TeamClassic.Id
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
         Gamemodes.TeamClassic.Id
      },
      DisguiseAssets = {},
   },
   ["GenericB"] = {
      Id = "GenericB",
      ForGamemodes = {
         Gamemodes.Classic.Id,
         Gamemodes.Elimination.Id,
         Gamemodes.HotPotato.Id,
         Gamemodes.TeamElimination.Id,
         Gamemodes.TeamClassic.Id
      },
      DisguiseAssets = {},
   },
   ["GenericC"] = {
      Id = "GenericC",
      ForGamemodes = {
         Gamemodes.Classic.Id,
         Gamemodes.Elimination.Id,
         Gamemodes.HotPotato.Id,
         Gamemodes.TeamElimination.Id,
         Gamemodes.TeamClassic.Id
      },
      DisguiseAssets = {},
   },
   ["GenericD"] = {
      Id = "GenericD",
      ForGamemodes = {
         Gamemodes.Classic.Id,
         Gamemodes.Elimination.Id,
         Gamemodes.HotPotato.Id,
         Gamemodes.TeamElimination.Id,
         Gamemodes.TeamClassic.Id
      },
      DisguiseAssets = {},
   },
   ["GenericE"] = {
      Id = "GenericE",
      ForGamemodes = {
         Gamemodes.Classic.Id,
         Gamemodes.Elimination.Id,
         Gamemodes.HotPotato.Id,
         Gamemodes.TeamElimination.Id,
         Gamemodes.TeamClassic.Id
      },
      DisguiseAssets = {},
   }
}

return MapData