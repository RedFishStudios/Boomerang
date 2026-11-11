-- Uploaded image asset ids. Art is cut from the "Official Boomerang! UI" mockups (background removed). Icons on the
-- tiles, coin plank, close buttons, quest tabs and Gift buttons are the vector set in art/icons (painted over the old ones).

local Assets = {}

-- Left-side HUD (mockup v2, page 2). The coin plank has its number painted out; the count is live text.
-- Tiles are three same-size layers (art/left-hud/tile_<name>_{bg,icon,ribbon}.png): framed background with no icon,
-- the large icon clipped to the coloured interior, and the name ribbon with its label (drawn over the icon).
Assets.LeftHud = {
	Coins = "rbxassetid://92623373586205",
	Inventory = {
		Bg = "rbxassetid://107933567065556", -- interior repainted as one rounded panel, frame cleaned
		Icon = "rbxassetid://87222260817902",
		Ribbon = "rbxassetid://115409735230432",
	},
	Shop = {
		Bg = "rbxassetid://107809823827340",
		Icon = "rbxassetid://139232895555907",
		Ribbon = "rbxassetid://124188475504187",
	},
	Index = {
		Bg = "rbxassetid://88400410898617",
		Icon = "rbxassetid://108417862179805",
		Ribbon = "rbxassetid://104670735977469",
	},
	Quests = {
		Bg = "rbxassetid://82982471343448",
		Icon = "rbxassetid://81494824168101",
		Ribbon = "rbxassetid://138863946360885",
	},
	Stats = "rbxassetid://87777044350124", -- AFK's wood frame and vines, one continuous teal interior, bar-chart icon, "Stats"
	-- AFK slide toggle (from the AFK toggle mockups): wooden frame with "AFK" and an empty slot, green (on) and red
	-- (off) tracks, and a knob that slides between them.
	AfkFrame = "rbxassetid://109934974740266",
	AfkTrackOn = "rbxassetid://128081804518008",
	AfkTrackOff = "rbxassetid://140404332176286",
	AfkKnob = "rbxassetid://85483530910661",
}

-- Inventory window (mockup v2, page 4, "Your Skins"). The window has its title, cards and detail-panel contents
-- painted out; tabs and the close button are overlays of the same art so they can animate. Equip button and cards
-- have their text painted out.
Assets.InventoryScreen = {
	Window = "rbxassetid://136938074765012",
	TabSkins = "rbxassetid://93310367572638",
	TabTaunts = "rbxassetid://119191024307011",
	TabArrows = "rbxassetid://112870876445278",
	TabKillEffects = "rbxassetid://106078057715342",
	Close = "rbxassetid://80939948956702",
	Equip = "rbxassetid://132460269560761",
	Equipped = "rbxassetid://98784855760472", -- grey copy of Equip
	CardNormal = "rbxassetid://116087380238399",
	CardSelected = "rbxassetid://99224325157096",
	CardEquipped = "rbxassetid://92633980617370", -- hue-shifted CardSelected
	Check = "rbxassetid://103175301119608",
}

-- Boomerang skin art, background removed.
Assets.Skins = {
	Bronzeguin = "rbxassetid://114825971223690",
	Default = "rbxassetid://82042595323457",
	Chubby = "rbxassetid://119665808232622",
	-- Garbage Egg skins, cut from the Shop mockup.
	PaperMecha = "rbxassetid://88332656317169",
	LunchBagSpy = "rbxassetid://98885008973120",
	CptRed = "rbxassetid://95217745189805",
	ParaBottler = "rbxassetid://131291360489061",
}

-- Shop window (mockup v2, page 5). Gem count and timer are painted out (live text); Gift and price buttons and the
-- close button are overlays of the same art.
Assets.ShopScreen = {
	Window = "rbxassetid://107063472569743",
	Close = "rbxassetid://136930628459636",
	Gift = {
		"rbxassetid://129754881479623",
		"rbxassetid://118945129006578",
		"rbxassetid://100975111507840",
		"rbxassetid://134636522116232",
	},
	Buy = {
		"rbxassetid://96557438223438",
		"rbxassetid://104327459906632",
		"rbxassetid://112444224820995",
		"rbxassetid://86593269032324",
	},
}

-- Quests window (mockup v2, page 5). Timer, card titles, reward amounts and progress text are painted out; the
-- progress bars are empty. Tabs have on (blue) / off (brown) versions; the card button has grey and green versions.
Assets.QuestsScreen = {
	Window = "rbxassetid://122319879631888",
	Close = "rbxassetid://129567222414141",
	TabDailyOn = "rbxassetid://95316478635524",
	TabDailyOff = "rbxassetid://71216361359559",
	TabWeeklyOn = "rbxassetid://119790831716286",
	TabWeeklyOff = "rbxassetid://74507956007532",
	TabSeasonOn = "rbxassetid://81884349454195",
	TabSeasonOff = "rbxassetid://124016271228124",
	ButtonGrey = "rbxassetid://131710866567888",
	ButtonGreen = "rbxassetid://87354740878901",
}

