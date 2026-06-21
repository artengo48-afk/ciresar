-- ============================================================
--  CIRESAR — CLIENT  (framework-agnostic)
--  No vRP Tunnel: talks to the server with plain events.
--  Interaction prompt + notifications go through core_ui when it's
--  running (so it matches the server look); otherwise it falls back
--  to self-contained 3D text + its own toast, so the resource stays
--  portable for a standalone / free release.
-- ============================================================

-- ─────────────────────────────────────────────
--  STATE
-- ─────────────────────────────────────────────
local treeAvailable = {}
local treeProps     = {}
local treeCherries  = {}   -- remaining cherries per tree (nil = not opened yet)
local vendorPed     = 0
local hudVisible    = false
local minigameOpen  = false
local minigameTree  = 0
local sellOpen      = false
local localCount    = 0    -- authoritative count, synced from server

for i = 1, #Config.treePoints do
    treeAvailable[i] = true
    treeProps[i]     = 0
    treeCherries[i]  = nil
end

-- ─────────────────────────────────────────────
--  LOCALE  (Lua side)
-- ─────────────────────────────────────────────
local function L(key)
    local t = (Locales and (Locales[Config.lang] or Locales.en)) or {}
    return t[key] or key
end

-- ─────────────────────────────────────────────
--  HELPERS
-- ─────────────────────────────────────────────
local function dist(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

local function hasCoreUI()
    return GetResourceState('core_ui') == 'started'
end

local function draw3DText(x, y, z, text)
    local on, sx, sy = World3dToScreen2d(x, y, z)
    if not on then return end
    SetTextScale(0.34, 0.34)
    SetTextFont(4)
    SetTextProportional(true)
    SetTextColour(255, 255, 255, 220)
    SetTextOutline()
    SetTextCentre(true)
    SetTextEntry('STRING')
    AddTextComponentString(text)
    DrawText(sx, sy)
end

-- ── Interaction prompt (core_ui if present, else 3D text) ──
local prompt = { active = false, text = nil, coords = nil, shown = false, last = nil }

local function promptSet(text, coords)
    prompt.active = true
    prompt.text   = text
    prompt.coords = coords
    if hasCoreUI() then
        if not prompt.shown or prompt.last ~= text then
            exports.core_ui:showText({ key = 'E', text = text })
            prompt.shown = true
            prompt.last  = text
        end
    end
end

local function promptClear()
    if not prompt.active then return end
    prompt.active = false
    if prompt.shown then
        if hasCoreUI() then exports.core_ui:hideText() end
        prompt.shown = false
        prompt.last  = nil
    end
end

local function promptDraw()  -- only does anything in the fallback path
    if prompt.active and not hasCoreUI() and prompt.coords then
        draw3DText(prompt.coords.x, prompt.coords.y, prompt.coords.z, '~y~[E]~w~ ' .. prompt.text)
    end
end

-- ── Notifications (core_ui if present, else native + own toast) ──
local KIND_TO_COREUI = { good = 'success', warn = 'warning', bad = 'error', info = 'info' }

local function notify(kind, message)
    if hasCoreUI() then
        exports.core_ui:notify({ type = KIND_TO_COREUI[kind] or 'info', message = message })
    else
        SetNotificationTextEntry('STRING')
        AddTextComponentString(message)
        DrawNotification(false, true)
        SendNUIMessage({ type = 'toast', kind = kind, message = message })
    end
end

local function spawnProp(model, coords)
    local hash = GetHashKey(model)
    RequestModel(hash)
    while not HasModelLoaded(hash) do Citizen.Wait(0) end
    -- Spawn at coords.z + zOffset (no PlaceObjectOnGroundProperly: it was
    -- snapping the trees up into the air on this terrain).
    local z = coords.z + (Config.props.zOffset or 0.0)
    local obj = CreateObject(hash, coords.x, coords.y, z, false, false, false)
    FreezeEntityPosition(obj, true)
    SetModelAsNoLongerNeeded(hash)
    return obj
end

local function deleteProp(idx)
    if treeProps[idx] and treeProps[idx] ~= 0 then
        DeleteObject(treeProps[idx])
        treeProps[idx] = 0
    end
end

local function showHUD()
    if not hudVisible then
        hudVisible = true
        SendNUIMessage({ type = 'showHUD' })
    end
end

local function hideHUD()
    if hudVisible and not minigameOpen then
        hudVisible = false
        SendNUIMessage({ type = 'hideHUD' })
    end
end

-- ─────────────────────────────────────────────
--  SERVER → CLIENT EVENTS
-- ─────────────────────────────────────────────
RegisterNetEvent('ciresar:hud', function(data)
    localCount = data.count or 0
    SendNUIMessage({
        type     = 'hud',
        count    = localCount,
        capacity = data.capacity or Config.basket.capacity,
    })
end)

RegisterNetEvent('ciresar:notify', function(data)
    notify(data.kind or 'info', data.message or '')
end)

-- ─────────────────────────────────────────────
--  PROMISE BRIDGE  (request/response over events, framework-agnostic)
-- ─────────────────────────────────────────────
local pendingCbs = {}

RegisterNetEvent('ciresar:cb', function(cbId, result)
    local cb = pendingCbs[cbId]
    if cb then cb(result); pendingCbs[cbId] = nil end
end)

local function serverCall(event, payload)
    local p = promise.new()
    local cbId = math.random(100000, 999999)
    pendingCbs[cbId] = function(r) p:resolve(r) end
    payload = payload or {}
    payload._cbId = cbId
    TriggerServerEvent('ciresar:' .. event, payload)
    return Citizen.Await(p)
end

-- ─────────────────────────────────────────────
--  NUI CALLBACKS  (JS → Lua)
-- ─────────────────────────────────────────────
RegisterNUICallback('pick', function(_, cb)
    TriggerServerEvent('ciresar:pick')
    cb({})
end)

RegisterNUICallback('close', function(data, cb)
    SetNuiFocus(false, false)
    minigameOpen = false

    local idx = minigameTree
    if idx > 0 then
        local remaining = tonumber(data.remaining) or 0
        if remaining <= 0 then
            -- Tree picked clean → swap to small prop, respawn after delay
            local point = Config.treePoints[idx]
            treeAvailable[idx] = false
            treeCherries[idx]  = nil
            deleteProp(idx)
            Citizen.CreateThread(function()
                treeProps[idx] = spawnProp(Config.props.small, point)
            end)
            Citizen.CreateThread(function()
                Citizen.Wait(Config.respawnDelay)
                deleteProp(idx)
                treeProps[idx] = spawnProp(Config.props.large, point)
                treeAvailable[idx] = true
            end)
        else
            treeCherries[idx] = remaining
        end
        minigameTree = 0
    end
    cb({})
end)

-- ─────────────────────────────────────────────
--  SELL PANEL  (vendor → ask the server what's sellable, open the NUI)
-- ─────────────────────────────────────────────
local function openSell()
    if sellOpen or minigameOpen then return end
    sellOpen = true
    Citizen.CreateThread(function()
        local info = serverCall('getSellInfo', {}) or {}
        if (info.count or 0) <= 0 then
            sellOpen = false
            notify('warn', L('nothing_sell'))
            return
        end
        promptClear()
        SetNuiFocus(true, true)
        SendNUIMessage({
            type     = 'sell',
            count    = info.count,
            priceMin = info.priceMin,
            priceMax = info.priceMax,
            lang     = Config.lang,
        })
    end)
end

RegisterNUICallback('sellConfirm', function(_, cb)
    cb({})
    Citizen.CreateThread(function()
        local res = serverCall('sell', {})
        if res then
            SendNUIMessage({ type = 'sellResult', count = res.count, price = res.price, total = res.total })
        else
            SendNUIMessage({ type = 'sellResult', error = true })
        end
    end)
end)

RegisterNUICallback('sellClose', function(_, cb)
    SetNuiFocus(false, false)
    sellOpen = false
    cb({})
end)

-- ─────────────────────────────────────────────
--  BLIPS
-- ─────────────────────────────────────────────
local function createBlip(coords, sprite, color, label)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, sprite)
    SetBlipColour(blip, color)
    SetBlipScale(blip, 0.85)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(label)
    EndTextCommandSetBlipName(blip)
    return blip
end

-- ─────────────────────────────────────────────
--  VENDOR NPC
-- ─────────────────────────────────────────────
local function spawnVendor()
    local model = GetHashKey(Config.vendor.model)
    RequestModel(model)
    while not HasModelLoaded(model) do Citizen.Wait(50) end
    local c = Config.vendor.coords
    vendorPed = CreatePed(4, model, c.x, c.y, c.z - 1.0, Config.vendor.heading, false, true)
    SetEntityInvincible(vendorPed, true)
    SetBlockingOfNonTemporaryEvents(vendorPed, true)
    FreezeEntityPosition(vendorPed, true)
    SetModelAsNoLongerNeeded(model)
end

-- ─────────────────────────────────────────────
--  INIT
-- ─────────────────────────────────────────────
Citizen.CreateThread(function()
    Citizen.Wait(600)

    createBlip(Config.pickZone.coords, Config.pickZone.blipSprite, Config.pickZone.blipColor,
        Config.pickZone.blipLabel or L('blip_zone'))
    createBlip(Config.vendor.coords, Config.vendor.blipSprite, Config.vendor.blipColor,
        Config.vendor.blipLabel or L('blip_vendor'))

    spawnVendor()

    for i, point in ipairs(Config.treePoints) do
        treeProps[i] = spawnProp(Config.props.large, point)
    end

    TriggerServerEvent('ciresar:requestHUD')   -- re-sync carried count
end)

-- ─────────────────────────────────────────────
--  MAIN LOOP
-- ─────────────────────────────────────────────
Citizen.CreateThread(function()
    Citizen.Wait(500)
    while true do
        local sleep  = 500
        local ped    = PlayerPedId()
        local coords = GetEntityCoords(ped)

        local inZone     = dist(coords, Config.pickZone.coords) <= Config.pickZone.radius
        local distVendor = dist(coords, Config.vendor.coords)
        local nearVendor = distVendor < Config.vendor.interactDistance * 2

        if (inZone or nearVendor) and not minigameOpen then
            showHUD()
        else
            hideHUD()
        end

        local promptThisFrame = false

        -- ── TREES ──
        if inZone and not minigameOpen and not sellOpen then
            sleep = 0
            for i, point in ipairs(Config.treePoints) do
                if treeAvailable[i] and dist(coords, point) < Config.pick.interactDistance then
                    promptThisFrame = true
                    promptSet(L('prompt_pick'), vector3(point.x, point.y, point.z + 0.6))
                    if IsControlJustPressed(0, 38) then  -- E
                        if localCount >= Config.basket.capacity then
                            notify('warn', L('basket_full'))
                        else
                            minigameOpen = true
                            minigameTree = i
                            if not treeCherries[i] then
                                treeCherries[i] = math.random(Config.pick.minCherries, Config.pick.maxCherries)
                            end
                            SetNuiFocus(true, true)
                            SendNUIMessage({
                                type        = 'open',
                                cherryCount = treeCherries[i],
                                current     = localCount,
                                capacity    = Config.basket.capacity,
                                lang        = Config.lang,
                            })
                        end
                    end
                    break
                end
            end
        end

        -- ── VENDOR ──
        if nearVendor and not minigameOpen and not sellOpen then
            sleep = 0
            if distVendor < Config.vendor.interactDistance then
                promptThisFrame = true
                local v = Config.vendor.coords
                promptSet(L('prompt_sell'), vector3(v.x, v.y, v.z + 0.9))
                if IsControlJustPressed(0, 38) then
                    openSell()
                end
            end
        end

        if promptThisFrame then promptDraw() else promptClear() end

        Citizen.Wait(sleep)
    end
end)

-- ─────────────────────────────────────────────
--  CLEANUP
-- ─────────────────────────────────────────────
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if vendorPed ~= 0 then DeleteEntity(vendorPed) end
    for i = 1, #treeProps do deleteProp(i) end
    if prompt.shown and hasCoreUI() then exports.core_ui:hideText() end
    SetNuiFocus(false, false)
end)
