local GUIComponentSliderInput = {}
local flib_table = require("__flib__/table")
local Util = require "src.Util"
local GUIDispatcher = require "src.GUIDispatcher"

local SLIDER_EVENT = "arr-component-slider"
local INPUT_EVENT = "arr-component-slider-input"

local function get_closest_step_index(value, step_values)
  local min_i = 1
  local min_dist = math.huge
  for i, step_val in ipairs(step_values) do
    local dist = math.abs(value - step_val)
    if dist <= min_dist then
      min_dist = dist
      min_i = i
    end
  end
  return min_i
end

local function remove_duplicates(array)
  local seen = {}
  local out = {}
  for i, val in ipairs(array) do
    if not seen[val] then
      table.insert(out, val)
      seen[val] = true
    end
  end
  return out
end

local function scale_array(array, scale, min, max)
  local out = {}
  for i, val in ipairs(array) do
    table.insert(
      out,
      Util.clamp(math.ceil(val * scale), min or -math.huge, max or math.huge)
    )
  end
  return out
end

function GUIComponentSliderInput.set_limits(parent, min_val, max_val)
  local slider = parent.slider
  local input = parent.input
  slider.tags = Util.table_merge(slider.tags, { min = min_val, max = max_val })
  input.tags = Util.table_merge(input.tags, { min = min_val, max = max_val })
  if slider.tags.steps then
    slider.set_slider_minimum_maximum(1, #slider.tags.steps)
  else
    slider.set_slider_minimum_maximum(min_val, max_val)
  end
end

function GUIComponentSliderInput.create(parent, slider_attrs, input_attrs, slider_steps, slider_mult, min_val, max_val)
  local value = slider_attrs.value or 0
  if slider_steps then
    slider_steps = remove_duplicates(scale_array(slider_steps, slider_mult or 1, min_val, max_val))
    slider_attrs.value_step = 1
  end
  local slider = parent.add(flib_table.deep_merge({
    {
      type = "slider",
      name = "slider",
      style = "notched_slider",
      tags = {
        event = { [SLIDER_EVENT] = true },
        steps = slider_steps,
      }
    },
    slider_attrs
  }))
  local input = parent.add(flib_table.deep_merge({
    {
      type = "textfield",
      name = "input",
      style = "slider_value_textfield",
      text = value,
      numeric = true,
      allow_decimal = false,
      tags = { event = { [INPUT_EVENT] = true } }
    },
    input_attrs
  }))

  GUIComponentSliderInput.set_limits(
    parent,
    min_val or slider.get_slider_minimum(),
    max_val or slider.get_slider_maximum()
  )
  if slider_steps then
    slider.slider_value = get_closest_step_index(value, slider_steps)
  end
end

function GUIComponentSliderInput.set_value(parent, value)
  local slider = parent.slider
  local input = parent.input
  local new_value = Util.clamp(value or 0, input.tags.min, input.tags.max)
  input.text = tostring(new_value)
  if slider.tags.steps then
    new_value = get_closest_step_index(new_value, slider.tags.steps)
  end
  slider.slider_value = new_value
end

local function on_slider_changed(event, tags, player)
  local new_value = event.element.slider_value
  local input = event.element.parent.input
  if tags.steps then
    new_value = Util.clamp(tags.steps[new_value], tags.min, tags.max)
  end
  input.text = tostring(new_value)
end

local function on_text_changed(event, tags, player)
  GUIComponentSliderInput.set_value(event.element.parent, tonumber(event.element.text) or 0)
end

GUIDispatcher.register(defines.events.on_gui_value_changed, SLIDER_EVENT, on_slider_changed)
GUIDispatcher.register(defines.events.on_gui_text_changed, INPUT_EVENT, on_text_changed)

return GUIComponentSliderInput
