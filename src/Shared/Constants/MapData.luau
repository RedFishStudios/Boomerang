local Gamemodes = require(script.Parent.Parent.Constants.Gamemodes)

export type MapData = {
   Id: string,
   ForGamemodes: {string},
   DisguiseAssets: {string},
}

local MapData = {
   ["Debug"] = {
      Id = "Debug",
      ForGamemodes = {
         Gamemodes.Classic.Id,
         Gamemodes.Elimination.Id,
         Gamemodes.HotPotato.Id
      },
      DisguiseAssets = {},
   },
   ["GenericA"] = {
      Id = "GenericA",
      ForGamemodes = {
         Gamemodes.Classic.Id,
         Gamemodes.Elimination.Id,
         Gamemodes.HotPotato.Id
      },
      DisguiseAssets = {},
   },
   ["GenericB"] = {
      Id = "GenericB",
      ForGamemodes = {
         Gamemodes.Classic.Id,
         Gamemodes.Elimination.Id,
         Gamemodes.HotPotato.Id
      },
      DisguiseAssets = {},
   },
   ["GenericC"] = {
      Id = "GenericC",
      ForGamemodes = {
         Gamemodes.Classic.Id,
         Gamemodes.Elimination.Id,
         Gamemodes.HotPotato.Id
      },
      DisguiseAssets = {},
   },
   ["GenericD"] = {
      Id = "GenericD",
      ForGamemodes = {
         Gamemodes.Classic.Id,
         Gamemodes.Elimination.Id,
         Gamemodes.HotPotato.Id
      },
      DisguiseAssets = {},
   },
   ["GenericE"] = {
      Id = "GenericE",
      ForGamemodes = {
         Gamemodes.Classic.Id,
         Gamemodes.Elimination.Id,
         Gamemodes.HotPotato.Id
      },
      DisguiseAssets = {},
   }
}

return MapData