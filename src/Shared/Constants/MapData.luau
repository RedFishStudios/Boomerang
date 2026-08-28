local Gamemodes = require(script.Parent.Parent.Constants.Gamemodes)

export type MapData = {
   Id: string,
   ForGamemodes: {string},
   DisguiseAssets: {string},
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
         Gamemodes.TeamElimination.Id
      },
      DisguiseAssets = {},
   },
   ["GenericA"] = {
      Id = "GenericA",
      ForGamemodes = {
         Gamemodes.Classic.Id,
         Gamemodes.Elimination.Id,
         Gamemodes.HotPotato.Id,
         Gamemodes.TeamElimination.Id
      },
      DisguiseAssets = {},
   },
   ["GenericB"] = {
      Id = "GenericB",
      ForGamemodes = {
         Gamemodes.Classic.Id,
         Gamemodes.Elimination.Id,
         Gamemodes.HotPotato.Id,
         Gamemodes.TeamElimination.Id
      },
      DisguiseAssets = {},
   },
   ["GenericC"] = {
      Id = "GenericC",
      ForGamemodes = {
         Gamemodes.Classic.Id,
         Gamemodes.Elimination.Id,
         Gamemodes.HotPotato.Id,
         Gamemodes.TeamElimination.Id
      },
      DisguiseAssets = {},
   },
   ["GenericD"] = {
      Id = "GenericD",
      ForGamemodes = {
         Gamemodes.Classic.Id,
         Gamemodes.Elimination.Id,
         Gamemodes.HotPotato.Id,
         Gamemodes.TeamElimination.Id
      },
      DisguiseAssets = {},
   },
   ["GenericE"] = {
      Id = "GenericE",
      ForGamemodes = {
         Gamemodes.Classic.Id,
         Gamemodes.Elimination.Id,
         Gamemodes.HotPotato.Id,
         Gamemodes.TeamElimination.Id
      },
      DisguiseAssets = {},
   }
}

return MapData