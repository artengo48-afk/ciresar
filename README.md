DISCORD - https://discord.gg/7KaEw485SS

# ciresar — Installation

A cherry-picking job with a 3D pick minigame. **Multi-framework** — auto-detects
**Dunko vRP / QBox / QBCore / ESX** at runtime. No manual switch.

---

## 1. Install

1. Drop the `ciresar` folder into your `resources` (e.g. `resources/[local]/ciresar`).
2. Add to `server.cfg`:
   ```cfg
   ensure ciresar
   ```
3. Restart the server. On boot the console prints the detected framework, e.g.
   `[ciresar] Framework: QBox (qbx_core)`.

No external map/prop pack is required — the trees use base-game props
(`prop_tree_jacada_02` / `prop_joshua_tree_02b`).

## 2. The cherry item

Picking a cherry gives the player a **`cherry`** inventory item; the vendor buys
those items. Set up the item for your inventory below.

> **Don't want items?** Set `Config.items.enable = false`. The job then tracks an
> internal per-trip counter and sells that instead — **no item setup needed**.

| Config key          | default    |
|---------------------|------------|
| `Config.items.name` | `cherry`   |
| `Config.items.label`| `Cherries` |
| `Config.items.image`| `cherry.png` |

### ox_inventory  (QBox / ESX / standalone)
Add the item to `ox_inventory/data/items.lua`:
```lua
['cherry'] = {
    label = 'Cherries',
    weight = 40,
    stack = true,
    close = false,
    client = { image = 'cherry.png' },
},
```
Then copy an icon to `ox_inventory/web/images/cherry.png` (one is bundled in this
resource's `html/cherry.png`).

### QBCore  (qb-inventory / ps-inventory / lj-inventory) — automatic ✅
The item is **registered automatically at runtime** via `exports['qb-core']:AddItem`
when `Config.items.autoRegister = true` — you do **not** edit `qb-core/shared/items.lua`.
For the icon, copy `html/cherry.png` into your inventory's image folder
(e.g. `qb-inventory/html/images/cherry.png`).

### ESX (DB item list)
```sql
INSERT INTO items (name, label, weight, rare, can_remove) VALUES
('cherry', 'Cherries', 1, 0, 1);
```
(ESX on ox_inventory: use the ox_inventory steps above instead.)

### vRP — `vrp/cfg/items.lua`
```lua
["cherry"] = {"Cherries", "Fresh cherries picked from the orchard.", nil, 0.04},
```

---

## 3. Dependencies summary

| Requirement            | Needed?                                                    |
|------------------------|------------------------------------------------------------|
| Framework              | one of vRP / QBox / QBCore / ESX (auto-detected)           |
| Inventory              | only if `Config.items.enable = true` (ox / qb / native)    |
| MySQL / prop packs     | none                                                       |

---

## 4. Config quick notes (`config.lua`)

- `Config.lang` — `'en'` or `'ro'` (Romanian is written without diacritics).
- `Config.account` — which wallet the sale pays into: QBox/QBCore `cash`/`bank`,
  ESX `money`/`bank`. vRP always uses the wallet.
- `Config.sell.minPrice` / `maxPrice` — `$` per cherry (server rolls the price).
- `Config.basket.capacity` — cherries per picking trip before you must sell.
- `Config.pick.minCherries` / `maxCherries` — cherries that spawn on a tree.
- `Config.pickZone` / `Config.treePoints` / `Config.vendor` — locations + blips.
- `Config.props.zOffset` — vertical offset for the tree props (default `-1.0`)
  if they sit too high/low on your terrain.
- `Config.debug` — **must be `false`** on a live server (it unlocks the dev
  `/ciresar_give` and `/ciresar_clear` test commands).
