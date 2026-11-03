# Payout curve

Two different numbers live in the project. Do not mix them up when you price the base.

## What the game pays right now

These are the live grants in `CourseLayout` and `PorchPads`. They are flat on purpose so the blockout is easy to feel.

| Action | Cash | Notes |
| --- | --- | --- |
| Suburbs Delivery finish | 50 | 7 jumps, one checkpoint. The checkpoint does not pay. Repeatable: you are sent back to the start. |
| Stage 2 finish | 150 | Harder copy (narrower, taller steps, one wider gap). Requires `BaseService.GetTier(player) >= 1`. |
| Porch bench | −50 | Spawns a seat. |
| Ice bath | −100 | Spawns a tub. |
| DoorDash bag shrine | −150 | Spawns a red bag on a pedestal. |
| All three pads | tier → 1 | Sum is **300**, which is `BaseConfig` tier 1's price. |

Six Suburbs clears buy the porch (6 × 50 = 300) and open Stage 2. After that, Stage 2 is 150 a run. There is no timer bonus in the blockout.

The daily shift is separate earned cash (`Streak.Rewards`: 200, 400, 600, 800, 1000, 1400, 2200). A full week is **6,600**, plus a once-per-account sock on day 7. That sock is not a tradable Limited.

**2× DoorDash Tips**, when the pass id is real and owned, multiplies `stage_clear`, `checkpoint`, `timer_bonus`, `daily_shift`, and `offline_tycoon`. It does not multiply pad spends (those are spends) or `dev_product` cash.

## Placeholder base prices

From `src/shared/BaseConfig`. The other team owns these numbers.

| Tier | Id | Placeholder price | How the current obby relates |
| --- | --- | --- | --- |
| 1 | `porch` | 300 | Exactly the three pads. The slice charges the pads, then sets tier to 1. |
| 2 | `walkup` | 12,000 | Not paid by the obby in any reasonable session. 12,000 / 150 = 80 Stage 2 runs. This price assumes **tycoon income you have not built yet**. |
| 3 | `keep` | 80,000 | Same. Endgame placeholder. |

If you change tier 1, change the pad costs too. A test locks `BaseConfig.Get(1).price` to the sum of the pads.

## Offline cap (the hook you call)

`Retention.GrantOfflineIncome(player, rawAccrued, elapsedSeconds)` runs your raw number through `OfflineIncome.Cap` and adds the result as `offline_tycoon` cash (so 2× applies). It settles once per saved logout. Call it **once per join, after the profile has loaded**. A call before load returns 0 and does not settle, so you can retry. `Retention.GetOfflineSeconds(player)` is the gap since the last clean leave (0 on the first join).

| Tier passed in | Rate | 8-hour ceiling |
| --- | --- | --- |
| 0 or 1 | 400 / hour | 3,200 |
| 2 | 1,200 / hour | 9,600 |
| 3 or higher | 4,000 / hour | 32,000 |

Tier 0 uses the tier-1 rate so a new player is not a special case. Hours above 8 do not accrue. Price early droppers so that a tier-1 base, left overnight, is a nice bump (a few thousand) and not a tier-2 purchase. At 400/hour, one full offline window is 3,200, about a quarter of the 12,000 tier-2 placeholder. Four such nights, plus Stage 2 and the weekly shift, are the neighborhood of tier 2 **if** you leave the placeholder alone. If your droppers pay faster than that, raise the tier prices or lower the rates together.

## A curve for later routes

Not implemented. The blockout stays at 50 and 150 until someone adds real stages. If you add a longer delivery ladder, this is the shape that stays readable against the placeholders above:

```
payout(n) = floor(100 * 1.25^(n - 1) + 1e-6)
```

`n` is the global stage index starting at 1. Checkpoint pay, if you add it, should stay a fraction of that stage (the blockout uses **0**). A timer bonus, if you add it, should be at most half the stage payout and only when they beat par; late finishes still pay the base. Suggested par times live next to the platforms you build, not in this table.

Computed from the formula (same floor the code would use):

| n | Payout | n | Payout | n | Payout |
| --- | --- | --- | --- | --- | --- |
| 1 | 100 | 9 | 596 | 17 | 3,552 |
| 2 | 125 | 10 | 745 | 18 | 4,440 |
| 3 | 156 | 11 | 931 | 19 | 5,551 |
| 4 | 195 | 12 | 1,164 | 20 | 6,938 |
| 5 | 244 | 13 | 1,455 | 21 | 8,673 |
| 6 | 305 | 14 | 1,818 | 22 | 10,842 |
| 7 | 381 | 15 | 2,273 | 23 | 13,552 |
| 8 | 476 | 16 | 2,842 | 24 | 16,940 |

Pack sums if you group them by eights: about **1,982**, then **11,824**, then **70,488**. A full clear of 24 stages is about **84,300** base cash, before any timer bonus and before 2×.

How to retune against `BaseConfig`:

- Keep the first pack's total in the same band as tier 1 (today, 300). The formula's first pack (~2,000) is already richer than the blockout. If you switch to it, either raise the porch price or lower `100` and `1.25`.
- Put tier 2 somewhere above one offline window at tier 1 plus one pack of routes, and below "a determined evening plus a few nights." The 12,000 placeholder does that only if most of the income is your tycoon, not the obby.
- Put tier 3 near the top of the ladder (the last pack is ~70,000) so the keep is a real sink, not a single Catering contract (70,000 cash for 799 R$). If one bundle buys the whole keep, the bundle is too strong or the keep is too cheap.
- Change the constants in one place and recompute this table. The live 50 / 150 numbers do not use this formula, so editing the table alone changes nothing in game.
