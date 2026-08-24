-- Gen 1 pocketed bag + capacity 60. Optional Berries pocket / BAG GIVE when
-- Kanto-Reforged is also loaded (KR registers a decorator via exports).

local BagPockets = require("mods.gen1_bag_pockets.bag_pockets")

return function(mod)
  BagPockets.register(mod)

  mod.exports.CAPACITY = BagPockets.CAPACITY
  mod.exports.addBagMenuDecorator = function(fn)
    BagPockets.addBagMenuDecorator(fn)
  end
end
