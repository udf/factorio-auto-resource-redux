local flib_table = require("__flib__/table")
local EntityGroups = require "src.EntityGroups"

local function gen_paste_tool(name_suffix, attrs)
  return flib_table.deep_merge({
    {
      name = "arr-paste-tool-" .. name_suffix,
      type = "selection-tool",
      selection_mode = { "blueprint", "same-force", "buildable-type" },
      alt_selection_mode = { "nothing" },
      selection_color = { 0, 0.75, 0 },
      alt_selection_color = { 0, 0.75, 0 },
      selection_cursor_box_type = "copy",
      alt_selection_cursor_box_type = "not-allowed",
      stack_size = 1,
      icon_size = 64,
      flags = { "hidden", "not-stackable", "only-in-cursor" },
      subgroup = "other",
      draw_label_for_cursor_render = true,
    },
    attrs
  })
end

data:extend({ gen_paste_tool(
  "requester-tank",
  {
    icon = "__auto-resource-redux__/graphics/paste-tool-requester-tank.png",
    entity_filters = { "arr-requester-tank" }
  }
) })

local managed_entity_types = {}
local managed_entity_names = {}
for group_name, filter in pairs(EntityGroups.entity_group_filters) do
  if filter.filter == "type" then
    table.insert(managed_entity_types, filter.type)
  elseif filter.filter == "name" then
    if filter.name ~= "arr-hidden-sink-chest" then
      table.insert(managed_entity_names, filter.name)
    end
  else
    assert(false, "FIXME: Cannot determine selection tool filters: unknown entity filter in EntityGroups.lua!")
  end
end
data:extend({ gen_paste_tool(
  "condition",
  {
    icon = "__auto-resource-redux__/graphics/paste-tool-condition.png",
    entity_filters = managed_entity_names,
    entity_type_filters = managed_entity_types
  }
) })

-- generate one tool per furnace crafting category
local furnace_crafting_categories = {}
for name, furnace in pairs(data.raw["furnace"]) do
  for _, category in ipairs(furnace.crafting_categories) do
    if furnace_crafting_categories[category] == nil then
      furnace_crafting_categories[category] = {}
    end
    table.insert(furnace_crafting_categories[category], furnace.name)
  end
end

for category, furnace_names in pairs(furnace_crafting_categories) do
  data:extend({ gen_paste_tool(
    "furnace-" .. category,
    {
      icon = "__auto-resource-redux__/graphics/paste-tool-recipe.png",
      entity_filters = furnace_names,
      alt_selection_mode = { "blueprint", "same-force", "buildable-type" },
      alt_selection_color = { 0.75, 0, 0 },
      alt_entity_filters = furnace_names
    }
  ) })
end

-- fallback tool for when specific tool is missing
-- which happens if another mod creates a category after we've created our tools
data:extend({ gen_paste_tool(
  "furnace-arr-fallback",
  {
    icon = "__auto-resource-redux__/graphics/paste-tool-recipe.png",
    entity_type_filters = { "furnace" },
    alt_selection_mode = { "blueprint", "same-force", "buildable-type" },
    alt_selection_color = { 0.75, 0, 0 },
    alt_entity_type_filters = { "furnace" }
  }
) })
