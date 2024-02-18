GUIComponentItemPrioritySet = {}

local flib_table = require("__flib__/table")
local GUICommon = require "src.GUICommon"
local GUIComponentSliderInput = require "src.GUIComponentSliderInput"
local GUIDispatcher = require "src.GUIDispatcher"
local ItemPriorityManager = require "src.ItemPriorityManager"
local R = require "src.RichText"

local BUTTON_CLICK_EVENT = "arr-component-priority-set-button"
local SLIDER_INPUT_EVENT = "arr-component-priority-set-slider"


local function update_slider(slider_flow, priority_sets, set_key)
  slider_flow.clear()
  slider_flow.visible = false
  local selected_item = slider_flow.tags.item
  if not selected_item then
    return
  end

  local stack_size = game.item_prototypes[selected_item].stack_size
  if stack_size <= 1 then
    slider_flow.tags = {}
    local player = game.get_player(slider_flow.player_index)
    player.create_local_flying_text({
      text = "Can't change quantity: item has stack size of 1",
      create_at_cursor = true
    })
    return
  end
  slider_flow.visible = true
  GUIComponentSliderInput.create(
    slider_flow,
    {
      style = "slider",
      minimum_value = 1,
      maximum_value = stack_size,
      value = priority_sets[set_key].item_counts[selected_item],
      tags = { event = { [SLIDER_INPUT_EVENT] = true } }
    },
    {
      allow_negative = false,
      tags = { event = { [SLIDER_INPUT_EVENT] = true } }
    }
  )
  slider_flow.slider.style.size = { 194, 12 }
end

local function update_buttons(table_elem, priority_sets)
  local set_key = table_elem.tags.key
  local slider_flow = table_elem.parent.parent.slider_flow
  local selected_item = slider_flow.tags.item
  local items = ItemPriorityManager.get_ordered_items(priority_sets, set_key)
  table_elem.clear()
  for item_name, count in pairs(items) do
    GUICommon.create_item_button(
      table_elem,
      item_name,
      {
        number = count > 0 and count or 0,
        name = item_name,
        style = count > 0 and "logistic_slot_button" or "red_logistic_slot_button",
        elem_tooltip = true,
        tooltip = table.concat({
          R.HINT, "Right-click", R.HINT_END, " to blacklist.\n",
          R.HINT, "Shift + Left-click", R.HINT_END, " to move forwards.\n",
          R.HINT, "Shift + Right-click", R.HINT_END, " to move backwards.\n",
          R.HINT, "Control + Left-click", R.HINT_END, " to move to front.\n",
          R.HINT, "Control + Right-click", R.HINT_END, " to move to back.",
        }),
        tags = { event = BUTTON_CLICK_EVENT },
      }
    )
  end

  update_slider(slider_flow, priority_sets, set_key)
  selected_item = slider_flow.tags.item
  if selected_item then
    table_elem[selected_item].toggled = true
  end
end

local function get_component_key(domain_key, set_key)
  return domain_key .. "-" .. set_key
end

local function clear_invalid_components(component_key)
  global.priority_set_components[component_key] = flib_table.filter(
    global.priority_set_components[component_key] or {},
    function(elem, key)
      return elem.valid
    end,
    true
  )
end

local function register_component(table_elem)
  if global.priority_set_components == nil then
    global.priority_set_components = {}
  end

  local component_key = table_elem.tags.component_key
  clear_invalid_components(component_key)
  table.insert(global.priority_set_components[component_key], table_elem)
end

local function update_components(src_elem, priority_sets, update_src)
  local component_key = src_elem.tags.component_key
  clear_invalid_components(component_key)
  for _, table_elem in ipairs(global.priority_set_components[component_key] or {}) do
    if update_src or table_elem ~= src_elem then
      update_buttons(table_elem, priority_sets)
    end
  end
end

function GUIComponentItemPrioritySet.update_by_key(priority_sets, domain_key, set_key)
  local component_key = get_component_key(domain_key, set_key)
  clear_invalid_components(component_key)
  for _, table_elem in ipairs(global.priority_set_components[component_key] or {}) do
    update_buttons(table_elem, priority_sets)
  end
end

