local GUIComponentSliderInput = {}
local flib_table = require("__flib__/table")
local Util = require "src.Util"
local GUIDispatcher = require "src.GUIDispatcher"

local SLIDER_EVENT = "arr-component-slider"
local INPUT_EVENT = "arr-component-slider-input"

function GUIComponentSliderInput.create(parent, slider_attrs, input_attrs)
  local slider = parent.add(flib_table.deep_merge({
    {
      type = "slider",
      name = "slider",
      style = "notched_slider",
      tags = { event = { [SLIDER_EVENT] = true } }
    },
    slider_attrs
  }))
  parent.add(flib_table.deep_merge({
    {
      type = "textfield",
      name = "input",
      style = "slider_value_textfield",
      text = slider.slider_value,
      numeric = true,
      allow_decimal = false,
      tags = { event = { [INPUT_EVENT] = true } }
    },
    input_attrs
  }))
end

local function on_slider_changed(event, tags, player)
  event.element.parent.input.text = tostring(event.element.slider_value)
end

local function on_text_changed(event, tags, player)
  local slider = event.element.parent.slider
  local new_value = Util.clamp(tonumber(event.element.text) or 0, slider.get_slider_minimum(), slider.get_slider_maximum())
  event.element.text = tostring(new_value)
  slider.slider_value = new_value
end

GUIDispatcher.register(defines.events.on_gui_value_changed, SLIDER_EVENT, on_slider_changed)
GUIDispatcher.register(defines.events.on_gui_text_changed, INPUT_EVENT, on_text_changed)

return GUIComponentSliderInput
