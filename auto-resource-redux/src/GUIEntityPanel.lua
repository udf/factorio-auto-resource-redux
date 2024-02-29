local GUIEntityPanel = {}

local flib_table = require("__flib__/table")
local EntityCondition = require "src.EntityCondition"
local EntityGroups = require "src.EntityGroups"
local FurnaceRecipeManager = require "src.FurnaceRecipeManager"
local GUICommon = require "src.GUICommon"
local GUIComponentSliderInput = require "src.GUIComponentSliderInput"
local GUIDispatcher = require "src.GUIDispatcher"
local ItemPriorityManager = require "src.ItemPriorityManager"
local Storage = require "src.Storage"

local GUI_CLOSE_EVENT = "arr-entity-panel-close"
local PRIORITISE_CHECKED_EVENT = "arr-entity-panel-prioritise"
local CONDITION_ITEM_EVENT = "arr-entity-panel-condition-item"
local CONDITION_OP_EVENT = "arr-entity-panel-condition-op"
local CONDITION_VALUE_BUTTON_EVENT = "arr-entity-panel-condition-button"
local CONDITION_VALUE_CHANGED_EVENT = "arr-entity-panel-condition-value-changed"
local FURNACE_RECIPE_EVENT = "arr-entity-panel-furnace-recipe"

local EntityTypeGUIAnchors = {
  ["assembling-machine"] = defines.relative_gui_type.assembling_machine_gui,
  ["car"] = defines.relative_gui_type.car_gui,
  ["logistic-container"] = defines.relative_gui_type.container_gui,
  ["furnace"] = defines.relative_gui_type.furnace_gui,
  ["lab"] = defines.relative_gui_type.lab_gui,
  ["mining-drill"] = defines.relative_gui_type.mining_drill_gui,
  ["boiler"] = defines.relative_gui_type.entity_with_energy_source_gui,
  ["ammo-turret"] = defines.relative_gui_type.container_gui,
  ["reactor"] = defines.relative_gui_type.reactor_gui,
  ["storage-tank"] = defines.relative_gui_type.storage_tank_gui,
  ["rocket-silo"] = defines.relative_gui_type.rocket_silo_gui,
  ["spider-vehicle"] = defines.relative_gui_type.spider_vehicle_gui
}

function GUIEntityPanel.initialise()
  if global.entity_panel_pending_relocations == nil then
    global.entity_panel_pending_relocations = {}
  end
  if global.entity_panel_location == nil then
    global.entity_panel_location = {}
  end
end

local function get_location_key(player, entity_name)
  return ("%d;%s;%s;%s"):format(
    player.index,
    player.opened.get_mod(),
    entity_name,
    player.opened.name
  )
end

local function add_panel_frame(parent, caption, tooltip)
  parent.add({
    type = "line",
    style = "control_behavior_window_line"
  })
  local frame = parent.add({
    type = "frame",
    style = "invisible_frame",
    direction = "vertical"
  })
  local label = frame.add({
    type = "label",
    style = "heading_2_label",
    caption = caption,
    tooltip = tooltip
  })
  label.style.padding = { 4, 0, 4, 0 }
  return frame
end

