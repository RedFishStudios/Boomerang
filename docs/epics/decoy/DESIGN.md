# Decoy / NPC-Bot system: Design

- **Status:** Discovery · **Priority:** P2 · **Update:** next client update
- **Stages:** single pass *(revisit if a prototype -> full split helps)*

How to use this file: Sol and the agent fill in each section during Discovery. `TODO (human review)` means not written yet; `OPEN:` means undecided. **Agents never decide these.** When Sol approves the design, set Status to Approved and write the tasks into [TASKS.md](TASKS.md). Decisions so far are tagged (Sol, 2026-10-09).

---

## 0. Epic or General tasks?

**Epic** (Sol, 2026-10-09). It adds a new *entity type* — a bot that looks and moves like a player but isn't one — spanning characters, movement, collision, hitboxes, animation and replication. Built as a thin server-authoritative **bot layer** with the Decoy as its first behavior, so a later NPC/bot system is a natural extension rather than a rewrite (Sol, 2026-10-09).

## 1. Player experience

The Decoy pickup spawns a convincing copy of the player that wanders off, baiting enemies into attacking it. First pass: the decoy spawns on the player's **first throw after pickup** — the pickup effect is **consumed at spawn**, so one pickup yields exactly **one** decoy. It **faces the direction the player was facing at spawn** but **moves opposite the player's movement at spawn**, so it strafes (facing and movement differ), collides with the environment like a player, and despawns after a few seconds. An **enemy** can **hit/eliminate it** — it's treated as on its owner's team, so there's no friendly fire and the owner can never hurt their own decoy; when hit it **poofs into a smoke particle** (Sol, 2026-10-09).

## 2. Scope

- **What it affects:** a new bot entity + `BotService`/`BotController`; the Decoy pickup (`PickupLogics/Decoy`); server-side hit detection; client->client replication.
- **Integration points:** `PickupLogics/Decoy`, `SharedTasks.WeaponThrownTasks` (first-pass trigger), the character render pipeline (`CharacterRenderController` + the Animate pose system) reused for bot visuals, collision (`CollisionService` / `DynamicCollisionLibrary` / `EnvironmentService`), the server hitbox (`HitboxService`), team checks (`GameTeamService` / `GameTeamLibrary`), and round/owner cleanup (`RoundCyclingService` / `RoundFinishedTasks` / `PlayerRemoving`). Keep changes small.
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
- **Appearance:** matches the owning player; **built client-side by cloning the same character model the client already builds for players** (reuse `CharacterRenderController`'s model build) rather than re-fetching avatar info or rebuilding a humanoid (Sol, 2026-10-09).
- **Trigger (flexible):** first pass spawns on the player's boomerang throw via `SharedTasks.WeaponThrownTasks`, and the **pickup effect is removed at spawn** (one pickup = one decoy). Later triggers: on-pickup, or a dedicated activation button (reusing the Abilities input pattern). The spawn cause is one swappable hook so the decoy/bot logic doesn't change.
- **Hit -> poof:** the decoy uses the **same hitbox as player characters via `HitboxService`** (Sol, 2026-10-09); a boomerang hit from an **enemy** eliminates it and it despawns with a client-side smoke particle (T-078). Treated as on its owner's team, so same-team weapons/abilities can't hurt it and the owner never can (team check via `GameTeamService` / `GameTeamLibrary.areEnemies`, plus an explicit owner guard).
- **Movement / collision:** players collide via a single **collision part at the body's centre**, assigned to the player-characters **collision group**; Roblox **physics** on that part resolves environment collisions (Sol, 2026-10-09). The bot reuses this: a **server-owned collision part in the same collision group**, moved by the server; Roblox replicates that part's position to all clients, and each client renders the avatar following it. The decoy **faces the player's facing at spawn** and **moves opposite the player's movement direction at spawn** (facing decoupled from movement — it strafes). Sitting in the player collision group gives it the same environment collision as players (and the same player-vs-player behaviour that group already has). It lives **4 seconds** (a tunable constant) then despawns. If the player is **standing still** at spawn, it picks a **random** move direction (Sol, 2026-10-09).
- **Cleanup:** despawn after 4 seconds; also on round end, owner death, owner leaving.
- **Switch-off while in progress:** the Decoy pickup stays `Disabled = true` until ready.

## 8. Order of work

`TODO (human review)` after DESIGN approval. Rough sketch (not tasks yet): bot layer (spawn -> replicate -> client render -> despawn) -> decoy wander + strafe + environment collision -> hit -> poof -> trigger on throw -> cleanup & perf pass.

## 9. Testing

Sol tests in Studio. A Cmdr command to spawn a decoy on demand (add a task). `OPEN:` what else needs a dev command.

## 10. Out of scope (first pass)

Other triggers (on-pickup, activation button), pathfinding / rich AI, a general NPC behavior library beyond the decoy, and any decoy combat beyond "can be hit -> poof".

## 11. Open questions

- `OPEN:` confirm the epic's **priority** (defaulted to P2 from the T-010 pickup).
- `OPEN:` does eliminating a decoy count toward the attacker's **stats**? (likely no.)
- `OPEN:` performance at scale — many players each with a decoy at once; any cap or spacing needed? (At most one decoy per player at a time.)
