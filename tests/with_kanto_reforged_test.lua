-- Both mods: luajit mods/gen1_bag_pockets/tests/with_kanto_reforged_test.lua
-- Requires mods/Kanto-Reforged to be present.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Bag = require("src.inventory.Bag")
local Data = require("src.core.Data")
Data:load()

-- Stub a few species the KR generator expects in encounter fixtures.
for _, id in ipairs({ "NIDORAN_M", "NIDORAN_F", "EXEGGCUTE", "CHANSEY", "PIDGEY", "RATTATA" }) do
  if not Data.pokemon[id] then
    Data.pokemon[id] = {
      id = id, name = id, dex = 999, types = { "NORMAL" },
      baseStats = { hp = 50, attack = 50, defense = 50, speed = 50, special = 50 },
      catchRate = 45, baseExp = 100, level1Moves = { "TACKLE" },
      growthRate = "SLOW", learnset = {}, tmhm = {}, evolutions = {},
    }
  end
end

local run = T.sdk.loadMods(
  { "mods/gen1_bag_pockets", "mods/Kanto-Reforged" },
  { data = Data })
T.eq(#run.errors, 0, "both mods load clean (" .. tostring(run.errors[1]) .. ")")

T.eq(Data.constants.bagSize, 60, "capacity 60 with both mods (no stack)")

local BagPockets = require("mods.gen1_bag_pockets.bag_pockets")
T.check(BagPockets.berriesEnabled(), "berries pocket on when KR present")
BagPockets.refreshPockets()
T.eq(#BagPockets.POCKETS, 5, "five pockets with KR")
T.eq(BagPockets.classify("CHERI_BERRY", Data.items.CHERI_BERRY or { name = "CHERI BERRY" }),
  "berries", "Cheri → berries with KR")

local exports = run.loader.exports.gen1_bag_pockets
T.check(exports and type(exports.addBagMenuDecorator) == "function",
  "bag mod exports decorator hook")

T.check(Data.screens and Data.screens.BagMenu, "BagMenu registered once")

local factory = Data.screens.BagMenu
factory = type(factory) == "function" and factory or factory.new
local bagSave = {
  money = 1000,
  inventory = { POTION = 1, CHERI_BERRY = 1, LEFTOVERS = 1 },
  bagOrder = { "POTION", "CHERI_BERRY", "LEFTOVERS" },
  player = { name = "RED" },
  party = {},
}
local fakeGame = {
  data = Data,
  save = bagSave,
  input = { wasPressed = function() return false end },
  stack = {
    top = function() return nil end,
    pop = function() end,
    push = function() end,
  },
}
local ok, list = pcall(factory, fakeGame, {})
T.check(ok and list, "BagMenu builds with both mods (" .. tostring(list) .. ")")
if ok and list then
  T.eq(#list.__pocketIds, 5, "BagMenu exposes five pocket ids")
  local hasBerries = false
  for _, id in ipairs(list.__pocketIds) do
    if id == "berries" then hasBerries = true end
  end
  T.check(hasBerries, "berries pocket id present")
end

BagPockets._resetFilter()
run.release()
T.finish("gen1_bag_pockets_with_kr")
