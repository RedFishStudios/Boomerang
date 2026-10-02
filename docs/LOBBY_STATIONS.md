# Lobby stations

A **lobby station** is any interactable spot in the lobby: shop pedestals, prize wheel, crates, the group chest, the server portal, ad/promo boards, and so on. They all share one framework (built in T-047), so **a new lobby interactable is a station, not a new system**. Station-specific code only says *what happens* and *what state each player sees*. The framework does the rest.

What the framework gives every station automatically:
- a world-space **title** above it (BillboardGui, client-side),
- a **glowing pad** under it (a pulsing PointLight on its `Pad` part, brighter while the player is in range, dimmed when the station is locked/claimed for that player),
- a **proximity prompt** whose trigger runs a server handler,
- **per-player state** (locked, claimed, different prompt text or title, prompt hidden) set by the server and replicated to that player only,
- **client hooks** for when the player walks up to or away from a station (e.g. to show an odds panel).

Spec for the stations themselves: [LOBBY_SPEC.md](LOBBY_SPEC.md). Lobby tasks: [epics/lobby/TASKS.md](epics/lobby/TASKS.md).

## Files

| File | Side | Role |
|---|---|---|
| `src/Shared/Library/LobbyStationLibrary.luau` | Both | Tag, attribute names and defaults, the `StationState` type, helpers to find a station's parts. The header comment is the attribute reference. |
| `src/Server/Core/LobbyStationService.luau` | Server | Creates the prompts, runs handlers, stores and replicates per-player state. |
| `src/Client/Core/LobbyStationController.luau` | Client | Title, pad glow, applies state to the prompt/title, approach hooks. Visual constants (font, label size, glow strength) are at the top. |
| `src/Server/Cmdr/Commands/SetStationState*.luau` | Server | Cmdr command for testing states. |

**Don't put station-specific code in these files.** Each station gets its own modules (see below).

## The station in Studio (place-only content)

The lobby lives only in the Studio place (`workspace.Lobby`, built by Sol), so stations are set up in Studio, not in the repo. Sol provides the models and art.

1. Put the station's Model (or a single BasePart) anywhere under `workspace.Lobby`.
2. Add the CollectionService tag **`LobbyStation`** to the Model (or part).
3. Set its attributes:

| Attribute | Type | Default | Meaning |
|---|---|---|---|
| `StationId` | string | **required** | Which handler runs, and which per-player state applies. Several instances may share one id (they share handler and state). Treat it as a permanent ID once shipped. |
| `Title` | string | none | Floating label text. No label when empty. |
| `ActionText` | string | `"Interact"` | Prompt action text. |
| `HoldDuration` | number | `0` | Prompt hold time (seconds). |
| `MaxDistance` | number | `10` | Prompt activation distance (studs). |
| `PromptPart` | string | PrimaryPart / first BasePart | Name of the descendant part that holds the prompt and the label. |
| `PadPart` | string | `"Pad"` | Name of the descendant part that glows. No glow if it doesn't exist. |
| `TitleHeight` | number | `2` | Studs between the top of the station and the label. |

**Agents with the Roblox Studio MCP:** only change the place when the task (or Sol) asks for it. Call `list_roblox_studios` and use "Boomerang [Development]" (placeId 74945725552268). Never save or publish the place; Sol does. Use `CollectionService:AddTag(model, "LobbyStation")` and `model:SetAttribute(...)` in `execute_luau` (Edit datamodel). The pad's colour sets the glow colour.

## Adding a station's behaviour (code)

Create a service (server) and, only if the station needs client-side visuals beyond the framework, a controller (client). Name them so the boot script loads them (`...Service` / `...Controller`, case-sensitive) and start from the module template. Example for a station with `StationId = "PrizeWheel"`:

### Server: `src/Server/Core/PrizeWheelService.luau`

