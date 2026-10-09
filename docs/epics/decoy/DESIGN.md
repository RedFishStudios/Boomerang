# Decoy / NPC-Bot system: Design

- **Status:** Discovery · **Priority:** P2 · **Update:** next client update
- **Stages:** single pass *(revisit if a prototype -> full split helps)*

How to use this file: Sol and the agent fill in each section during Discovery. `TODO (human review)` means not written yet; `OPEN:` means undecided. **Agents never decide these.** When Sol approves the design, set Status to Approved and write the tasks into [TASKS.md](TASKS.md). Decisions so far are tagged (Sol, 2026-10-09).

---

## 0. Epic or General tasks?

**Epic** (Sol, 2026-10-09). It adds a new *entity type* — a bot that looks and moves like a player but isn't one — spanning characters, movement, collision, hitboxes, animation and replication. Built as a thin server-authoritative **bot layer** with the Decoy as its first behavior, so a later NPC/bot system is a natural extension rather than a rewrite (Sol, 2026-10-09).

## 1. Player experience

The Decoy pickup spawns a convincing copy of the player that wanders off, baiting enemies into attacking it. First pass: the decoy spawns **when the player throws their boomerang**. It wanders in a set direction, **strafing** (faces one way, moves another), collides with the environment like a player, and despawns after a few seconds. An enemy can **hit/eliminate it**; when hit it **poofs into a smoke particle** (Sol, 2026-10-09).

## 2. Scope

- **What it affects:** a new bot entity + `BotService`/`BotController`; the Decoy pickup (`PickupLogics/Decoy`); server-side hit detection; client->client replication.
- **Integration points:** `PickupLogics/Decoy`, `SharedTasks.WeaponThrownTasks` (first-pass trigger), the character render pipeline (`CharacterRenderController` + the Animate pose system) reused for bot visuals, collision (`CollisionService` / `DynamicCollisionLibrary` / `EnvironmentService`), the server hitbox/combat path, and round/owner cleanup (`RoundCyclingService` / `RoundFinishedTasks` / `PlayerRemoving`). Keep changes small. `OPEN:` exact movement/collision reuse (see §7 — needs recon).
- **Assets needed:** a smoke particle for the poof on hit — Sol provides (Backlog **T-078**).
- **Size:** `TODO (human review)` — rough task count after DESIGN approval.

## 3. Performance budget

Server stays **lightweight**: it owns only the bot's authoritative transform and hitbox and replicates spawn/despawn/transform between clients; **clients build and animate the full avatar** (Sol, 2026-10-09). No per-accessory server replication. Replication modeled on the existing thrown-weapon snapshots (event-driven, not per-frame remotes). `OPEN:` concurrent-decoy cap; replication rate.

## 4. Save data

None expected — decoys are transient. `TODO (human review)` if a decoy variant is ever saved.

## 5. Economy

None.

## 6. Revenue

- **Focus:** none.

## 7. Implementation

- **Bot layer:** `BotService` (server) owns live bots (id, owner, authoritative CFrame, move direction, facing, lifetime, hitbox) and steps them; `BotController` (client) builds, renders and animates bot models, reusing the player render pipeline and the Animate pose system. A `BotBehavior` interface (`start` / `update` / `shouldDespawn`); **Decoy is the first behavior**.
- **Appearance:** matches the owning player; **built client-side** (Sol, 2026-10-09). `OPEN:` how a client obtains the owner's exact appearance (equipped skin / avatar) for a non-player id.
- **Trigger (flexible):** first pass spawns on boomerang throw via `SharedTasks.WeaponThrownTasks`. Later: on-pickup, or a dedicated activation button (reusing the Abilities input pattern). The spawn cause is one swappable hook so the decoy/bot logic doesn't change.
- **Hit -> poof:** a server-side hitbox lets a boomerang eliminate the decoy; on elimination it despawns with a client-side smoke particle (T-078). `OPEN:` reuse `CombatService`/`HitboxService` vs a dedicated bot hitbox; whether a hit counts toward stats (likely no).
- **Movement / collision:** wander in a set direction, strafe; collide with the environment like a player. `OPEN (needs recon):` how player movement + environment collision work today and how much the bot reuses (custom server movement vs Humanoid physics).
- **Cleanup:** despawn after N seconds; also on round end, owner death, owner leaving.
- **Switch-off while in progress:** the Decoy pickup stays `Disabled = true` until ready.

## 8. Order of work

`TODO (human review)` after DESIGN approval. Rough sketch (not tasks yet): bot layer (spawn -> replicate -> client render -> despawn) -> decoy wander + strafe + environment collision -> hit -> poof -> trigger on throw -> cleanup & perf pass.

## 9. Testing

Sol tests in Studio. A Cmdr command to spawn a decoy on demand (add a task). `OPEN:` what else needs a dev command.

## 10. Out of scope (first pass)

Other triggers (on-pickup, activation button), pathfinding / rich AI, a general NPC behavior library beyond the decoy, and any decoy combat beyond "can be hit -> poof".

## 11. Open questions

- `OPEN:` the "set direction" the decoy wanders (player facing at spawn / opposite the throw / away from nearest enemy / random?).
- `OPEN:` facing while strafing (fixed to the player's spawn facing? toward a point?).
- `OPEN:` lifetime length; one decoy per throw, or an effect window that spawns one on each throw for a duration?
- `OPEN:` does the decoy collide with players / other decoys, or only the environment?
- `OPEN:` hit-detection reuse (`CombatService`/`HitboxService`) and whether a hit affects stats.
- `OPEN:` how a client reconstructs the owner's exact appearance for the bot.
- `OPEN:` team modes (team color?) and Assassin interaction.
- `OPEN:` confirm the epic's priority (defaulted to P2 from the T-010 pickup).
- `OPEN:` concurrent-decoy cap and replication rate (performance).
