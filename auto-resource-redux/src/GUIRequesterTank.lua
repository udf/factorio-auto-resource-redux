local GUIRequesterTank = {}
local GUICommon = require "src.GUICommon"
local GUIDispatcher = require "src.GUIDispatcher"
local GUIComponentSliderInput = require "src.GUIComponentSliderInput"
local FluidBoxScan            = require "src.FluidBoxScan"

local GUI_CLOSE_EVENT = "arr-requester-tank-close"
local FLUID_CHANGED_EVENT = "arr-requester-tank-fluid"
local PERCENT_CHANGED_EVENT = "arr-requester-tank-fluid-percent"
local USE_RANGE_EVENT = "arr-requester-tank-temp-range"
local MIN_TEMP_CHANGED_EVENT = "arr-requester-tank-temp-min"
local MAX_TEMP_CHANGED_EVENT = "arr-requester-tank-temp-max"

function GUIRequesterTank.get_paste_label(data)
  if not data then
    return ""
  end
  if data.fluid and data.min_temp and data.max_temp then
    return ("[fluid=%s] %d%% @ %d°C-%d°C"):format(data.fluid, data.percent or 0, data.min_temp, data.max_temp)
  elseif data.fluid and data.min_temp then
    return ("[fluid=%s] %d%% @ %d°C"):format(data.fluid, data.percent or 0, data.min_temp)
  elseif data.fluid then
    return ("[fluid=%s]"):format(data.fluid)
  end
  return ""
end

local function update_controls(unit_number, controls_flow)
  local opts = global.entity_data[unit_number]
  local fluid = opts.fluid
  local percent = opts.percent or 0
  local min_temp = opts.min_temp
  local max_temp = opts.max_temp

  local fluid_button = controls_flow.fluid.fluid
  fluid_button.elem_value = fluid
  GUIComponentSliderInput.set_value(controls_flow.fluid, percent)

  local fluid_proto = game.fluid_prototypes[fluid] or {}
  local fluid_min_temp = fluid_proto.default_temperature
  local fluid_max_temp = fluid_proto.max_temperature
  local can_set_temperature = fluid_min_temp and fluid_min_temp ~= fluid_max_temp
  local temp_table = controls_flow.temp
  if not can_set_temperature then
    temp_table.visible = false
    controls_flow.line.visible = false
    controls_flow.use_range.visible = false
    return
  end
  temp_table.visible = true
  controls_flow.line.visible = true
  controls_flow.use_range.visible = true
  controls_flow.use_range.state = (max_temp ~= nil)
  GUIComponentSliderInput.set_limits(temp_table.min, fluid_min_temp, fluid_max_temp)
  GUIComponentSliderInput.set_value(temp_table.min, min_temp)

  if max_temp then
    GUIComponentSliderInput.set_limits(temp_table.max, fluid_min_temp, fluid_max_temp)
    GUIComponentSliderInput.set_value(temp_table.max, max_temp)
    temp_table.max_label.visible = true
    temp_table.max.visible = true
    temp_table.min_label.caption = "Min. Temperature"
  else
    temp_table.max_label.visible = false
    temp_table.max.visible = false
    temp_table.min_label.caption = "Temperature"
  end
end

local function open_gui(entity, player)
  local unit_number = entity.unit_number
  global.entity_data[unit_number] = global.entity_data[unit_number] or {}
  local screen = player.gui.screen

  local window = screen.add({
    type = "frame",
    name = GUICommon.GUI_REQUESTER_TANK,
    direction = "vertical",
    tags = { event = GUI_CLOSE_EVENT },
    style = "inner_frame_in_outer_frame"
  })
  player.opened = window
  window.auto_center = true

  GUICommon.create_header(window, { "entity-name.arr-requester-tank" }, GUI_CLOSE_EVENT)

  local inner_frame = window.add({
    type = "frame",
    style = "inside_shallow_frame_with_padding",
  })
  local inner_flow = inner_frame.add({
    type = "flow",
    direction = "horizontal"
  })
  inner_flow.style.horizontal_spacing = 8

  local entity_frame = inner_flow.add({
    type = "frame",
    style = "deep_frame_in_shallow_frame"
  })
  local entity_preview = entity_frame.add({
    type = "entity-preview",
    style = "entity_button_base"
  })
  entity_preview.entity = entity

  local controls_flow = inner_flow.add({
    type = "flow",
    direction = "vertical"
  })

  local fluid_controls_flow = controls_flow.add({
    type = "flow",
    name = "fluid",
    style = "player_input_horizontal_flow",
  })
  local fluid_button = fluid_controls_flow.add({
    type = "choose-elem-button",
    name = "fluid",
    elem_type = "fluid",
    style = "slot_button_in_shallow_frame",
    tags = { id = unit_number, event = FLUID_CHANGED_EVENT }
  })
  GUIComponentSliderInput.create(
    fluid_controls_flow,
    {
      style = "slider",
      minimum_value = 0,
      maximum_value = 100,
      value = 0,
      tags = { id = unit_number, event = { [PERCENT_CHANGED_EVENT] = true } }
    },
    {
      allow_negative = false,
      tags = { id = unit_number, event = { [PERCENT_CHANGED_EVENT] = true } }
    }
  )
  fluid_controls_flow.add({
    type = "label",
    caption = "%",
  })

  controls_flow.add({
    type = "line",
    name = "line"
  })

  controls_flow.add({
    type = "checkbox",
    name = "use_range",
    state = false,
    caption = "Use temperature range",
    tags = { id = unit_number, event = USE_RANGE_EVENT }
  })

  local temp_opts_table = controls_flow.add({
    type = "table",
    name = "temp",
    column_count = 2,
    vertical_centering = true
  })

  local label = temp_opts_table.add({
    type = "label",
    name = "min_label",
    caption = "Min. Temperature",
  })
  label.style.right_padding = 4
  local min_temp_flow = temp_opts_table.add({
    type = "flow",
    name = "min",
    style = "player_input_horizontal_flow"
  })
  GUIComponentSliderInput.create(
    min_temp_flow,
    {
      style = "slider",
      tags = { id = unit_number, event = { [MIN_TEMP_CHANGED_EVENT] = true } }
    },
    {
      allow_negative = false,
      tags = { id = unit_number, event = { [MIN_TEMP_CHANGED_EVENT] = true } }
    }
  )

  label = temp_opts_table.add({
    type = "label",
    name = "max_label",
    caption = "Max. Temperature",
  })
  label.style.right_padding = 4
  local max_temp_flow = temp_opts_table.add({
    type = "flow",
    name = "max",
    style = "player_input_horizontal_flow"
  })
  GUIComponentSliderInput.create(
    max_temp_flow,
    {
      style = "slider",
      tags = { id = unit_number, event = { [MAX_TEMP_CHANGED_EVENT] = true } }
    },
    {
      allow_negative = false,
      tags = { id = unit_number, event = { [MAX_TEMP_CHANGED_EVENT] = true } }
    }
  )

  local data = global.entity_data[unit_number]
  if not data.fluid then
    FluidBoxScan.autoconfig_request(entity, data)
  end

  update_controls(entity.unit_number, controls_flow)
