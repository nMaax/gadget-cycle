-- QuickFav: one hotkey cycles the combat-gadget button (grenades / Optical Camo / launcher)
-- through favorites picked in the CET overlay. Empty favorites = cycle everything owned.

local FAV_FILE = "favorites.json"
local cooldown = 0.35    -- seconds; a hard mouse-wheel flick sends many ticks, only the first counts
local favs = {}          -- [tdbidString] = true
local overlayOpen = false
local dirty = false      -- cooldown changed, save on overlay close
local cached = {}        -- items shown in the overlay, refreshed on open
local now, lastCycle = 0, -math.huge

local function log(msg) print("[QuickFav] " .. msg) end

-- File format: { "favorites": [...], "cooldown": 0.35 }; a bare array (old format) = favorites only.
local function loadFavs()
    local f = io.open(FAV_FILE, "r")
    if not f then return end
    local ok, data = pcall(json.decode, f:read("*a"))
    f:close()
    if not ok or type(data) ~= "table" then return end
    if type(data.cooldown) == "number" then cooldown = data.cooldown end
    favs = {}
    for _, k in ipairs(data.favorites or data) do favs[k] = true end
end

local function saveFavs()
    local list = {}
    for k in pairs(favs) do list[#list + 1] = k end
    table.sort(list)
    local f = io.open(FAV_FILE, "w")
    if not f then return log("cannot write " .. FAV_FILE) end
    f:write(json.encode({ favorites = list, cooldown = cooldown }))
    f:close()
end

local function itemName(id, key)
    local ok, name = pcall(function()
        return Game.GetLocalizedTextByKey(RPGManager.GetItemRecord(id):DisplayName())
    end)
    return (ok and name and name ~= "") and name or key
end

-- Same check the vanilla radial wheel uses (EquipmentSystem.IsEquipped, system-level).
local function isInstalled(es, player, id)
    local ok, res = pcall(function() return es:IsEquipped(player, id) end)
    return ok and res == true
end

-- All grenades + ability cyberware the player owns, one entry per record.
-- Abilities carry installed=false when not installed; cycling skips those.
local function eligibleItems(player, es)
    -- tonumber: EnumInt returns int64 cdata, which is keyed by identity in Lua tables
    local grenade = tonumber(EnumInt(gamedataItemType.Gad_Grenade))
    local ability = { [tonumber(EnumInt(gamedataItemType.Cyb_Ability))] = true,
                      [tonumber(EnumInt(gamedataItemType.Cyb_Launcher))] = true }
    local ok, items = Game.GetTransactionSystem():GetItemList(player)
    local out, seen = {}, {}
    if not ok or not items then return out end
    for _, data in ipairs(items) do
        local id = data:GetID()
        local t = tonumber(EnumInt(RPGManager.GetItemType(id)))
        if t == grenade or ability[t] then
            local key = TDBID.ToStringDEBUG(ItemID.GetTDBID(id))
            local installed = t == grenade or isInstalled(es, player, id)
            if not seen[key] then
                seen[key] = { id = id, key = key, name = itemName(id, key), installed = installed }
                out[#out + 1] = seen[key]
            elseif installed and not seen[key].installed then
                seen[key].id, seen[key].installed = id, true -- prefer the installed copy
            end
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

-- Next entry after curKey among favorites (or all, if no favorite is owned).
local function pickNext(items, curKey, favSet)
    local usable, list = {}, {}
    for _, it in ipairs(items) do
        if it.installed ~= false then usable[#usable + 1] = it end
    end
    for _, it in ipairs(usable) do
        if favSet[it.key] then list[#list + 1] = it end
    end
    if #list == 0 then list = usable end
    if #list == 0 then return nil end
    for i, it in ipairs(list) do
        if it.key == curKey then return list[i % #list + 1] end
    end
    return list[1]
end

-- Game menus (pause, inventory, map...) or the CET overlay are open.
local function inMenu()
    if overlayOpen then return true end
    local ok, res = pcall(function()
        local defs = Game.GetAllBlackboardDefs()
        return Game.GetBlackboardSystem():Get(defs.UI_System):GetBool(defs.UI_System.IsInMenu)
    end)
    return ok and res == true
end

local function cycleGadget()
    local player = Game.GetPlayer()
    if not player or inMenu() then return end
    local es = Game.GetScriptableSystemsContainer():Get("EquipmentSystem")
    local pd = es:GetPlayerData(player)
    local cur = pd:GetActiveGadget()
    local curKey = ItemID.IsValid(cur) and TDBID.ToStringDEBUG(ItemID.GetTDBID(cur)) or nil

    local nextItem = pickNext(eligibleItems(player, es), curKey, favs)
    if not nextItem or nextItem.key == curKey then return end

    local ok = pcall(function()
        es:QueueRequest(HotkeyAssignmentRequest.Construct(nextItem.id, EHotkey.RB, player, EHotkeyRequestType.Assign))
    end)
    if not ok then pd:AssignItemToHotkey(nextItem.id, EHotkey.RB) end
end

registerInput("cycle_gadget", "Cycle favorite grenade / ability", function(down)
    if not down or now - lastCycle < cooldown then return end
    lastCycle = now
    cycleGadget()
end)

registerForEvent("onInit", loadFavs)

registerForEvent("onUpdate", function(dt) now = now + dt end)

registerForEvent("onOverlayOpen", function()
    overlayOpen = true
    cached = {}
    local player = Game.GetPlayer()
    if player then
        cached = eligibleItems(player, Game.GetScriptableSystemsContainer():Get("EquipmentSystem"))
    end
end)

registerForEvent("onOverlayClose", function()
    overlayOpen = false
    if dirty then saveFavs(); dirty = false end
end)

registerForEvent("onDraw", function()
    if not overlayOpen then return end
    if ImGui.Begin("QuickFav") then
        local val, used = ImGui.SliderFloat("Key lock (s)", cooldown, 0, 1, "%.2f")
        if used then cooldown, dirty = val, true end
        ImGui.Separator()
        if #cached == 0 then
            ImGui.Text("Load a save to see your grenades / abilities.")
        else
            ImGui.Text("Tick favorites (none ticked = cycle all):")
        end
        for _, it in ipairs(cached) do
            local label = it.installed and it.name or (it.name .. " (not installed)")
            local val, pressed = ImGui.Checkbox(label .. "##" .. it.key, favs[it.key] == true)
            if pressed then
                favs[it.key] = val or nil
                saveFavs()
            end
        end
        if ImGui.Button("Debug: print cyberware to console") and Game.GetPlayer() then
            local player = Game.GetPlayer()
            local es = Game.GetScriptableSystemsContainer():Get("EquipmentSystem")
            local ok, items = Game.GetTransactionSystem():GetItemList(player)
            for _, data in ipairs(ok and items or {}) do
                local id = data:GetID()
                local key = TDBID.ToStringDEBUG(ItemID.GetTDBID(id))
                if key:find("Cyber") or key:find("Camo") or key:find("Launcher") or key:find("Face") then
                    log(key .. "  type=" .. tostring(RPGManager.GetItemType(id))
                        .. "  installed=" .. tostring(isInstalled(es, player, id)))
                end
            end
        end
    end
    ImGui.End()
end)

return { pickNext = pickNext }
