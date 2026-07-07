-- // Data on thrown weapons that exist in the field

local ThrownWeapons = {}

ThrownWeapons.StateEnum = {
   Outgoing = 1,
   Exhausted = 2,
   Returning = 3
} :: {
   ["Outgoing"]: number,
   ["Exhausted"]: number,
   ["Returning"]: number
}

export type Data = {
   ToolId: string,
   State: number,

   Host: Part | Model,
   
   MovementConnection: RBXScriptConnection?,
   TestRaycastVisualizers: {Part}
}

ThrownWeapons.Data = {} :: {
   [Player]: Data
}

return ThrownWeapons