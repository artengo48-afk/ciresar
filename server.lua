-- ============================================================
--  CIRESAR — SERVER  (multi-framework: vRP / QBox / QBCore / ESX)
--  The server owns the cherry count and the payout. The client is
--  NEVER trusted for the money amount or the cherry quantity.
--
--  Communication is plain events (no vRP Tunnel): client fires
--  ciresar:pick / ciresar:sell; the server pushes ciresar:hud /
--  ciresar:notify back to that one player.
-- ============================================================

local FW = { name = nil }

-- ─────────────────────────────────────────────
--  FRAMEWORK DETECTION  (vRP → QBox/QBCore → ESX)
-- ─────────────────────────────────────────────
if GetResourceState('vrp') == 'started' then
    local code = LoadResourceFile('vrp', 'lib/utils.lua')
    if code then
        local fn = load(code)
        if fn then pcall(fn) end   -- defines module() in this scope
    end
    if type(module) == 'function' then
        local ok = pcall(function()
            local Proxy = module('vrp', 'lib/Proxy')
            FW.vRP  = Proxy.getInterface('vRP')
            FW.name = 'vrp'
        end)
        if ok and FW.name then print('[ciresar] Framework: Dunko vRP') end
    end
end

if not FW.name then
    Citizen.CreateThread(function()
        Citizen.Wait(500)

        -- QBox and QBCore both expose a QBCore-compatible core object through
        -- the 'qb-core' export. On QBox it comes from qbx_core's bridge
        -- (qbx_core `provide`s 'qb-core'); note GetCoreObject is NOT registered
        -- under the 'qbx_core' export name, so it MUST be called on 'qb-core'.
        local isQBox = GetResourceState('qbx_core') == 'started'
        if not FW.name and (isQBox or GetResourceState('qb-core') == 'started') then
            local ok = pcall(function()
                FW.QBCore = exports['qb-core']:GetCoreObject()
                FW.name   = 'qbcore'
            end)
            if ok and FW.name then
                print('[ciresar] Framework: ' .. (isQBox and 'QBox (qbx_core)' or 'QBCore'))
                return
            end
        end

        if not FW.name and GetResourceState('es_extended') == 'started' then
            local ok = pcall(function()
                FW.ESX  = exports['es_extended']:getSharedObject()
                FW.name = 'esx'
            end)
            if ok and FW.name then print('[ciresar] Framework: ESX'); return end
        end

        print('[ciresar] WARNING: no framework detected (vRP / QBox / QBCore / ESX).')
    end)
end

-- ─────────────────────────────────────────────
--  LOCALE  (read live; Locales comes from config.lua)
-- ─────────────────────────────────────────────
local function L(key, ...)
    local t = (Locales and (Locales[Config.lang] or Locales.en)) or {}
    local s = t[key] or key
    if select('#', ...) > 0 then
        local ok, res = pcall(string.format, s, ...)
        if ok then return res end
    end
    return s
end

-- ─────────────────────────────────────────────
--  MONEY  (pay the player — all framework calls pcall-guarded)
--  Returns true if the money was actually given.
-- ─────────────────────────────────────────────
local function giveMoney(src, amount)
    local ok, res = pcall(function()
        if FW.name == 'vrp' then
            local uid = FW.vRP.getUserId({ src })
            if not uid then return false end
            FW.vRP.giveMoney({ uid, amount })
            return true
        elseif FW.name == 'qbcore' then
            local p = FW.QBCore.Functions.GetPlayer(src)
            if not p then return false end
            p.Functions.AddMoney(Config.account.qbcore or 'cash', amount, 'cherry-sale')
            return true
        elseif FW.name == 'esx' then
            local p = FW.ESX.GetPlayerFromId(src)
            if not p then return false end
            p.addAccountMoney(Config.account.esx or 'money', amount)
            return true
        end
        return false
    end)
    if not ok then print('[ciresar] giveMoney error: ' .. tostring(res)); return false end
    return res and true or false
end