```lua
local PrizeWheelService = {}

local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local LobbyStationService = require(ServerStorage.Server.Core.LobbyStationService)
local PlayerDataService = require(ServerStorage.Server.Core.PlayerDataService)

local STATION_ID = "PrizeWheel"

-- // Recompute what this player should see (call on join, after data loads, and after anything that changes it)
local function refreshState(player: Player)
	local canSpin = true -- read the player's data / cooldown here
	LobbyStationService.setPlayerState(player, STATION_ID, if canSpin
		then { State = "Active", ActionText = "Spin" }
		else { State = "Claimed", ActionText = "Come back later", PromptEnabled = false })
end

local function onTriggered(player: Player, station: Instance)
	-- // ALWAYS re-validate here: the client can't be trusted (cooldown, currency, ownership...)
	-- // Do the work (EconomyService / ItemService / PlayerDataService.get), then refresh the state
	refreshState(player)
end

function PrizeWheelService.start()
	LobbyStationService.registerHandler(STATION_ID, onTriggered)
	-- // + call refreshState for current and future players once their data is loaded
end

return PrizeWheelService
```

Register handlers in `start()` (not at the top level), since `LobbyStationService` must have run its `init()`.

### Per-player state (`LobbyStationLibrary.StationState`)

All fields are optional. `nil` (or `setPlayerState(player, id, nil)`) means "defaults from the attributes".

| Field | Effect |
|---|---|
| `State` | Free-form name owned by your station (`"Active"`, `"Locked"`, `"Claimed"`...). The framework only uses it to **dim the pad** when it is set and isn't `"Active"`. Your client code can read it for anything else. |
| `PromptEnabled` | `false` hides the prompt for that player, and the server ignores their triggers. |
| `ActionText` | Overrides the prompt text for that player. |
| `Title` | Overrides the floating title for that player. |

- `setPlayerState` replaces the whole state (it doesn't merge). Send every field you want.
- State is **not saved**. It lives in memory for the session, so recompute it from saved data (`PlayerDataService`) when the player joins/their data loads, and whenever it changes. Late-joining clients receive the current state automatically.
- `LobbyStationService.getPlayerState(player, id)` reads it back.

### Client: `src/Client/Core/<Name>Controller.luau` (optional)

Only for extra visuals (odds panel, spin animation, locked/unlocked model look). The framework's client hooks:

```lua
local LobbyStationController = require(ReplicatedStorage.Client.Core.LobbyStationController)

LobbyStationController.ApproachedTasks:Add(function(stationId, station)
	if stationId ~= "ExplosionCrate" then return end
	-- // show the odds panel near `station`
end)
LobbyStationController.LeftTasks:Add(function(stationId, station) ... end) -- hide it
LobbyStationController.StateChangedTasks:Add(function(stationId, state) ... end) -- e.g. open/close the chest lid
LobbyStationController.getState(stationId) -- current state for this player
```

"Approached/Left" follow the prompt being shown/hidden, so they fire only while the prompt is enabled for that player.

If a station needs its own remotes (e.g. to tell the client the wheel result for an animation), create them with `SimpleRemotes` in the station's service, as usual.

## Rules the framework already enforces

- Triggers only count when the player's character is **in the lobby** (`LobbyLibrary.isCharacterInLobby`).
- **0.5 s cooldown** per player across all stations.
- **One handler per `StationId`.** Registering again replaces it (with a warning).
- An unhandled `StationId` warns once in Studio and is otherwise ignored.
- Works with **StreamingEnabled**: the client sets stations up as they stream in and cleans them up when they stream out. Don't cache station parts on the client for long.

## Testing (Cmdr, F2)

| Command | What it does |
|---|---|
| `setstationstate <players> <stationId> <state> [promptEnabled]` | Sets a state for players. `state = clear` resets it. Example: `setstationstate me PrizeWheel Locked false` hides the prompt and dims the pad. `setstationstate me PrizeWheel clear` puts it back. |

When a station's behaviour is hard to reach by playing (cooldowns, group membership, purchases), add a Cmdr command for it (e.g. reset that station's cooldown) and say which one to use in the task Notes. See "Developer commands" in CLAUDE.md.

**Quick check for a new station:** play, walk up to it. You should see the title, the glow brightening and the prompt. Trigger it and check the handler's effect, then try the locked/claimed states with `setstationstate`.

## Not covered yet

- **Non-interactive signs/ads with no prompt:** every station currently gets a prompt (and the approach hooks rely on it). For a purely decorative board, ask Sol whether it should still be a station (e.g. a prompt that opens a shop) or whether the framework should get a "no prompt" option. Extend the framework rather than building a separate system.
- Station art, VFX and locked/unlocked model looks are per-station (Sol's models + the station's own controller).
