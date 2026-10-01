# Lobby feature spec (from the client's reference screenshots)

Converted from `lobby_feature_spec_from_reference_screenshots.docx` (provided by Sol, 2026-10-01). Tasks: T-041 to T-047 and T-032 in TASKS.md. Player-facing text uses "eliminations", not "kills" (see CLAUDE.md).

**Purpose.** This document translates the supplied screenshots into an implementation-oriented inventory of physical lobby features. It intentionally ignores the HUD, player stats/currency UI, and other purely screen-space controls. It is written so an agentic development workflow can turn the inventory into tasks, while leaving ambiguous design choices for human confirmation.

**Reference rule.** Treat the screenshots as visual references, not as a requirement to reproduce exact art, branding, text, geometry, or assets. Where a mechanic is visible but its exact behavior is unknown, implement the physical interaction pattern only after confirming the intended behavior.

# 1. Physical lobby feature inventory

| Feature                               | Observed in reference                                                                                                                                                                                    | Implementation guidance                                                                                                                                                                                                                                      | Human confirmation                                                                                                                                                           |
|---------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Central lobby platform / hub          | Large floating/raised lobby platform with multiple themed interaction stations arranged around a central walkable area. The environment reads as a social hub rather than a conventional menu.           | Build a spacious central hub with clear walking lanes and stations placed around its perimeter. Keep important interactables visually distinct and reachable.                                                                                                | Exact layout, scale, world theme, and whether the lobby should float over an environment should be confirmed.                                                                |
| Prize / reward wheel                  | Large freestanding circular prize wheel on a pedestal. The wheel is divided into reward segments and visually presented as a physical object.                                                            | Create a world-space wheel prop with a visible center hub, segmented reward faces, and a supporting pedestal. Provide an interaction prompt/trigger and an animation state for spinning if the mechanic is required.                                         | Confirm reward categories, spin frequency/cost, whether the wheel is cosmetic or gameplay-affecting, and the desired spin animation.                                         |
| Explosion Crates area                 | Two physical crate stations are shown side-by-side: a premium-looking crate and a normal crate. The premium crate is visually more elaborate and has a floating label/interaction presentation above it. | Create a dedicated crate display area with at least two distinct crate variants, each on a small platform/pedestal. Give each crate a readable world-space name and interaction point.                                                                       | Confirm exact crate names, purchase currencies/costs, reward tables, and whether the crates should actually open in the lobby or only act as purchase points.                |
| Crate odds / information presentation | When approaching a crate, a floating panel appears above/near the physical crate showing rarity probabilities. The reference includes Rare, Legendary, and an extremely rare/unknown tier.               | Support a world-space information panel attached to or triggered by a crate. It should be possible to show rarity/odds information and an interaction prompt without relying on the main HUD.                                                                | Confirm whether exact odds are required, whether they vary by crate, and any legal/platform requirements for displaying randomized-item odds.                                |
| Sword Crate station                   | A separate physical crate station is shown later in the lobby. It has a different visual treatment from the explosion crates and is associated with sword-related rewards.                               | Add a distinct collectible/equipment crate station, visually separated from the explosion crate area. Use a pedestal/display treatment consistent with the rest of the hub.                                                                                  | Confirm whether this is specifically a sword loot box, equipment shop, or another reward system; confirm cost and contents.                                                  |
| Group Rewards chest                   | A large locked treasure chest sits on a glowing circular floor marker. A prominent world-space 'GROUP REWARDS' label identifies the station.                                                             | Create a large reward chest prop on a dedicated glowing activation pad, with a world-space station title. The chest should support an interactable/claim state and a locked/unlocked visual state.                                                           | Confirm whether rewards require joining a group/community, whether there is a cooldown, and what happens after claiming.                                                     |
| Server Selection portal               | A large sci-fi arch/portal stands on a glowing floor ring. A nearby world-space sign communicates that it leads to different game modes/worlds.                                                          | Create a prominent portal gateway with a glowing activation area and a nearby informational sign. The portal should support teleport/navigation to server, mode, or world selection.                                                                         | Confirm destination structure: server browser, game-mode selector, world selector, or a combination. Confirm whether selection happens physically or through a follow-up UI. |
| Leaderboards                          | Large physical leaderboard displays are placed together in the lobby. The reference clearly shows separate boards for 'Most Wins' and 'Most Kills', with ranked player rows.                             | Build two or more large world-space leaderboard panels on dedicated frames. Each board should support title, ranking number, player identity/display name, and score/value. Provide an obvious physical location where players can walk up and inspect them. | Confirm the complete leaderboard set, update frequency, all-time vs monthly/global/region scopes, and whether tabs are physical buttons or UI.                               |
| Leaderboard podium / \#1 display      | A physical display area in front of the leaderboards highlights a top-ranked player with a character/avatar standing on a small platform and a placard beneath/near them.                                | Add a small champion/podium display associated with the leaderboard area. Support showing a selected top player avatar and their relevant title/stat.                                                                                                        | Confirm whether this should always represent \#1 overall, rotate between leaderboards, or use a configurable featured player.                                                |
| Ambient lobby presentation            | The lobby uses glowing floor rings, neon accents, floating/large signage, themed props, soft environmental lighting, and a spacious elevated environment.                                                | Establish a coherent visual language for all stations: glowing activation pads, physical pedestals, oversized readable labels, and strong silhouettes for interactable props.                                                                                | Confirm target art direction, performance budget, lighting style, and whether visual similarity to the reference should be close or merely functionally analogous.           |

