local GUICommon = {}

local mouse_button_str = {
  [defines.mouse_button_type.left] = "left",
  [defines.mouse_button_type.right] = "right",
  [defines.mouse_button_type.middle] = "middle",
}

function GUICommon.get_click_str(event)
  local str = ""
  if event.control then
    str = "control-" .. str
  end
  if event.shift then
    str = "shift-" .. str
  end
  if event.alt then
    str = "alt-" .. str
  end
  return str .. (mouse_button_str[event.button] or "none")
end

return GUICommon