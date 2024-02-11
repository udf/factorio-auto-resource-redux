local entity = table.deepcopy(data.raw["simple-entity-with-force"]["simple-entity-with-force"])
entity.minable.result = nil
entity.name = "arr-data-proxy"
entity.collision_mask = {}
entity.picture = {
  filename = "__auto-resource-redux__/graphics/empty.png",
  priority = "extra-high",
  width = 32,
  height = 32,
}

local item = {
  flags = { "hidden" },
  icon = "__auto-resource-redux__/graphics/logo.png",
  icon_size = 64,
  name = "arr-data-proxy",
  order = "s[simple-entity-with-owner]-o[arr-data-proxy]",
  place_result = "arr-data-proxy",
  stack_size = 50,
  subgroup = "other",
  type = "item",
}

data:extend({
  entity,
  item
})