# 2. Suggested lobby layout

- **Primary central hub:** Keep a broad, uncluttered walkable zone in the middle.

- **Reward zone:** Place the prize wheel and reward-related stations where they are immediately visible from spawn.

- **Crate zone:** Group the Explosion Crates and Sword Crate into a recognizable shop/reward area, while keeping crate types visually distinct.

- **Social/reward zone:** Place Group Rewards in a visually prominent location with a clear activation pad.

- **Navigation zone:** Give the Server Selection portal a large amount of open space around its entrance so it reads as a destination.

- **Competition/social-status zone:** Place the Most Wins / Most Kills boards together, with the featured-player podium in front of or between them.

# 3. Interaction conventions to reproduce

- World-space labels above major interactables (station name/title rather than relying on the HUD).

- Physical pedestals/platforms beneath important props.

- Glowing circular or colored activation markers beneath interactable stations.

- Proximity-based interaction presentation: approaching an object reveals an interaction prompt or information panel.

- Large, readable signage for destinations such as Server Selection and Group Rewards.

- Locked/unlocked visual states for reward containers.

- Animated/active visual feedback for high-value stations (e.g., glowing rings, particles, floating effects).

# 4. Explicitly out of scope from these screenshots

- Screen-space HUD buttons such as Emote, AFK, Skills/Skins, Quests, Clans, Block, Ability, Spectate, settings, notifications, and currency counters.

- Top navigation/menu controls.

- HUD-only stats and counters.

- Any feature that is only visible as a menu overlay rather than a physical world object.

# 5. Unknowns / human decisions before implementation

- Whether the requested requirement means functional parity (same categories of lobby stations) or close visual/interaction parity.

- Exact reward economies, prices, probabilities, cooldowns, and inventory behavior for every crate/wheel/chest.

- Whether randomized crates are appropriate for the client's platform/audience and what disclosure requirements apply.

- What 'Server Selection' should actually navigate to in the client's game.

- Whether Group Rewards should require a community/group membership and what rewards it grants.

- Whether leaderboards are global, regional, monthly, all-time, or some combination, and which statistics are tracked.

- Whether the \#1 podium character should be a live player avatar, a cached avatar, or a generic showcase character.

- Exact art direction, colors, models, typography, VFX, and degree of visual differentiation from the reference.

- Spawn location and camera sightlines: which stations must be visible immediately after spawning.

# 6. Agentic implementation checklist

☐ Audit the existing lobby scene and identify reusable platform, portal, pedestal, VFX, and interaction systems.

☐ Block out the central hub and station positions before producing final art.

☐ Implement the prize wheel as a world-space interactable.

☐ Implement the two Explosion Crate variants and their world-space interaction/odds presentation.

☐ Implement the Sword Crate station.

☐ Implement the Group Rewards chest and claim-state visuals.

☐ Implement the Server Selection portal and destination flow.

☐ Implement the physical leaderboard boards and data refresh pipeline.

☐ Implement the featured/top-player podium display if approved.

☐ Add consistent glowing pads, station labels, interaction prompts, and visual feedback.

☐ Test walking paths, visibility, collision, camera readability, and station accessibility.

☐ Run a parity review against the supplied screenshots, while avoiding unnecessary copying of exact branded assets/art.

# 7. Definition of done

☐ A player can walk through the lobby and physically encounter every in-scope station listed above.

☐ Every major station has a recognizable physical prop, readable world-space identification, and an intentional interaction point.

☐ The lobby has distinct areas for rewards/crates, navigation, social rewards, and leaderboards.

☐ The environment contains the major physical presentation cues visible in the references: platforms, glowing rings, oversized signs, themed props, and ambient VFX.

☐ No required lobby feature depends on the HUD being visible.

☐ All unresolved economy, reward, navigation, data, and visual-design decisions have been confirmed by the human stakeholder before final implementation.

**Source note:** All observations in this document are derived from the four screenshots supplied in this conversation. Where behavior cannot be established from the images, the document intentionally marks it for confirmation rather than assuming implementation details.
