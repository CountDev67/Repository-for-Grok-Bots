# Count Crackula — game1

Playable blockout of **Count Crackula: Sore-Foot Shift**. Two delivery routes, a cash ledger, and a three-pad porch. Placeholder parts only. The other team replaces the base and the art; this folder is the core loop.

## Run

From the repo root (or `cd game1` and drop the `game1/` prefix):

```bash
rojo build game1/default.project.json -o game1/build/CountCrackula.rbxlx
```

Open `game1/build/CountCrackula.rbxlx` in Roblox Studio and press Play.

Live sync, from `game1/`:

```bash
rojo serve
```

Connect the Rojo plugin to the default port. Tool versions are pinned in `rokit.toml` (Rojo 7.7.1, Lune 0.11.1, Selene 0.32.0, StyLua 2.6.0). Wally is listed and unused; the build does not read `Packages/`.

Checks:

```bash
make test
make lint
make build
```

`make test` runs Lune specs for cash, jump clearance, the porch, the session lock, profile reconcile, receipt idempotency, the streak, and the offline cap. There is no Studio in this environment, so the running place is verified by those specs, `rojo build`, and `tests/sim/smoke.luau`: `lune run tests/sim/smoke.luau <built.rbxlx>` boots the server scripts from the built place under `@lune/roblox` (real property-name/type checks, stubbed services), then simulates a player through all three courses, the porch, and the Crypt Key. It writes `parts.csv`; `python3 tests/sim/render.py` turns that into rough top-down and spawn-view PNGs.

## How to play

Jump numbers are locked to a default character: **JumpHeight 7.2**, **WalkSpeed 16**, **gravity 196.2**. `Movement` sets those on spawn. Do not change gravity without updating `CourseLayout`. Every gap is checked by `tests/spec/CourseLayout.spec.luau` at the worst phase of any moving platform.

The world is a moonlit vampire night (spooky-cute, kid-safe). You spawn in the middle of **Count Crackula's manor plaza**, facing north. Each exit has one gothic sign facing the spawn.

1. **North: Suburbs Delivery** (haunted night route, 15 obstacles, 2 checkpoints, pays **50**). Lawn hops, porch steps, a picket-fence beam, pumpkin tops, a sideways hover-drone, vanishing cardboard boxes, a leaf-blown sidewalk conveyor, a spinning ectoplasm sprinkler, roof hops, and a row of goo hurdles. Purple goo below.
2. **West: your porch.** **Porch Bench 50**, **Ice Bath 100**, **DoorDash Bag Shrine 150**. Buying all three sets tier **1**. Then the **Crypt Key (1500)** pad turns on and sets tier **2**.
3. **East: Graveyard Rugby Rush** (tier 1, 16 obstacles, 2 checkpoints, pays **150**). Through the rugby goal posts: tombstone hops, coffin platforms (one slides), a spinning tackle bar, a goal-crossbar beam, vanishing ghosts, tombstone wall-climb ledges, a scrum conveyor, a tackle-line of kill strips, and a bobbing rugby ball. Green ectoplasm below.
4. **South: Sore Foot Lava Crypt** (tier 2, 17 obstacles, 2 checkpoints, pays **400**). Through the manor gate: 6–7 stud gaps, chain beams, sliding and floating coffins, two candelabra spinners, crumbling tiles, brick wall-climb ledges, a lava belt, lava-crack hurdles, a rising sarcophagus. Blood-moon lava below.
5. Falling into goo/lava kills you; you respawn at your latest checkpoint for that run. Falling off the plaza onto the graveyard ground just teleports you back (checkpoint, course start, or spawn).
6. Cash is on the leaderboard and the top HUD. The red pad south-east of spawn is the **DoorDash shift** (daily streak, day 7 equips a sock). **Shop** lists passes and products; ids are still 0.