-- ─────────────────────────────────────────────
--  INVENTORY ITEM WRAPPERS  (auto-detect ox_inventory → qb-inventory →
--  framework-native). All pcall-guarded. No-ops when items are disabled.
-- ─────────────────────────────────────────────
local function invKind()
    if GetResourceState('ox_inventory') == 'started' then return 'ox' end
    if GetResourceState('qb-inventory') == 'started' then return 'qb' end
    return nil
end

local function giveItem(src, count)
    if not (Config.items and Config.items.enable) then return end
    count = count or 1
    if count <= 0 then return end
    local item = Config.items.name
    local ok, err = pcall(function()
        local k = invKind()
        if k == 'ox' then
            exports.ox_inventory:AddItem(src, item, count)
        elseif k == 'qb' then
            exports['qb-inventory']:AddItem(src, item, count, false, nil, 'ciresar')
        elseif FW.name == 'esx' then
            local p = FW.ESX.GetPlayerFromId(src); if p then p.addInventoryItem(item, count) end
        elseif FW.name == 'vrp' then
            local uid = FW.vRP.getUserId({ src }); if uid then FW.vRP.giveInventoryItem({ uid, item, count, true }) end
        end
    end)
    if not ok then print('[ciresar] giveItem error: ' .. tostring(err)) end
end

local function getItemCount(src)
    if not (Config.items and Config.items.enable) then return 0 end
    local item = Config.items.name
    local ok, n = pcall(function()
        local k = invKind()
        if k == 'ox' then
            return exports.ox_inventory:GetItemCount(src, item) or 0
        elseif k == 'qb' then
            return exports['qb-inventory']:GetItemCount(src, item) or 0
        elseif FW.name == 'esx' then
            local p = FW.ESX.GetPlayerFromId(src)
            local it = p and p.getInventoryItem(item)
            return (it and it.count) or 0
        elseif FW.name == 'vrp' then
            local uid = FW.vRP.getUserId({ src })
            return (uid and FW.vRP.getInventoryItemAmount({ uid, item })) or 0
        end
        return 0
    end)
    if not ok then print('[ciresar] getItemCount error: ' .. tostring(n)); return 0 end
    return n or 0
end

local function removeItem(src, count)
    if not (Config.items and Config.items.enable) then return true end
    count = count or 0
    if count <= 0 then return true end
    local item = Config.items.name
    local ok, res = pcall(function()
        local k = invKind()
        if k == 'ox' then
            return exports.ox_inventory:RemoveItem(src, item, count)
        elseif k == 'qb' then
            return exports['qb-inventory']:RemoveItem(src, item, count, nil, 'ciresar')
        elseif FW.name == 'esx' then
            local p = FW.ESX.GetPlayerFromId(src); if p then p.removeInventoryItem(item, count); return true end
        elseif FW.name == 'vrp' then
            local uid = FW.vRP.getUserId({ src }); if uid then return FW.vRP.tryGetInventoryItem({ uid, item, count, true }) end
        end
        return false
    end)
    if not ok then print('[ciresar] removeItem error: ' .. tostring(res)); return false end
    return res ~= false
end

-- Register the item where the framework needs it. ox_inventory items are
-- static (data/items.lua), so nothing to do there; QBCore can be auto-added.
local function registerItems()
    if not (Config.items and Config.items.enable and Config.items.autoRegister) then return end
    if GetResourceState('ox_inventory') == 'started' then return end
    if FW.name == 'qbcore' and GetResourceState('qb-core') == 'started' then
        pcall(function()
            exports['qb-core']:AddItem(Config.items.name, {
                name = Config.items.name, label = Config.items.label,
                weight = Config.items.weight or 40, type = 'item',
                image = Config.items.image, unique = false, useable = false,
                shouldClose = false, description = '',
            })
        end)
        print('[ciresar] item registered (qb-core): ' .. Config.items.name)
    end
end

Citizen.CreateThread(function()
    while not FW.name do Citizen.Wait(200) end
    registerItems()
end)

-- ─────────────────────────────────────────────
--  COMMS HELPERS
-- ─────────────────────────────────────────────
local function pushHUD(src)
    TriggerClientEvent('ciresar:hud', src, {
        count    = playerCherries[src] or 0,
        capacity = Config.basket.capacity,
    })
