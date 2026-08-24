-- Standalone: luajit mods/gen1_bag_pockets/tests/bag_pockets_test.lua
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Bag = require("src.inventory.Bag")
local ItemEffects = require("src.inventory.ItemEffects")
local Data = require("src.core.Data")
Data:load()

local run = T.sdk.loadMod("mods/gen1_bag_pockets", { data = Data })
T.eq(#run.errors, 0, "loads clean (" .. tostring(run.errors[1]) .. ")")

local BagPockets = require("mods.gen1_bag_pockets.bag_pockets")
local exports = run.loader.exports.gen1_bag_pockets

T.eq(Data.constants.bagSize, BagPockets.CAPACITY, "constants.bagSize matches")
T.eq(exports.CAPACITY, BagPockets.CAPACITY, "exports.CAPACITY matches")
T.check(type(exports.addBagMenuDecorator) == "function", "exports.addBagMenuDecorator")

T.check(not BagPockets.berriesEnabled(), "berries pocket off without Kanto-Reforged")
T.eq(#BagPockets.POCKETS, 4, "four base pockets without KR")

T.eq(BagPockets.classify("POKE_BALL", Data.items.POKE_BALL), "balls", "Poke Ball → balls")
T.eq(BagPockets.classify("BICYCLE", Data.items.BICYCLE), "key", "Bicycle → key")
T.eq(BagPockets.classify("POTION", Data.items.POTION), "items", "Potion → items")
T.eq(BagPockets.classify("BERRY", { name = "BERRY" }), "items",
  "Berry falls into items when KR absent")
T.check(ItemEffects.isBall("ULTRA_BALL"), "Ultra Ball is a ball")

local tm = nil
for id, def in pairs(Data.items) do
  if def.machine and def.machine.kind == "TM" then tm = id; break end
end
T.check(tm ~= nil, "found a TM in item data")
T.eq(BagPockets.classify(tm, Data.items[tm]), "tmhm", "TM → tmhm")

T.check(Data.screens and Data.screens.BagMenu, "BagMenu screen replaced")

-- Pocket-aware SELECT: swap two items in ITEMS pocket updates save.bagOrder
BagPockets._resetFilter()
BagPockets._data = Data
BagPockets.setIndex(1)
local save = {
  inventory = { POTION = 1, ANTIDOTE = 1, POKE_BALL = 1 },
  bagOrder = { "POTION", "POKE_BALL", "ANTIDOTE" },
}
-- Activate filter the same way BagMenu does
local factory = Data.screens.BagMenu
factory = type(factory) == "function" and factory or factory.new
local fakeGame = {
  data = Data,
  save = save,
  input = { wasPressed = function() return false end },
  stack = {
    top = function() return nil end,
    pop = function() end,
    push = function() end,
  },
}
local ok, list = pcall(factory, fakeGame, {})
T.check(ok and list, "BagMenu factory builds (" .. tostring(list) .. ")")
if ok and list then
  T.eq(#list.__pocketIds, 4, "pocket id count is 4 without KR")
  T.check(type(list.onSelectKey) == "function", "SELECT reorder enabled on ITEMS")
  -- First SELECT marks swap; second completes against real bagOrder
  list.index = 1
  list.onSelectKey(list.items[1], list)
  T.eq(list.swapIndex, 1, "first SELECT sets swapIndex")
  list.index = 2
  -- items pocket filtered: POTION, ANTIDOTE (POKE_BALL in balls)
  -- rebuild may have CANCEL; find ANTIDOTE row
  local antidoteIdx
  for i, row in ipairs(list.items) do
    if row.value == "ANTIDOTE" then antidoteIdx = i break end
  end
  T.check(antidoteIdx ~= nil, "ANTIDOTE visible in items pocket")
  list.index = antidoteIdx
  list.onSelectKey(list.items[antidoteIdx], list)
  T.eq(save.bagOrder[1], "ANTIDOTE", "swap moved ANTIDOTE earlier in bagOrder")
  T.eq(save.bagOrder[3], "POTION", "swap moved POTION later in bagOrder")

  -- Switch to tmhm: reorder disabled
  list.gen1ModernUi.switchPocket(list.gen1ModernUi, 3) -- items->balls->key->tmhm
  T.eq(BagPockets.current().id, "tmhm", "switched to tmhm")
  T.eq(list.onSelectKey, nil, "SELECT reorder disabled on tmhm")
end

-- TM/HM sort
BagPockets._data = Data
BagPockets.setIndex(4)
-- force filter active via opening path already did; ensure for direct order call
local tmSave = {
  inventory = { HM_01 = 1, TM_28 = 1, TM_01 = 1, HM_02 = 1, TM_05 = 1 },
  bagOrder = { "HM_01", "TM_28", "TM_01", "HM_02", "TM_05" },
}
-- Open filter: factory path sets filterActive; call factory once more if needed
if ok and list then
  -- filter still active from open bag
  local tmOrder = Bag.order(tmSave)
  T.eq(table.concat(tmOrder, ","), "TM_01,TM_05,TM_28,HM_01,HM_02",
    "tmhm pocket groups TMs then HMs by number")
end

BagPockets._resetFilter()
run.release()
T.finish("gen1_bag_pockets")