In Studio chat, `/cash 300` grants cash, and `/pass foamBlaster` (also `doubleCash`, `speedCoil`, `vip`) grants that pass. Neither works in a published server.

Profiles save to DataStore `CountCrackula_Player_v1` with a session lock (15 minute steal, retries, 60 second autosave). An unpublished place, or Studio without API access, falls back to an in-memory store and warns once; the game stays fully playable.

## Interfaces

`Economy` is server-authoritative. `Changed` fires `(player, cash, delta, reason)`.

- `GetCash(player) -> number`
- `AddCash(player, amount, reason)` — positive integer. 2× applies to `stage_clear`, `checkpoint`, `timer_bonus`, `daily_shift`, and `offline_tycoon` only.
- `TrySpend(player, amount, reason) -> boolean`
- `Hydrate(player, amount)` — restore from a save, no multiplier.

`BaseService` is the base team's stub. Keep these:

- `GetTier(player) -> number` (0 until the three pads are bought, then 1)
- `TierChanged:Fire(player, tier)`
- `ExportState(player) -> plain table` stored at `profile.base` and not read by Saves
- `ImportState(player, blob)` — the stub understands `tier` and `pads`; other keys round-trip

Courses check `GetTier >= requiredTier` (0 / 1 / 2) on touch. `Retention.GrantOfflineIncome(player, rawAccrued, elapsedSeconds)` is the offline cap. Call it once per join **after** the profile has loaded; an early call returns 0 and does not settle. `Shop` owns `MarketplaceService.ProcessReceipt`. A `PurchaseId` grants at most once, and `PurchaseGranted` is returned only after the profile save succeeds. Do not replace that callback.

The saved document is `cash`, `stages`, `streak`, `purchases`, `offline`, `base`, and the lock's `session`.

## Layout

| Path | Owner | What it is |
| --- | --- | --- |
| `src/shared/Economy` | Core | `GetCash`, `AddCash`, `TrySpend`, `Changed` |
| `src/server/Stages` | Core | The three courses, multi-checkpoints, finish payout, ground rescue |
| `src/shared/CourseLayout.luau` | Core | Blockout numbers. Tests decide if a jump is possible |
| `src/server/Pads` + `src/shared/PorchPads.luau` | Core placeholder | The three pads. **TODO(base-team)** replace |
| `src/server/Base` | Base team stub | Tier, pad flags, `ExportState` / `ImportState` |
| `src/shared/BaseConfig` | Base team stub | 3 tiers. Tier 1 price is 300, matching the pads |
| `src/server/World` | World | Map built at runtime from Parts: `init` (lobby, entrances, scatter, moon, bats), `Obstacles` (platform kinds and their behaviour), `Props` (houses, van, graves, gate…), `Sky` (night lighting, pcall-wrapped) |
| `src/server/Saves` | Core | Session-locked DataStore |
| `src/server/Shop` + `src/shared/Shop` | Core | Passes, dev products, idempotent receipts |
| `src/server/Retention` + `src/shared/Retention` | Core | Daily shift, sock, offline cap |
| `docs/PRICING.md` | Draft | Robux list and an assumed ARPPU |
| `docs/PAYOUT_CURVE.md` | Draft | Live 50/150 payouts, and a curve for later routes |

## What the other team owns

- The real tycoon: droppers, buttons, and any price that is not the three porch pads. Start from `BaseService` and `BaseConfig`. Keep `GetTier`, `TierChanged`, and the `base` save blob.
- The map art. `World` builds a blockout at runtime and tags parts with `CourseId` and `Role` (`start`, `checkpoint`, `finish`, `kill`, `gate`). Replace the parts; leave the stage flow alone unless you also change `CourseLayout`.
- The VIP lounge, if you sell that pass. Gate it with `Shop.OwnsPass(player, "vip")`.
- Calling `Retention.GrantOfflineIncome` with whatever raw income your sim produced while they were gone.

Foam Fangs stays a toy. Do not add player damage to it.
