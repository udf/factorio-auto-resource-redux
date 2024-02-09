-- Requester "tank" to request from storage
local requester_tank = table.deepcopy(data.raw["storage-tank"]["storage-tank"])
requester_tank.name = "arr-requester-tank"
requester_tank.minable.result = "arr-requester-tank"
requester_tank.fast_replaceable_group = nil
requester_tank.corpse = "pipe-to-ground-remnants"
requester_tank.collision_box = { { -0.5, -0.45 }, { 0.5, 0.45 } }
requester_tank.selection_box = { { -0.5, -0.5 }, { 0.5, 0.5 } }
requester_tank.fluid_box.base_area = 100
requester_tank.fluid_box.height = 1
requester_tank.fluid_box.base_level = 10
requester_tank.fluid_box.pipe_connections = { { position = { 0, -1 } } }
requester_tank.two_direction_only = false
requester_tank.damaged_trigger_effect = table.deepcopy(data.raw["pipe-to-ground"]["pipe-to-ground"].damaged_trigger_effect)
requester_tank.pipe_covers = table.deepcopy(data.raw["pipe-to-ground"]["pipe-to-ground"].pipe_covers)
requester_tank.window_bounding_box = { { -0.2, 0.35 }, { 0.2, 0.9 } }
requester_tank.integration_patch = {
  north = {
    filename = "__auto-resource-redux__/graphics/requester-tank-floor.png",
    priority = "low",
    width = 114,
    height = 66,
    scale = 0.5,
    shift = { 0.078125, 0.125 },
  },
  east = {
    filename = "__auto-resource-redux__/graphics/requester-tank-floor.png",
    priority = "low",
    width = 114,
    height = 66,
    scale = 0.5,
    shift = { 0.078125, 0.25 },
  },
  south = {
    filename = "__auto-resource-redux__/graphics/requester-tank-floor.png",
    priority = "low",
    width = 114,
    height = 66,
    scale = 0.5,
    shift = { 0.078125, 0.25 },
  },
  west = {
    filename = "__auto-resource-redux__/graphics/requester-tank-floor.png",
    priority = "low",
    width = 114,
    height = 66,
    scale = 0.5,
    shift = { 0.078125, 0.25 },
  }
}
requester_tank.pictures = {
  picture = {
    north = {
      filename = "__base__/graphics/entity/pipe-to-ground/hr-pipe-to-ground-up.png",
      priority = "high",
      width = 128,
      height = 128,
      scale = 0.5,
    },
    east = {
      filename = "__base__/graphics/entity/pipe-to-ground/hr-pipe-to-ground-right.png",
      priority = "high",
      width = 128,
      height = 128,
      scale = 0.5,
    },
    south = {
      filename = "__base__/graphics/entity/pipe-to-ground/hr-pipe-to-ground-down.png",
      priority = "high",
      width = 128,
      height = 128,
      scale = 0.5,
    },
    west = {
      filename = "__base__/graphics/entity/pipe-to-ground/hr-pipe-to-ground-left.png",
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
    filename = "__auto-resource-redux__/graphics/empty.png",
    priority = "extra-high",
    width = 32,
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

local requester_tank_recipe = {
  enabled = true,
  energy_required = 0.5,
  ingredients = {
    { type = "item", name = "pipe",       amount = 10 },
    { type = "item", name = "iron-plate", amount = 5 }
  },
  name = "arr-requester-tank",
  result = "arr-requester-tank",
  type = "recipe"
}

local requester_tank_item = {
  icon = "__auto-resource-redux__/graphics/requester-tank-icon.png",
  icon_size = 64,
  name = "arr-requester-tank",
  order = "b[fluid]-z[arr-b-tank]",
  place_result = "arr-requester-tank",
  stack_size = 50,
  subgroup = "storage",
  type = "item"
}

data:extend({
  requester_tank,
  requester_tank_recipe,
  requester_tank_item,
})
