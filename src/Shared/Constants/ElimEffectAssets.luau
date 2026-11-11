--[[
	ElimEffectAssets

	Description:
	Image and sound ids used by the elimination effects ("Strike Effects") in Client/Core/ElimEffectController/Effects.
	From the client's scripter package (reference/ScripterPackage, Assets.KillFx). The images were uploaded by the
	client's account; the sounds are Creator Store sounds. If one doesn't load in a live server, re-upload it under
	the experience owner and replace the id here.
]]

return {
	-- // Images
	-- // Cartoon flames: one flame per image, rounded base at image left (Beam Attachment0), curved tapered tip at the
	-- // right; A and B curl opposite ways.
	FlameA = "rbxassetid://88714137915694",
	FlameB = "rbxassetid://96229182291445",
	Ember = "rbxassetid://94383239956362", -- // Small rounded square (tinted)
	Puff = "rbxassetid://132813702120922", -- // Soft round puff for smoke and dust (tinted)
	Flake = "rbxassetid://80083509926170", -- // Irregular flake / chunk (tinted)
	Cracks = "rbxassetid://99406278253599", -- // Thin dark cracks, applied as decals on the stone statue
	Petal = "rbxassetid://83014691223087", -- // Sakura petal (notched tip, stronger pink at the base)
	FlowerCenter = "rbxassetid://108239980750884", -- // Sakura centre with stamens
	Ring = "rbxassetid://128250807147873", -- // Thin white ring (ripples)
	WaterHole = "rbxassetid://92025769928549", -- // Water opening seen from above
	Droplet = "rbxassetid://121620197123677", -- // Chunky pale-blue droplet
	Splash = "rbxassetid://94868073821415", -- // Cartoon water crown spike
	Teeth = "rbxassetid://84209784349334", -- // Row of seven white triangular teeth (image up = into the mouth)

	-- // Sounds (Creator Store). The swooshes are the main sounds and play loudest.
	Swoosh = "rbxassetid://9120653862", -- // Fat, deep, airy whoosh (pitched down for stone)
	FireSwoosh = "rbxassetid://2741718865", -- // Fire blast rush
	StoneGrind = "rbxassetid://1334583496",
	StoneClunk = "rbxassetid://9118616114",
	StoneCrumble = "rbxassetid://9118770616",
	FireCrackle = "rbxassetid://108689534998891",
	AshCollapse = "rbxassetid://9118770617",
	AirySwoosh = "rbxassetid://76241725980727", -- // Soft wind woosh (sakura)
	FireRoar = "rbxassetid://9040280284", -- // White-noise whoosh with a low rumble, layered under the fire swoosh
	Gulp = "rbxassetid://90087825083279", -- // Cartoon "glup" (shark), ~0.2 s audible after a short silent lead-in
	GulpLeadIn = 0.07, -- // Seconds of silence at the start of Gulp (skipped on playback)
	Rumble = "rbxassetid://9120348019", -- // Underwater movement
	SplashBig = "rbxassetid://9125703162",
	SplashSmall = "rbxassetid://9125702803",
	Chomp = "rbxassetid://9119056218", -- // Shark teeth snap
}
