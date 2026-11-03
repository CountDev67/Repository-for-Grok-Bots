# Robux price draft

Draft only. Every game pass and developer product in `src/shared/Shop/Catalog.luau` still has **id 0**. Nothing in this list can be purchased until those ids are created on the Creator Dashboard and pasted into the catalog. The in-game button says "No id" until then.

The foam blaster ("Foam Fangs") is a toy dart launcher. It does not damage players, and it is priced as a cosmetic.

## Fee assumptions

These are planning assumptions, not a measurement and not a promise of payout.

1. Prices below are **list-price Robux** before regional pricing. The dashboard price is the source of truth once a SKU exists; `Catalog.price` is the label we show.
2. Marketplace fee is assumed at **30%**. The developer keeps **70%** of list price as earned Robux. Confirm the current Creator Dashboard terms before publishing.
3. DevEx is assumed at **$0.0035 per earned Robux** ($350 per 100,000), and only if the account qualifies. This draft does not predict that you will qualify or when.
4. There is **no playtest cohort**. The spender mix below is a planning assumption, not observed data.
5. The **2× DoorDash Tips** pass multiplies earned cash (routes, checkpoints, the daily shift, offline income). It does **not** multiply developer-product cash bundles, so the bundle face values below are what the buyer receives.
6. **Ice-Bath VIP** assumes the base/world team ships a real lounge that checks `Shop.OwnsPass(player, "vip")`. Do not sell the pass if that room does not exist.
7. Repeat purchases (skips, revives, extra bundles) are folded into the segment averages below. They are lifetime-ish planning averages, not a single receipt.

## Game passes

| Key | Name | List price | Why this price |
| --- | --- | --- | --- |
| `doubleCash` | 2× DoorDash Tips | 249 R$ | Core obby/sim multiplier. High enough to matter, under a typical "I'll just buy it" ceiling. |
| `speedCoil` | Rugby Cleats | 99 R$ | Small quality-of-life. WalkSpeed 16 → 22. Classic coil territory. |
| `vip` | Ice-Bath VIP | 199 R$ | Social pass. Priced under 2× so it does not outrank the economy pass while the lounge is still the other team's work. |
| `foamBlaster` | Foam Fangs | 149 R$ | Toy cosmetic. Not a weapon and not a power boost. Mid impulse. |

Pass total if someone buys all four: **696 R$** list.

## Developer products

| Key | Name | List price | Grant | Cash per list Robux |
| --- | --- | --- | --- | --- |
| `stageSkip` | Skip this porch | 35 R$ | Pays the armed route with no extra timer bonus. If nothing is open, grants 50 cash instead. | — |
| `revive` | Ice the ankles | 25 R$ | Teleports to the checkpoint (or the route start) and keeps the run armed. | — |
| `cashSmall` | Snack run | 79 R$ | 3,500 cash | 44.3 |
| `cashMedium` | Dinner rush | 349 R$ | 18,000 cash | 51.6 |
| `cashLarge` | Catering contract | 799 R$ | 70,000 cash | 87.6 |

The cash-per-Robux column rises on purpose. A larger bundle is a better rate, which is the usual ladder. Against the **live** obby (50 and 150 a run) these bundles are a shortcut past grinding, not a match for the porch's 300 cash. They matter once the base team adds droppers priced toward the tier 2 / tier 3 placeholders (12,000 and 80,000). See `PAYOUT_CURVE.md`.

## Revenue per paying user

ARPPU here means **list-price Robux per paying user**, before the 30% fee. "Paying user" means someone who spends at least once. Conversion (what share of players pay) is not estimated.

### Floor mix

A cautious obby where most payers buy one cheap thing.

| Share | What they buy | List Robux |
| --- | --- | --- |
| 55% | A revive or a skip, averaged to 30 | 30 |
| 25% | Rugby Cleats only | 99 |
| 12% | 2× tips only | 249 |
| 6% | 2× tips + Dinner rush | 598 |
| 2% | All passes + Catering contract | 1,495 |

Weighted list ARPPU = `0.55*30 + 0.25*99 + 0.12*249 + 0.06*598 + 0.02*1495` = **136.91 R$**.

Earned after the assumed 30% fee: **95.84 R$**. DevEx at the assumed rate: **about $0.34** per paying user.

### Target mix

What the shop is aimed at if the button is visible and the VIP room actually ships. Still an assumption.

| Share | What they buy | List Robux |
| --- | --- | --- |
| 20% | One revive/skip spree, averaged to 40 | 40 |
| 25% | One cheap permanent (cleats or Foam Fangs, averaged) | 124 |
| 30% | 2× tips + one skip | 284 |
| 15% | 2× tips + cleats + Dinner rush | 697 |
| 8% | All four passes + Dinner rush | 1,045 |
| 2% | All four passes + three Catering contracts | 3,093 |

Weighted list ARPPU = `0.20*40 + 0.25*124 + 0.30*284 + 0.15*697 + 0.08*1045 + 0.02*3093` = **374.21 R$**.

Earned after the assumed 30% fee: **261.95 R$**. DevEx at the assumed rate: **about $0.92** per paying user.

Per 100 paying users at the target mix: about **37,421 R$** list, about **26,195 R$** earned, about **$92** if every earned Robux were DevEx'd. Do not treat that as a forecast.

If the real mix lands near the floor, the shop still functions; it just does not carry the game. The obby and the (still stub) tycoon have to be fun without a purchase.
