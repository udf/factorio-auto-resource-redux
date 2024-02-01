local GUIItemPriority = {}
local ItemPriorityManager = require "src.ItemPriorityManager"
local GUICommon = require "src.GUICommon"
local GUIDispatcher = require "src.GUIDispatcher"
local GUIComponentItemPrioritySet = require "src.GUIComponentItemPrioritySet"
local R = require "src.RichText"

local GUI_CLOSE_EVENT = "arr-priority-close"


function GUIItemPriority.open(player)
  local screen = player.gui.screen
  local window = screen[GUICommon.GUI_ITEM_PRIORITY]
  if window then
    window.destroy()
    return
  end

  window = screen.add({
    type = "frame",
    name = GUICommon.GUI_ITEM_PRIORITY,
    direction = "vertical",
    tags = { event = GUI_CLOSE_EVENT },
    style = "inner_frame_in_outer_frame"
  })
  player.opened = window
  window.auto_center = true

  GUICommon.create_header(window, "Manage Item Priorities", GUI_CLOSE_EVENT)

  local inner_frame = window.add({
    type = "frame",
    style = "inside_deep_frame_for_tabs"
  })

  local tabbed_pane = inner_frame.add({
    type = "tabbed-pane",
    style = "logistic_gui_tabbed_pane"
  })

  local priority_sets = ItemPriorityManager.get_priority_sets(player)
  -- group priority sets into G[group][entity_name] = {set_keys}
  local grouped_priority_sets = {}
  local groups_with_subitem_column = {}
  for set_key, priority_set in pairs(priority_sets) do
    if type(priority_set) ~= "table" then
      goto continue
    end
    local group = priority_set.group
    if grouped_priority_sets[group] == nil then
      grouped_priority_sets[group] = {}
    end
    local entity_name = priority_set.entity_name
    if grouped_priority_sets[group][entity_name] == nil then
      grouped_priority_sets[group][entity_name] = {}
    end
    table.insert(grouped_priority_sets[group][entity_name], set_key)
    if priority_set.sub_item_name then
      groups_with_subitem_column[group] = true
    end
    ::continue::
  end

  for group, entities in pairs(grouped_priority_sets) do
    local tab = tabbed_pane.add({ type = "tab", caption = group })
    local tab_content_flow = tabbed_pane.add({
      type = "frame",
      direction = "vertical",
      style = "invisible_frame"
    })
    local subheader = tab_content_flow.add({
      type = "frame",
      style = "subheader_frame_with_top_border",
      direction = "horizontal"
    })
    subheader.style.horizontally_stretchable = true
    subheader.style.vertically_stretchable = true
    subheader.style.height = 50
    subheader.style.top_padding = 8
    subheader.style.bottom_padding = 8
    subheader.style.left_padding = 8
    local hint = subheader.add({
      type = "label",
      caption = {
        "",
        "Items are used from left to right.\n",
        R.HINT, { "control-keys.mouse-button-1" }, R.HINT_END, " to set item quantity.",
      }
    })
    hint.style.maximal_width = 400
    hint.style.single_line = false
    local scroll_pane = tab_content_flow.add({
      type = "scroll-pane",
      direction = "vertical",
      vertical_scroll_policy = "always",
      style = "logistic_gui_scroll_pane"
    })
    scroll_pane.style.vertically_stretchable = true
    scroll_pane.style.minimal_width = 404
    scroll_pane.style.minimal_height = 400
    scroll_pane.style.maximal_height = 600
    scroll_pane.style.top_padding = 8
    scroll_pane.style.left_padding = -2
    scroll_pane.style.right_padding = 8
    local content_table = scroll_pane.add({
      type = "table",
      column_count = 2,
      vertical_centering = true,
      style = "bordered_table"
    })
    tabbed_pane.add_tab(tab, tab_content_flow)

    for entity_name, set_keys in pairs(entities) do
      local entity_sprite = content_table.add({
        type = "sprite",
        sprite = "entity/" .. entity_name,
        elem_tooltip = { type = "entity", name = entity_name },
        -- resize_to_sprite = false
      })
      -- entity_sprite.style.size = {32, 32}
      local content_flow = content_table.add({
        type = "flow",
        direction = "vertical",
      })

      for _, set_key in ipairs(set_keys) do
        local priority_set = priority_sets[set_key]
        local controls_flow = content_flow.add({
          type = "flow",
          direction = "horizontal",
          style = "player_input_horizontal_flow"
        })

        if priority_set.sub_item_name then
          controls_flow.add({
            type = "sprite",
            sprite = "item/" .. priority_set.sub_item_name,
            elem_tooltip = { type = "item", name = priority_set.sub_item_name }
          })
        elseif groups_with_subitem_column[group] then
          local empty = controls_flow.add({
            type = "empty-widget",
          })
          empty.style.size = { 32, 32 }
        end

        GUIComponentItemPrioritySet.create(controls_flow, priority_sets, set_key)
      end
    end
  end
end

-- TODO on_tick updates???

function on_close(event, tags, player)
  local window = player.gui.screen[GUICommon.GUI_ITEM_PRIORITY]
  window.destroy()
end

GUIDispatcher.register(defines.events.on_gui_click, GUI_CLOSE_EVENT, on_close)
GUIDispatcher.register(defines.events.on_gui_closed, GUI_CLOSE_EVENT, on_close)


return GUIItemPriority
