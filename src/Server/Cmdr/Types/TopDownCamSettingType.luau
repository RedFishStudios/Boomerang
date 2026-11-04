-- // Cmdr type "topdowncamsetting": which top-down camera value the topdowncam command changes (tilt, fov or distance).
-- // Registered by CmdrService and replicated to clients, so it must not require server modules.
return function(registry)
	registry:RegisterType("topdowncamsetting", registry.Cmdr.Util.MakeEnumType("topdowncamsetting", { "tilt", "fov", "distance" }))
end