local function add_gui_content(window, entity)
  local frame = window.add({
    type = "frame",
    style = "inside_shallow_frame_with_padding",
    direction = "vertical"
  })

  local data_id = entity.unit_number
  -- Prioritise
  local data = global.entity_data[data_id]
  if not data then
    data = {}
    global.entity_data[data_id] = data
  end
  frame.add({
    type = "checkbox",
    caption = "Prioritise [img=info]",
    tooltip = "Allow consumption of reserved resources",
    state = (data.use_reserved == true),
    tags = { id = data_id, event = PRIORITISE_CHECKED_EVENT }
  })
  frame.add({
    type = "line",
    style = "control_behavior_window_line"
  })

  -- Condition
  if not data.condition then
    data.condition = {}
  end
  local condition = data.condition
  local condition_value = condition.value or 0
  local condition_frame = frame.add({
    type = "frame",
    name = "condition_frame",
    style = "invisible_frame_with_title",
    caption = { "gui-control-behavior-modes-guis.enabled-condition" },
    direction = "vertical"
  })
  local condition_controls_flow = condition_frame.add({
    type = "flow",
    name = "condition_controls_flow",
    direction = "horizontal"
  })
  condition_controls_flow.style.vertical_align = "center"
  local fluid_name = Storage.unpack_fluid_item_name(condition.item or "")
  condition_controls_flow.add({
    type = "choose-elem-button",
    elem_type = "signal",
    style = "slot_button_in_shallow_frame",
    signal = {
      type = fluid_name and "fluid" or "item",
      name = fluid_name or condition.item
    },
    tags = { id = data_id, event = CONDITION_ITEM_EVENT }
  })
  condition_controls_flow.add({
    type = "drop-down",
    items = EntityCondition.OPERATIONS,
    selected_index = condition.op or 1,
    style = "circuit_condition_comparator_dropdown",
    tags = { id = data_id, event = CONDITION_OP_EVENT }
  })
  local condition_value_btn = condition_controls_flow.add({
    type = "button",
    name = "condition_value",
    style = "slot_button_in_shallow_frame",
    caption = condition_value .. "%",
    tags = { event = CONDITION_VALUE_BUTTON_EVENT }
  })
  condition_value_btn.style.font_color = { 1, 1, 1 }

  local condition_slider_flow = condition_frame.add({
    type = "flow",
    name = "slider_flow",
    style = "player_input_horizontal_flow",
  })
  condition_slider_flow.style.top_padding = 4
  condition_slider_flow.visible = false
  GUIComponentSliderInput.create(
    condition_slider_flow,
    {
      value = condition_value,
      maximum_value = 100,
      style = "slider",
      tags = { id = data_id, event = { [CONDITION_VALUE_CHANGED_EVENT] = true } }
    },
    {
      allow_negative = false,
      style = "very_short_number_textfield",
      tags = { id = data_id, event = { [CONDITION_VALUE_CHANGED_EVENT] = true } }
    }
  )
  condition_slider_flow.slider.style.width = 100
  condition_slider_flow.add({
    type = "label",
    caption = "%",
  })

  if entity.type == "furnace" then
    local sub_frame = add_panel_frame(
      frame,
      { "", { "description.recipe" }, " [img=info]" },
      "The new recipe will be applied on the next production cycle, when the productivity bar is empty."
    )
    local current_recipe = FurnaceRecipeManager.get_recipe(entity)
    local filters = {}
    for category, _ in pairs(entity.prototype.crafting_categories) do
      table.insert(filters, { filter = "category", category = category })
    end
    sub_frame.add({
      type = "choose-elem-button",
      elem_type = "recipe",
      style = "slot_button_in_shallow_frame",
      recipe = current_recipe and current_recipe.name or nil,
      elem_filters = filters,
      tags = { id = data_id, event = FURNACE_RECIPE_EVENT }
    })
  end

  local priority_sets = ItemPriorityManager.get_priority_sets_for_entity(entity)
  -- { [group] = { set1_key, set2_key, ... } }
  local related_priority_set_keys = {}
  for set_key, priority_set in pairs(priority_sets) do
    if priority_set.group then
      local sets = related_priority_set_keys[priority_set.group] or {}
      table.insert(sets, set_key)
      related_priority_set_keys[priority_set.group] = sets
    end
  end
  if table_size(related_priority_set_keys) > 0 then
    local sub_frame = add_panel_frame(
      frame,
      "Item Priority [img=info]",
      { "", ("Effects every [entity=%s] "):format(entity.name), entity.localised_name }
    )
    sub_frame.style.vertically_stretchable = false
    local inner_flow = sub_frame.add({
      type = "flow",
      direction = "vertical"
    })
    inner_flow.style.left_margin = 4
    inner_flow.style.vertical_spacing = 0
    for group, set_keys in pairs(related_priority_set_keys) do
      local label = inner_flow.add({
        type = "label",
        style = "heading_2_label",
        caption = group,
      })
      label.style.bottom_padding = 0
      for _, set_key in ipairs(set_keys) do
        local flow = inner_flow.add({
          type = "flow",
        })
        GUIComponentItemPrioritySet.create(flow, priority_sets, set_key)
      end
    end
  end
end

local function close_gui(player)
  local last_position = nil
  local window = player.gui.relative[GUICommon.GUI_ENTITY_PANEL]
  if window then
    window.destroy()
  end

  window = player.gui.screen[GUICommon.GUI_ENTITY_PANEL]
  if window then
    last_position = window.location
    window.destroy()
  end
  return last_position
end

local function on_gui_opened(event, tags, player)
  local last_position = close_gui(player)
  local entity = event.entity
  if not entity or not EntityGroups.can_manage(entity) then
    return
  end

  -- if .opened is a custom UI, then open on screen instead because we can't anchor
  if player.opened and player.opened.object_name == "LuaGuiElement" then
    local parent = player.gui.screen
    local window = parent.add({
      type = "frame",
      name = GUICommon.GUI_ENTITY_PANEL,
      direction = "vertical",
      style = "inner_frame_in_outer_frame",
      tags = { entity_name = entity.name }
    })
    GUICommon.create_header(window, "Auto Resource", GUI_CLOSE_EVENT)
    -- use the location from the previous time a similar UI was opened
    -- this might be incorrect, but should be corrected on the next tick
    local location_key = get_location_key(player, entity.name)
    last_position = global.entity_panel_location[location_key] or last_position
    if last_position then
      window.location = last_position
    else
      window.force_auto_center()
    end
    -- the position of the parent GUI will only be known on the next tick
    -- so set a flag for on_tick to reposition us later
    global.entity_panel_pending_relocations[player.index] = {
      player = player,
      tick = game.tick + 1
    }
    add_gui_content(window, entity)
    return
  end

  local anchor = EntityTypeGUIAnchors[entity.type]
  if not anchor then
    log(("FIXME: don't know how to anchor to entity GUI name=%s type=%s"):format(entity.name, entity.type))
    return
  end

  local relative = player.gui.relative
  local window = relative[GUICommon.GUI_ENTITY_PANEL]
  window = relative.add({
    type = "frame",
    name = GUICommon.GUI_ENTITY_PANEL,
    direction = "vertical",
    style = "inner_frame_in_outer_frame",
    anchor = {
      position = defines.relative_gui_position.right,
      gui = anchor,
    },
    caption = "Auto Resource",
    tags = { entity_id = entity.unit_number }
  })
  add_gui_content(window, entity)
