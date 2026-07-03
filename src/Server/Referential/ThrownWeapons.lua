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

   ReplicationPart: Part,
   
   MovementConnection: RBXScriptConnection?,
   TestRaycastVisualizers: {Part}
}

-- // Data for a thrown weapon out on the field
ThrownWeapons.Data = {} :: {
   [Player]: Data
}

return ThrownWeapons