-- Stats window (art/stats, from the supplied Stats mockup). Avatar, names and all numbers are painted out (live);
-- the close button is a separate overlay. Layout in art/stats/layout.txt.
Assets.StatsScreen = {
	Window = "rbxassetid://117972552516440", -- art/stats/window.png, clean vine edges (the previous cut was 80344166363694)
	Close = "rbxassetid://99387041915365",
}

-- Placeholder item art: cut from the tab icons, with tinted copies for variety. Swap for designer art.
Assets.Taunts = {
	Laugh = "rbxassetid://127410866517037",
	Flex = "rbxassetid://110494031510556",
	Dance = "rbxassetid://99346101856261",
}

Assets.Arrows = {
	Classic = "rbxassetid://107698805529915",
	Gold = "rbxassetid://108384880690283",
	Frost = "rbxassetid://90865724950757",
}

-- Kill effect visuals (Client.KillEffects). Textures are drawn from fixed shapes/seeds so every death looks the same.
Assets.KillFx = {
	-- Cartoon flames (art/kill-effects/FlameGen.cs): one flame per image, rounded base at image left (Beam
	-- Attachment0), curved tapered tip at the right; A and B curl opposite ways.
	FlameA = "rbxassetid://88714137915694",
	FlameB = "rbxassetid://96229182291445",
	Ember = "rbxassetid://94383239956362", -- small rounded square (tinted)
	Puff = "rbxassetid://132813702120922", -- soft round puff for smoke and dust (tinted)
	Flake = "rbxassetid://80083509926170", -- irregular flake / chunk (tinted)
	Cracks = "rbxassetid://99406278253599", -- thin dark cracks, applied as decals on the stone statue
	Petal = "rbxassetid://83014691223087", -- sakura petal (notched tip, stronger pink at the base)
	FlowerCenter = "rbxassetid://108239980750884", -- sakura centre with stamens
	Ring = "rbxassetid://128250807147873", -- thin white ring (ripples)
	WaterHole = "rbxassetid://92025769928549", -- water opening seen from above
	Droplet = "rbxassetid://121620197123677", -- chunky pale-blue droplet
	Splash = "rbxassetid://94868073821415", -- cartoon water crown spike
	Teeth = "rbxassetid://84209784349334", -- row of seven white triangular teeth (image up = into the mouth)
	-- Sounds (Creator Store). The SWOOSHes are the main sounds and play loudest.
	Swoosh = "rbxassetid://9120653862", -- fat, deep, airy whoosh (pitched down for stone)
	FireSwoosh = "rbxassetid://2741718865", -- fire blast rush
	StoneGrind = "rbxassetid://1334583496",
	StoneClunk = "rbxassetid://9118616114",
	StoneCrumble = "rbxassetid://9118770616",
	FireCrackle = "rbxassetid://108689534998891",
	AshCollapse = "rbxassetid://9118770617",
	AirySwoosh = "rbxassetid://76241725980727", -- soft wind woosh (sakura)
	FireRoar = "rbxassetid://9040280284", -- white-noise whoosh with a low rumble, layered under the fire SWOOSH
	-- Cartoon "glup" (shark): a short clean tonal blorp, pitch rising ~280 -> ~940 Hz then dropping, no wet or noisy
	-- content (measured with an AudioAnalyzer). ~0.2 s audible after ~0.07 s of lead-in silence; ~0.28 s at the 0.8
	-- playback speed the shark uses.
	Gulp = "rbxassetid://90087825083279",
	GulpLeadIn = 0.07, -- seconds of silence at the start of Gulp (skipped on playback)
	Rumble = "rbxassetid://9120348019", -- underwater movement
	SplashBig = "rbxassetid://9125703162",
	SplashSmall = "rbxassetid://9125702803",
	Chomp = "rbxassetid://9119056218", -- shark teeth snap
}

Assets.KillEffects = {
	Skull = "rbxassetid://75872067653950",
	Stone = "rbxassetid://102302090252595", -- skull turned to cracked stone
	Ashes = "rbxassetid://135143054207331", -- charcoal skull in the effect's flames
	Sakura = "rbxassetid://137908369916180", -- five-petal blossom
	Shark = "rbxassetid://113492942953005", -- cartoon shark breaching
}

return Assets
