-- Hidden chest for miner outputs
-- TODO: this could be a linked chest for better performance
local hidden_chest = table.deepcopy(data.raw["container"]["iron-chest"])
hidden_chest.minable = nil
hidden_chest.name = "arr-sink-chest"
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


-- Sink "tank" to insert fluid into storage
local sink_tank = table.deepcopy(data.raw["storage-tank"]["storage-tank"])
sink_tank.name = "arr-sink-tank"
sink_tank.minable.result = "arr-sink-tank"
sink_tank.fast_replaceable_group = nil
sink_tank.corpse = "pipe-to-ground-remnants"
sink_tank.collision_box = { { -0.5, -0.5 }, { 0.5, 0.5 } }
sink_tank.selection_box = { { -0.5, -0.5 }, { 0.5, 0.5 } }
sink_tank.collision_mask = { "item-layer", "object-layer", "water-tile" }
sink_tank.fluid_box.base_area = 250
sink_tank.fluid_box.height = 1
sink_tank.fluid_box.base_level = -1
sink_tank.fluid_box.pipe_connections = { { position = { 0, -1 } } }
sink_tank.two_direction_only = false
sink_tank.damaged_trigger_effect = table.deepcopy(data.raw["pipe-to-ground"]["pipe-to-ground"].damaged_trigger_effect)
sink_tank.pipe_covers = table.deepcopy(data.raw["pipe-to-ground"]["pipe-to-ground"].pipe_covers)
sink_tank.integration_patch = {
  direction_count = 1,
  filename = "__auto-resource-redux__/graphics/sink-tank-integration.png",
  priority = "low",
  width = 120,
  height = 120,
  scale = 0.5,
  shift = { 0, 0.45 },
}
sink_tank.window_bounding_box = { { -0.2, 0.35 }, { 0.2, 0.9 } }
sink_tank.pictures = {
  picture = {
    north = {
      filename = "__auto-resource-redux__/graphics/sink-tank-north.png",
      priority = "high",
      width = 128,
      height = 128,
      scale = 0.5,
    },
    east = {
      filename = "__auto-resource-redux__/graphics/sink-tank-east.png",
      priority = "high",
      width = 128,
      height = 128,
      scale = 0.5,
    },
    south = {
      filename = "__auto-resource-redux__/graphics/sink-tank-south.png",
      priority = "high",
      width = 128,
      height = 128,
      scale = 0.5,
    },
    west = {
      filename = "__auto-resource-redux__/graphics/sink-tank-west.png",
      priority = "high",
      width = 128,
      height = 128,
      scale = 0.5,
    },
  },
  window_background = {
    filename = "__auto-resource-redux__/graphics/empty.png",
    priority = "extra-high",
    width = 32,
    height = 32,
  },
  fluid_background = {
    filename = "__auto-resource-redux__/graphics/sink-tank-fluid-background.png",
    priority = "extra-high",
    width = 20,
    height = 32,
  },
  gas_flow = {
    animation_speed = 0.25,
    axially_symmetrical = false,
    direction_count = 1,
    filename = "__base__/graphics/entity/pipe/hr-steam.png",
    frame_count = 60,
    height = 30,
    line_length = 10,
    priority = "extra-high",
    scale = 0.4,
    width = 48,
    shift = { 0, 0.1 },
    draw_as_glow = true
  },
  flow_sprite = {
    filename = "__base__/graphics/entity/pipe/fluid-flow-low-temperature.png",
    priority = "extra-high",
    width = 160,
    height = 20,
    draw_as_glow = true
  }
}

local sink_tank_recipe = {
  enabled = true,
  energy_required = 0.5,
  ingredients = {
    { type = "item", name = "pipe", amount = 10 },
    { type = "item", name = "iron-plate", amount = 5 }
  },
  name = "arr-sink-tank",
  result = "arr-sink-tank",
  type = "recipe"
}

local sink_tank_item = {
  icon = "__auto-resource-redux__/graphics/sink-tank-icon.png",
  icon_size = 64,
  name = "arr-sink-tank",
  order = "b[fluid]-z[storage-tank]",
  place_result = "arr-sink-tank",
  stack_size = 50,
  subgroup = "storage",
  type = "item"
}

data:extend({
  sink_tank,
  sink_tank_recipe,
  sink_tank_item,
})
