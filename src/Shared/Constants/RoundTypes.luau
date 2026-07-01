-- // Defines the types of rounds and their functionality
-- DOCU: https://docs.google.com/document/d/15GWFwrjrhytRjPqBhBg-Zhc5YLX9CeWJlt8Q_rMttss/edit?tab=t.d4ujxm3y7eay

export type RoundType = {
   Id: string,
   CanLateJoin: boolean
}

-------------------------------------------------------------------------------
-- PUBLIC VARIABLES
-------------------------------------------------------------------------------

local RoundTypes: {
   [string]: RoundType
} = {
   Classic = {
      Id = "Classic",
      CanLateJoin = true
   }
}

return RoundTypes