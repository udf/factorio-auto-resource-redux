-- Hidden chest for miner outputs
-- TODO: this could be a linked chest for better performance
local hidden_chest = table.deepcopy(data.raw["container"]["iron-chest"])
hidden_chest.minable = nil
hidden_chest.name = "arr-hidden-sink-chest"
hidden_chest.collision_mask = {}
hidden_chest.inventory_size = 5
hidden_chest.selectable_in_game = false
hidden_chest.picture = {
  filename = "__auto-resource-redux__/graphics/empty.png",
  priority = "extra-high",
  width = 32,
  height = 32,
}

data:extend({
  hidden_chest
})