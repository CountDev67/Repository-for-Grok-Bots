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

`make test` runs Lune specs for cash, jump clearance, the porch, the session lock, profile reconcile, receipt idempotency, the streak, and the offline cap. There is no Studio in this environment, so the running place is verified by those specs plus `rojo build`.

## How to play

Jump numbers are locked to a default character: **JumpHeight 7.2**, **WalkSpeed 16**, **gravity 196.2**. `Movement` sets those on spawn. Do not change gravity without updating `CourseLayout`.

1. You spawn in the lobby facing **Suburbs Delivery** (north): 7 jumps, a blue checkpoint, a gold finish. The finish pays **50** cash once per trip. You are sent back to the start so you can run it again.
2. Falling drops you on a kill volume. You respawn at the checkpoint if you touched it this run, otherwise the lobby.
3. West is your porch. **Porch Bench 50**, **Ice Bath 100**, **DoorDash Bag Shrine 150**. Hold the prompt. A bench, tub, or red bag spawns behind the pad.
4. Buying all three sets your base tier to **1** and opens **Stage 2** (east): a narrower, taller, longer-gap copy that pays **150**.
5. Cash is on the leaderboard as **Cash** and in the top HUD.
6. South-east of the lobby, the red pad is the **DoorDash shift** (one claim per UTC day, 7-day streak, day 7 equips a sock). **Shop** in the top right lists passes and products. Every id is still 0, so those buttons do not prompt.

Six suburb runs buy the porch (300) and open Stage 2. In Studio chat, `/cash 300` grants cash, and `/pass foamBlaster` (also `doubleCash`, `speedCoil`, `vip`) grants that pass. Neither command is connected in a published server.

Profiles save to DataStore `CountCrackula_Player_v1` with a session lock (15 minute steal, retries, 60 second autosave). Studio without API access keeps the profile in memory and warns once.

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

Stage 2 checks `GetTier` on touch. `Retention.GrantOfflineIncome(player, rawAccrued, elapsedSeconds)` is the offline cap. Call it once per join **after** the profile has loaded; an early call returns 0 and does not settle. `Shop` owns `MarketplaceService.ProcessReceipt`. A `PurchaseId` grants at most once, and `PurchaseGranted` is returned only after the profile save succeeds. Do not replace that callback.

The saved document is `cash`, `stages`, `streak`, `purchases`, `offline`, `base`, and the lock's `session`.

## Layout

| Path | Owner | What it is |
| --- | --- | --- |
| `src/shared/Economy` | Core | `GetCash`, `AddCash`, `TrySpend`, `Changed` |
| `src/server/Stages` | Core | The two courses, checkpoint, finish payout |
| `src/shared/CourseLayout.luau` | Core | Blockout numbers. Tests decide if a jump is possible |
| `src/server/Pads` + `src/shared/PorchPads.luau` | Core placeholder | The three pads. **TODO(base-team)** replace |
| `src/server/Base` | Base team stub | Tier, pad flags, `ExportState` / `ImportState` |
| `src/shared/BaseConfig` | Base team stub | 3 tiers. Tier 1 price is 300, matching the pads |
| `src/server/World` | World placeholder | Parts created at runtime. **TODO(world-team)** replace the art |
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
