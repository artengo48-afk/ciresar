-- ============================================================
--  CIRESAR (Cherry Picking Job) — CONFIG
--  Loaded on BOTH client and server (shared_script).
--  Multi-framework: Dunko vRP / QBox / QBCore / ESX.
-- ============================================================

Config = {}

-- 'ro' or 'en'. Romanian strings are written WITHOUT diacritics on purpose
-- (FiveM CEF + native text render them cleanly that way).
Config.lang = 'en'

-- Set true ONLY while developing — unlocks the /ciresar_* test commands
-- and prints debug to the server console. MUST be false on a live server.
Config.debug = false

-- ─────────────────────────────────────────────
--  MONEY ACCOUNT (which wallet gets paid, per framework)
--  vRP is always wallet money. QBCore/QBox + ESX pick an account.
-- ─────────────────────────────────────────────
Config.account = {
    qbcore = 'cash',   -- 'cash' or 'bank'
    esx    = 'money',  -- 'money' (cash) or 'bank'
}

-- ─────────────────────────────────────────────
--  PICK ZONE  (blip + boundary for the trees)
-- ─────────────────────────────────────────────
Config.pickZone = {
    coords     = vector3(2803.38, 4757.50, 46.52),
    radius     = 60.0,
    blipLabel  = nil,   -- nil => taken from locale key 'blip_zone'
    blipSprite = 89,
    blipColor  = 1,     -- red
}

-- ─────────────────────────────────────────────
--  CHERRY TREE SPAWN POINTS (inside / near the zone)
-- ─────────────────────────────────────────────
Config.treePoints = {
    vector3(2822.66, 4792.31, 48.65),
    vector3(2827.51, 4777.79, 48.51),
    vector3(2827.14, 4760.70, 47.76),
    vector3(2816.85, 4752.52, 46.97),
    vector3(2797.30, 4751.41, 46.35),
    vector3(2793.80, 4767.31, 46.37),
    vector3(2786.75, 4783.52, 46.29),
    vector3(2771.57, 4782.02, 45.87),
    vector3(2776.39, 4765.18, 45.99),
    vector3(2804.18, 4737.50, 46.38),
}

-- ─────────────────────────────────────────────
--  VENDOR NPC
-- ─────────────────────────────────────────────
Config.vendor = {
    coords           = vector3(1694.94, 3594.86, 35.62),
    heading          = 210.0,
    model            = 'a_m_m_farmer_01',
    blipLabel        = nil,  -- nil => locale key 'blip_vendor'
    blipSprite       = 59,
    blipColor        = 2,
    interactDistance = 2.5,
}

-- ─────────────────────────────────────────────
--  BASKET
-- ─────────────────────────────────────────────
Config.basket = {
    capacity = 50,   -- max cherries carried per trip
}

-- ─────────────────────────────────────────────
--  PICKING (per-tree minigame)
-- ─────────────────────────────────────────────
Config.pick = {
    minCherries      = 10,   -- min cherries that spawn on a tree
    maxCherries      = 15,   -- max cherries that spawn on a tree
    interactDistance = 2.2,  -- metres to show the [E] prompt
}

-- ─────────────────────────────────────────────
--  SELL / PRICING  ($ per cherry, server rolls in this range)
-- ─────────────────────────────────────────────
Config.sell = {
    minPrice = 8,
    maxPrice = 15,
}

-- ─────────────────────────────────────────────
--  TREE PROPS  (large = pickable, small = picked/respawning)
-- ─────────────────────────────────────────────
Config.props = {
    large   = 'prop_tree_jacada_02',
    small   = 'prop_joshua_tree_02b',
    zOffset = -1.0,   -- lower trees so they sit on the ground (coords are ~player height)
}

Config.respawnDelay = 30000   -- ms before a picked tree returns

-- ─────────────────────────────────────────────
--  INVENTORY ITEM  (cherry)
--  enable=true  → picking gives a 'cherry' item, the vendor buys those items.
--  enable=false → legacy mode: an internal per-trip counter is sold instead.
--  Inventory is auto-detected: ox_inventory (QBox/ESX) → qb-inventory (QBCore)
--  → framework-native (vRP / ESX). On ox_inventory the item must exist in
--  ox_inventory/data/items.lua (we register 'cherry' there); on QBCore it is
--  auto-added via qb-core:AddItem when autoRegister is true.
-- ─────────────────────────────────────────────
Config.items = {
    enable       = true,
    name         = 'cherry',
    label        = 'Cherries',
    weight       = 40,
    image        = 'cherry.png',
    autoRegister = true,   -- QBCore (qb-core:AddItem) only; ox uses data/items.lua
}

-- ─────────────────────────────────────────────
--  LOCALES  (Lua side — NUI has its own copy inline in script.js)
--  Romanian intentionally WITHOUT diacritics.
-- ─────────────────────────────────────────────
Locales = {
    en = {
        blip_zone     = 'Cherry Orchard',
        blip_vendor   = 'Cherry Vendor',
        prompt_pick   = 'Pick cherries',
        prompt_sell   = 'Sell cherries',
        basket_full   = 'Basket full! Head to the vendor to sell.',
        basket_done   = 'Basket full (%s/%s). Head to the vendor!',
        nothing_sell  = 'You have no cherries to sell.',
        sold          = 'Sold %s cherries for $%s ($%s each).',
        no_account    = 'Could not find your account.',
    },
    ro = {
        blip_zone     = 'Livada de Cirese',
        blip_vendor   = 'Vanzator Cirese',
        prompt_pick   = 'Culege cirese',
        prompt_sell   = 'Vinde cirese',
        basket_full   = 'Cosul e plin! Mergi la vanzator ca sa vinzi.',
        basket_done   = 'Cos plin (%s/%s). Mergi la vanzator!',
        nothing_sell  = 'Nu ai cirese de vandut.',
        sold          = 'Ai vandut %s cirese pentru $%s ($%s bucata).',
        no_account    = 'Nu ti-am gasit contul.',
    },
}