end

local function on_gui_closed(event, tags, player)
  close_gui(player)
end

function GUIEntityPanel.on_tick()
  -- assume mod UI is centered and reposition our panel based on the guessed width
  for player_id, t in pairs(global.entity_panel_pending_relocations) do
    if game.tick < t.tick then
      goto continue
    end
    if t.player.opened then
      local window = t.player.gui.screen[GUICommon.GUI_ENTITY_PANEL]
      local parent_location = t.player.opened.location
      local tags = window.tags
      -- remember the location, so we can use it for the initial frame when a similar UI opens
      -- we don't account for the parent size, so it might positioned incorrectly
      -- but it is less distracting than being in the center
      local basic_location_key = get_location_key(t.player, tags.entity_name)
      tags.location_key = ("%s;%d;%d"):format(basic_location_key, parent_location.x, parent_location.y)
      window.tags = tags
      local previous_location = global.entity_panel_location[tags.location_key]
      if previous_location then
        window.location = previous_location
        global.entity_panel_location[basic_location_key] = previous_location
      else
        local res = t.player.display_resolution
        local guessed_width = (res.width / 2 - parent_location.x) * 2
        if guessed_width > 0 then
          window.location = { parent_location.x + guessed_width, parent_location.y }
          global.entity_panel_location[basic_location_key] = window.location
        end
      end
    end
    global.entity_panel_pending_relocations[player_id] = nil
    ::continue::
  end
end

function GUIEntityPanel.on_location_changed(event)
  if event.element.name == GUICommon.GUI_ENTITY_PANEL then
    local location_key = event.element.tags.location_key
    if location_key then
      global.entity_panel_location[location_key] = event.element.location
    end
  end
end

local function on_prioritise_checked(event, tags, player)
  global.entity_data[tags.id].use_reserved = event.element.state
end

local function on_condition_item_changed(event, tags, player)
  local signal = event.element.elem_value
  local storage_key = signal and (signal.type == "fluid" and Storage.get_fluid_storage_key(signal.name) or signal.name)
  if signal and (signal.type == "virtual" or not Storage.can_store(storage_key)) then
    event.element.elem_value = nil
    return
  end
  global.entity_data[tags.id].condition.item = storage_key
end

local function on_condition_op_changed(event, tags, player)
  global.entity_data[tags.id].condition.op = event.element.selected_index
end

local function on_condition_value_clicked(event, tags, player)
  local slider_flow = event.element.parent.parent.slider_flow
  event.element.toggled = not event.element.toggled
  slider_flow.visible = event.element.toggled
end

local function on_condition_value_changed(event, tags, player)
  local new_value = event.element.parent.input.text
  local condition_controls_flow = event.element.parent.parent.condition_controls_flow
  condition_controls_flow.condition_value.caption = new_value .. "%"
  global.entity_data[tags.id].condition.value = tonumber(new_value)
end

local function on_furnace_recipe_changed(event, tags, player)
  local new_recipe_name = event.element.elem_value
  local entity = global.entities[event.element.tags.id]
  if not new_recipe_name then
    local recipe = FurnaceRecipeManager.get_recipe(entity)
    event.element.elem_value = recipe and recipe.name
    return
  end
  FurnaceRecipeManager.set_recipe(entity, new_recipe_name)
end

GUIDispatcher.register(defines.events.on_gui_click, GUI_CLOSE_EVENT, on_gui_closed)

GUIDispatcher.register(defines.events.on_gui_opened, nil, on_gui_opened)
GUIDispatcher.register(defines.events.on_gui_closed, nil, on_gui_closed)

GUIDispatcher.register(defines.events.on_gui_checked_state_changed, PRIORITISE_CHECKED_EVENT, on_prioritise_checked)

GUIDispatcher.register(defines.events.on_gui_elem_changed, CONDITION_ITEM_EVENT, on_condition_item_changed)
GUIDispatcher.register(defines.events.on_gui_selection_state_changed, CONDITION_OP_EVENT, on_condition_op_changed)
GUIDispatcher.register(defines.events.on_gui_click, CONDITION_VALUE_BUTTON_EVENT, on_condition_value_clicked)
GUIDispatcher.register(defines.events.on_gui_value_changed, CONDITION_VALUE_CHANGED_EVENT, on_condition_value_changed)
GUIDispatcher.register(defines.events.on_gui_text_changed, CONDITION_VALUE_CHANGED_EVENT, on_condition_value_changed)

GUIDispatcher.register(defines.events.on_gui_elem_changed, FURNACE_RECIPE_EVENT, on_furnace_recipe_changed)

return GUIEntityPanel
