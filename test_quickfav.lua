-- Mock-Game self-test for quickfav. Run from the repo root: luajit test_quickfav.lua
local MOD = "bin/x64/plugins/cyber_engine_tweaks/mods/quickfav/"

local inputs, events = {}, {}
function registerInput(slug, _, fn) inputs[slug] = fn end
function registerForEvent(ev, fn) events[ev] = fn end
json = { decode = function() return {} end, encode = function() return "[]" end }

gamedataItemType = { Gad_Grenade = 1, Cyb_Ability = 2, Cyb_Launcher = 3, Wea_Pistol = 4 }
EHotkey = { RB = "RB" }
EHotkeyRequestType = { Assign = "Assign" }
local ffi = require("ffi")
function EnumInt(e) return ffi.new("int64_t", e) end -- like CET: int64 cdata

-- inventory: id = { key, type, installed }
local inv = {
    { key = "Items.GrenadeFrag", t = 1 },
    { key = "Items.GrenadeFrag", t = 1 },          -- second stack, must dedupe
    { key = "Items.GrenadeEMP",  t = 1 },
    { key = "Items.OpticalCamo", t = 2, installed = true },
    { key = "Items.Launcher",    t = 3, installed = false }, -- not installed -> skip
    { key = "Items.Pistol",      t = 4 },
}
local active = nil
TDBID = { ToStringDEBUG = function(k) return k end }
ItemID = { GetTDBID = function(id) return id.key end, IsValid = function(id) return id ~= nil end }
RPGManager = {
    GetItemType = function(id) return id.t end,
    GetItemRecord = function() error("no record in mock") end,
}
HotkeyAssignmentRequest = { Construct = function(id) return id end }
local es = {
    GetPlayerData = function() return { GetActiveGadget = function() return active end } end,
    IsEquipped = function(_, _, id) return id.installed == true end,
    QueueRequest = function(_, req) active = req end,
}
local player = {}
local menuOpen = false
Game = {
    GetAllBlackboardDefs = function() return { UI_System = { IsInMenu = "IsInMenu" } } end,
    GetBlackboardSystem = function() return { Get = function() return {
        GetBool = function() return menuOpen end } end } end,
    GetPlayer = function() return player end,
    GetScriptableSystemsContainer = function() return { Get = function() return es end } end,
    GetTransactionSystem = function() return { GetItemList = function()
        local out = {}
        for _, it in ipairs(inv) do out[#out + 1] = { GetID = function() return it end } end
        return true, out
    end } end,
}

local mod = dofile(MOD .. "init.lua")
local tick = function(s) events.onUpdate(s) end
local press = function() tick(1); inputs.cycle_gadget(true); return active and active.key end

-- no favorites: cycles all eligible, sorted by name (key fallback), deduped, launcher skipped
assert(press() == "Items.GrenadeEMP")
assert(press() == "Items.GrenadeFrag")
assert(press() == "Items.OpticalCamo")
assert(press() == "Items.GrenadeEMP")
inputs.cycle_gadget(false) -- release must do nothing
assert(active.key == "Items.GrenadeEMP")

-- wheel flick: burst of presses within cooldown advances only once
tick(1)
for _ = 1, 8 do inputs.cycle_gadget(true); tick(0.01) end
assert(active.key == "Items.GrenadeFrag")

-- game menu open: silent
menuOpen = true
assert(press() == "Items.GrenadeFrag")
menuOpen = false

-- uninstalled ability is never picked even if favorited
assert(mod.pickNext({ { key = "A", installed = false }, { key = "B" } }, nil, { A = true }).key == "B")

-- favorites only
local items = { { key = "A" }, { key = "B" }, { key = "C" } }
local favs = { A = true, C = true }
assert(mod.pickNext(items, "A", favs).key == "C")
assert(mod.pickNext(items, "C", favs).key == "A")
assert(mod.pickNext(items, "B", favs).key == "A")   -- current not a favorite -> first favorite
assert(mod.pickNext(items, nil, { Z = true }).key == "A") -- no owned favorites -> all
assert(mod.pickNext({}, nil, {}) == nil)

-- no player (main menu) -> no error
Game.GetPlayer = function() return nil end
inputs.cycle_gadget(true)
print("ok")
