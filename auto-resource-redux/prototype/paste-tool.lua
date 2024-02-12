local paste_tool_requester_tank = {
  name = "arr-paste-tool-requester-tank",
  type = "selection-tool",
  selection_mode = { "blueprint", "same-force", "buildable-type" },
  alt_selection_mode = { "nothing" },
  selection_color = { 0, 0.75, 0 },
  alt_selection_color = { 0, 0.75, 0 },
  selection_cursor_box_type = "copy",
  alt_selection_cursor_box_type = "not-allowed",
  stack_size = 1,
  icon = "__auto-resource-redux__/graphics/paste-tool-requester-tank.png",
  icon_size = 64,
  flags = { "hidden", "not-stackable" , "only-in-cursor"},
  subgroup = "other",
  draw_label_for_cursor_render = true,
  entity_filters = { "arr-requester-tank" }
}


data:extend({ paste_tool_requester_tank })