end

local function notify(src, kind, message)
    TriggerClientEvent('ciresar:notify', src, { kind = kind, message = message })
end

-- Promise-bridge reply (client serverCall waits on ciresar:cb).
local function respond(src, cbId, data)
    if cbId then TriggerClientEvent('ciresar:cb', src, cbId, data) end
end

-- ─────────────────────────────────────────────
--  STATE  (authoritative cherry count per player)
-- ─────────────────────────────────────────────
playerCherries = {}

-- ─────────────────────────────────────────────
--  EVENTS
-- ─────────────────────────────────────────────

-- Client reports one successful pick. Server validates the cap.
RegisterNetEvent('ciresar:pick', function()
    local src      = source
    local count    = playerCherries[src] or 0
    local capacity = Config.basket.capacity

    if count >= capacity then
        notify(src, 'warn', L('basket_full'))
        pushHUD(src)
        return
    end

    playerCherries[src] = count + 1
    giveItem(src, 1)            -- hand the player a real 'cherry' item
    pushHUD(src)

    if playerCherries[src] >= capacity then
        notify(src, 'good', L('basket_done', capacity, capacity))
    end
end)

-- The number of cherries the sale is actually based on: real item count in
-- item mode, otherwise the internal per-trip counter.
local function sellableCount(src)
    if Config.items and Config.items.enable then return getItemCount(src) end
    return playerCherries[src] or 0
end

-- Vendor opens the sell panel → report what the player can sell + price range.
RegisterNetEvent('ciresar:getSellInfo', function(payload)
    local src  = source
    local cbId = payload and payload._cbId
    respond(src, cbId, {
        count    = sellableCount(src),
        priceMin = Config.sell.minPrice,
        priceMax = Config.sell.maxPrice,
    })
end)

-- Sell everything. Server rolls the price and pays — money is never trusted
-- from the client, and the quantity is the real inventory / counter.
RegisterNetEvent('ciresar:sell', function(payload)
    local src  = source
    local cbId = payload and payload._cbId
    local count = sellableCount(src)

    if count <= 0 then return respond(src, cbId, nil) end

    -- Legacy mode anti-cheat (item mode is bounded by real inventory).
    if not (Config.items and Config.items.enable) and count > Config.basket.capacity then
        if Config.debug then
            print(('[ciresar] ANTI-CHEAT: src %s had %s cherries (cap %s)'):format(src, count, Config.basket.capacity))
        end
        playerCherries[src] = 0
        pushHUD(src)
        return respond(src, cbId, nil)
    end

    local price = math.random(Config.sell.minPrice, Config.sell.maxPrice)
    local total = count * price

    -- Take the items FIRST so we never pay without removing stock.
    if Config.items and Config.items.enable then
        if not removeItem(src, count) then return respond(src, cbId, nil) end
    end

    if not giveMoney(src, total) then
        if Config.items and Config.items.enable then giveItem(src, count) end  -- refund
        return respond(src, cbId, nil)
    end

    playerCherries[src] = 0
    pushHUD(src)
    respond(src, cbId, { count = count, price = price, total = total })
end)

-- Client asks for its current count (on resource start / re-sync).
RegisterNetEvent('ciresar:requestHUD', function()
    pushHUD(source)
end)

-- ─────────────────────────────────────────────
--  CLEANUP
-- ─────────────────────────────────────────────
AddEventHandler('playerDropped', function()
    playerCherries[source] = nil
end)

-- ─────────────────────────────────────────────
--  DEV TEST COMMANDS  (only when Config.debug)
-- ─────────────────────────────────────────────
if Config.debug then
    RegisterCommand('ciresar_give', function(src)
        playerCherries[src] = math.min((playerCherries[src] or 0) + 10, Config.basket.capacity)
        pushHUD(src)
        notify(src, 'info', 'DEBUG: +10 cherries')
    end, false)

    RegisterCommand('ciresar_clear', function(src)
        playerCherries[src] = 0
        pushHUD(src)
        notify(src, 'info', 'DEBUG: basket cleared')
    end, false)
end