local function table_swap(t, i1, i2)
  if t[i1] == nil or t[i2] == nil then
    return false
  end
  t[i1], t[i2] = t[i2], t[i1]
  return true
end

local function array_move_item(arr, index, target_index)
  if target_index <= 0 then
    target_index = #arr
  end
  if index == target_index then
    return false
  end
  local val = table.remove(arr, index)
  table.insert(arr, target_index, val)
  return true
end

function GUIComponentItemPrioritySet.create(parent, priority_sets, set_key)
  local main_flow = parent.add({
    type = "flow",
    direction = "vertical",
    name = "priority-set-component"
  })
  local table_frame = main_flow.add({
    type = "frame",
    name = "table_frame",
    style = "arr_deep_frame",
  })
  local component_key = get_component_key(priority_sets.domain_key, set_key)
  local table_elem = table_frame.add({
    type = "table",
    name = "table",
    column_count = 10,
    style = "logistics_slot_table",
    tags = {
      domain = priority_sets.domain_key,
      key = set_key,
      component_key = component_key
    }
  })

  local slider_flow = main_flow.add({
    type = "flow",
    name = "slider_flow",
    direction = "horizontal",
    style = "player_input_horizontal_flow"
  })
  slider_flow.style.left_padding = 4
  slider_flow.visible = false

  update_buttons(table_elem, priority_sets)
  register_component(table_elem)
end

local function on_slider_input_changed(event, tags, player)
  local slider_flow = event.element.parent
  local item_name = slider_flow.tags.item
  local slider = slider_flow.slider
  local domain_key = slider_flow.tags.domain
  local priority_sets = ItemPriorityManager.get_priority_sets_for_domain(domain_key)
  local set_key = slider_flow.tags.key
  local priority_set = priority_sets[set_key]
  priority_set.item_counts[item_name] = slider.slider_value

  local table_elem = slider_flow.parent.table_frame.table
  local button = table_elem[item_name]
  button.number = slider.slider_value
  update_components(table_elem, priority_sets, false)
end

local function on_button_click(event, tags, player)
  local click_str = GUICommon.get_click_str(event)
  local table_elem = event.element.parent
  local domain_key = table_elem.tags.domain
  local priority_sets = ItemPriorityManager.get_priority_sets_for_domain(domain_key)
  local set_key = table_elem.tags.key
  local priority_set = priority_sets[set_key]
  local clicked_item_name = event.element.name
  local clicked_item_index = flib_table.find(priority_set.item_order, clicked_item_name)
  local clicked_item_count = priority_set.item_counts[clicked_item_name]
  local updated = false

  if click_str == "left" then
    local slider_flow = table_elem.parent.parent.slider_flow
    local selected_item = slider_flow.tags.item
    if selected_item == clicked_item_name then
      slider_flow.tags = {}
    elseif clicked_item_count > 0 then
      slider_flow.tags = {
        domain = domain_key,
        key = set_key,
        item = clicked_item_name,
      }
    end
    updated = true
  end

  if click_str == "right" then
    -- toggle blacklist
    priority_set.item_counts[clicked_item_name] = clicked_item_count == 0 and 1 or -clicked_item_count
    updated = true
  elseif click_str == "control-left" then
    -- move to front
    updated = array_move_item(priority_set.item_order, clicked_item_index, 1)
  elseif click_str == "control-right" then
    -- move to back
    updated = array_move_item(priority_set.item_order, clicked_item_index, -1)
  elseif click_str == "shift-left" then
    -- swap left
    updated = table_swap(priority_set.item_order, clicked_item_index, clicked_item_index - 1)
  elseif click_str == "shift-right" then
    -- swap right
    updated = table_swap(priority_set.item_order, clicked_item_index, clicked_item_index + 1)
  end

  if updated then
    update_components(table_elem, priority_sets, true)
  end
end

GUIDispatcher.register(defines.events.on_gui_click, BUTTON_CLICK_EVENT, on_button_click)
GUIDispatcher.register(defines.events.on_gui_value_changed, SLIDER_INPUT_EVENT, on_slider_input_changed)
GUIDispatcher.register(defines.events.on_gui_text_changed, SLIDER_INPUT_EVENT, on_slider_input_changed)

return GUIComponentItemPrioritySet
