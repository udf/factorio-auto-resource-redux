local function hole_glow_anim(tint)
  return {
    filename = "__auto-resource-redux__/graphics/hole-chest-glow-anim.png",
    frame_count = 15,
    width = 50,
    height = 64,
    priority = "extra-high",
    scale = 0.5,
    draw_as_glow = true,
    tint = tint,
    shift = { 0, -0.25 }
  }
end

local function integration_patch(path)
  return {
    direction_count = 1,
    filename = path,
    priority = "extra-high",
    width = 72,
    height = 34,
    scale = 0.5,
    shift = { 0.07, 0 },
  }
end

local function remnants(path)
  return {
    direction_count = 1,
    filename = path,
    frame_count = 1,
    line_length = 1,
    width = 72,
    height = 38,
    scale = 0.5,
    shift = { 0.07, 0 },
  }
end

local function recipe(name)
  return {
    enabled = true,
    ingredients = {},
    name = name,
    result = name,
    type = "recipe"
  }
end

local function item(path, name, order)
  return {
    icon = path,
    icon_size = 64,
    name = name,
    order = order,
    place_result = name,
    stack_size = 50,
    subgroup = "logistic-network",
    type = "item"
  }
end

local selection_box = { { -0.5, -0.375 }, { 0.5, 0.375 } }

-- sink chest for bots to insert items into storage
local sink_chest = table.deepcopy(data.raw["logistic-container"]["logistic-chest-storage"])
sink_chest.collision_mask = { "item-layer", "object-layer", "water-tile" }
sink_chest.name = "arr-logistic-sink-chest"
sink_chest.minable.result = "arr-logistic-sink-chest"
sink_chest.animation = hole_glow_anim({ 1, 0.74, 0 })
sink_chest.integration_patch = integration_patch("__auto-resource-redux__/graphics/sink-chest-integration.png")
sink_chest.corpse = "arr-logistic-sink-chest-remnants"
sink_chest.selection_box = selection_box

local sink_chest_remnants = table.deepcopy(data.raw["corpse"]["storage-chest-remnants"])
sink_chest_remnants.name = "arr-logistic-sink-chest-remnants"
sink_chest_remnants.animation = remnants("__auto-resource-redux__/graphics/sink-chest-remnants.png")

data:extend({
  sink_chest,
  sink_chest_remnants,
  recipe("arr-logistic-sink-chest"),
  item(
    "__auto-resource-redux__/graphics/sink-chest-icon.png",
    "arr-logistic-sink-chest",
    "b[storage]-f[arr-logistic-sink-chest]"
  )
})


-- request chest
local request_chest = table.deepcopy(data.raw["logistic-container"]["logistic-chest-requester"])
request_chest.collision_mask = { "item-layer", "object-layer", "water-tile" }
request_chest.name = "arr-logistic-requester-chest"
request_chest.minable.result = "arr-logistic-requester-chest"
request_chest.animation = hole_glow_anim({ 0, 0.74, 1 })
request_chest.integration_patch = integration_patch("__auto-resource-redux__/graphics/requester-chest-integration.png")
request_chest.corpse = "arr-logistic-requester-chest-remnants"
request_chest.selection_box = selection_box

local request_chest_remnants = table.deepcopy(data.raw["corpse"]["requester-chest-remnants"])
request_chest_remnants.name = "arr-logistic-requester-chest-remnants"
request_chest_remnants.animation = remnants("__auto-resource-redux__/graphics/requester-chest-remnants.png")

data:extend({
  request_chest,
  request_chest_remnants,
  recipe("arr-logistic-requester-chest"),
  item(
    "__auto-resource-redux__/graphics/requester-chest-icon.png",
    "arr-logistic-requester-chest",
    "b[storage]-g[arr-logistic-requester-chest]"
  )
})
