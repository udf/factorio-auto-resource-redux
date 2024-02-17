local EntityGroups = require "src.EntityGroups"

local function gen_paste_tool(name_suffix, icon, entity_filters, entity_type_filters)
  return {
    name = "arr-paste-tool-" .. name_suffix,
    type = "selection-tool",
    selection_mode = { "blueprint", "same-force", "buildable-type" },
    alt_selection_mode = { "nothing" },
    selection_color = { 0, 0.75, 0 },
    alt_selection_color = { 0, 0.75, 0 },
    selection_cursor_box_type = "copy",
    alt_selection_cursor_box_type = "not-allowed",
    stack_size = 1,
    icon = icon,
    icon_size = 64,
    flags = { "hidden", "not-stackable", "only-in-cursor" },
    subgroup = "other",
    draw_label_for_cursor_render = true,
    entity_filters = entity_filters,
    entity_type_filters = entity_type_filters
  }
end

data:extend({ gen_paste_tool(
  "requester-tank",
  "__auto-resource-redux__/graphics/paste-tool-requester-tank.png",
  { "arr-requester-tank" }
) })

local managed_entity_types = {}
local managed_entity_names = {}
for group_name, filter in pairs(EntityGroups.entity_group_filters) do
  if filter.filter == "type" then
    table.insert(managed_entity_types, filter.type)
  elseif filter.filter == "name" then
    table.insert(managed_entity_names, filter.name)
  else
    assert(false, "FIXME: Cannot determine selection tool filters: unknown entity filter in EntityGroups.lua!")
  end
end
data:extend({ gen_paste_tool(
  "condition",
  "__auto-resource-redux__/graphics/paste-tool-condition.png",
  managed_entity_names,
  managed_entity_types
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
    "__auto-resource-redux__/graphics/paste-tool-recipe.png",
    furnace_names
  ) })
end
