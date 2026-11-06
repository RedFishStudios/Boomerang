-- // Cmdr type "boomerangdebugsetting": which boomerang debug switch the boomerangdebug command changes.
-- // Registered by CmdrService and replicated to clients, so it must not require server modules.
return function(registry)
	registry:RegisterType("boomerangdebugsetting", registry.Cmdr.Util.MakeEnumType("boomerangdebugsetting", { "log", "walk", "walkradius", "noreturn", "throw", "recall" }))
end
