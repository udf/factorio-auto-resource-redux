local GUICommon = {}
local Util = require "src.Util"
local Storage = require "src.Storage"

-- "arr" stands for auto resource redux, matey
GUICommon.GUI_LOGO_BUTTON = "arr-logo-button"
GUICommon.GUI_RESOURCE_TABLE = "arr-table"
GUICommon.GUI_LIMIT_DIALOG = "arr-limit-diag"


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

function GUICommon.create_item_button(parent, storage_key, new_attrs)
  local fluid_name = Storage.unpack_fluid_item_name(storage_key)
  local default_attrs = {
    type = "sprite-button",
    sprite = fluid_name and "fluid/" .. fluid_name or "item/" .. storage_key,
  }
  return parent.add(Util.table_merge(default_attrs, new_attrs))
end

return GUICommon
