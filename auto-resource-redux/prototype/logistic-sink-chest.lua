-- sink chest for bots to insert items into storage
local sink_chest = table.deepcopy(data.raw["logistic-container"]["logistic-chest-storage"])
sink_chest.collision_mask = { "item-layer", "object-layer", "water-tile" }
sink_chest.name = "arr-logistic-sink-chest"
sink_chest.minable.result = "arr-logistic-sink-chest"
sink_chest.animation = {
  filename = "__auto-resource-redux__/graphics/hole-chest-glow-anim.png",
  frame_count = 15,
  width = 50,
  height = 64,
  priority = "extra-high",
  scale = 0.5,
  draw_as_glow = true,
  tint = { 1, 0.74, 0 }
}
sink_chest.integration_patch = {
  direction_count = 1,
  filename = "__auto-resource-redux__/graphics/sink-chest-integration.png",
  priority = "low",
  width = 72,
  height = 34,
  scale = 0.5,
  shift = { 0.07, 0.25 },
}
sink_chest.corpse = "arr-logistic-sink-chest-remnants"

local sink_chest_remnants = table.deepcopy(data.raw["corpse"]["storage-chest-remnants"])
sink_chest_remnants.name = "arr-logistic-sink-chest-remnants"
sink_chest_remnants.animation = {
  direction_count = 1,
  filename = "__auto-resource-redux__/graphics/sink-chest-remnants.png",
  frame_count = 1,
  line_length = 1,
  width = 72,
  height = 38,
  scale = 0.5,
  shift = { 0.07, 0.25 },
}

local sink_chest_recipe = {
  enabled = true,
  ingredients = {
    { type = "item", name = "steel-chest", amount = 1 },
    { type = "item", name = "electronic-circuit", amount = 3 },
    { type = "item", name = "advanced-circuit", amount = 1 }
  },
  name = "arr-logistic-sink-chest",
  result = "arr-logistic-sink-chest",
  type = "recipe"
}

local sink_chest_item = {
  icon = "__auto-resource-redux__/graphics/sink-chest-icon.png",
  icon_size = 64,
  name = "arr-logistic-sink-chest",
  order = "b[storage]-f[arr-logistic-sink-chest]",
  place_result = "arr-logistic-sink-chest",
  stack_size = 50,
  subgroup = "logistic-network",
  type = "item"
}

data:extend({
  sink_chest,
  sink_chest_remnants,
  sink_chest_recipe,
  sink_chest_item,
})