end

local function on_gui_opened(event, tags, player)
  if event.entity and event.entity.name == "arr-requester-tank" then
    open_gui(event.entity, player)
  end
end

local function on_close(event, tags, player)
  local window = player.gui.screen[GUICommon.GUI_REQUESTER_TANK]
  player.opened = nil
  window.destroy()
end

local function on_fluid_changed(event, tags, player)
  local fluid = event.element.elem_value
  local default_temp = fluid and game.fluid_prototypes[fluid].default_temperature or nil
  local data = global.entity_data[tags.id]
  data.fluid = fluid
  data.percent = data.percent or 5
  data.min_temp = default_temp
  data.max_temp = data.max_temp and default_temp or nil
  local controls_flow = event.element.parent.parent
  update_controls(tags.id, controls_flow)
  player.gui.screen[GUICommon.GUI_REQUESTER_TANK].force_auto_center()
end

local function on_percent_changed(event, tags, player)
  local data = global.entity_data[tags.id]
  data.percent = event.element.parent.slider.slider_value
end

local function on_use_range_checked(event, tags, player)
  local data = global.entity_data[tags.id]
  data.max_temp = event.element.state and data.min_temp or nil
  local controls_flow = event.element.parent
  update_controls(tags.id, controls_flow)
  player.gui.screen[GUICommon.GUI_REQUESTER_TANK].force_auto_center()
end

local function on_min_temp_changed(event, tags, player)
  local data = global.entity_data[tags.id]
  local parent = event.element.parent
  local min_temp = parent.slider.slider_value
  data.min_temp = min_temp
  if data.max_temp and min_temp > data.max_temp then
    data.max_temp = min_temp
    GUIComponentSliderInput.set_value(parent.parent.max, min_temp)
  end
end

local function on_max_temp_changed(event, tags, player)
  local data = global.entity_data[tags.id]
  local parent = event.element.parent
  local max_temp = parent.slider.slider_value
  data.max_temp = max_temp
  if max_temp < data.min_temp then
    data.min_temp = max_temp
    GUIComponentSliderInput.set_value(parent.parent.min, max_temp)
  end
end

GUIDispatcher.register(defines.events.on_gui_opened, nil, on_gui_opened)

GUIDispatcher.register(defines.events.on_gui_click, GUI_CLOSE_EVENT, on_close)
GUIDispatcher.register(defines.events.on_gui_closed, GUI_CLOSE_EVENT, on_close)

GUIDispatcher.register(defines.events.on_gui_elem_changed, FLUID_CHANGED_EVENT, on_fluid_changed)
GUIDispatcher.register(defines.events.on_gui_value_changed, PERCENT_CHANGED_EVENT, on_percent_changed)
GUIDispatcher.register(defines.events.on_gui_text_changed, PERCENT_CHANGED_EVENT, on_percent_changed)

GUIDispatcher.register(defines.events.on_gui_checked_state_changed, USE_RANGE_EVENT, on_use_range_checked)

GUIDispatcher.register(defines.events.on_gui_value_changed, MIN_TEMP_CHANGED_EVENT, on_min_temp_changed)
GUIDispatcher.register(defines.events.on_gui_text_changed, MIN_TEMP_CHANGED_EVENT, on_min_temp_changed)

GUIDispatcher.register(defines.events.on_gui_value_changed, MAX_TEMP_CHANGED_EVENT, on_max_temp_changed)
GUIDispatcher.register(defines.events.on_gui_text_changed, MAX_TEMP_CHANGED_EVENT, on_max_temp_changed)

return GUIRequesterTank
