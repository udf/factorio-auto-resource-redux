local GUICommon = {}
local Util = require "src.Util"
local Storage = require "src.Storage"

-- "arr" stands for auto resource redux, matey
GUICommon.GUI_LOGO_BUTTON = "arr-logo-button"
GUICommon.GUI_RESOURCE_TABLE = "arr-res-tables"
GUICommon.GUI_LIMIT_DIALOG = "arr-limit-diag"
GUICommon.GUI_ITEM_PRIORITY = "arr-priority-list"
GUICommon.GUI_REQUESTER_TANK = "arr-requester-tank"


local mouse_button_str = {
  [defines.mouse_button_type.left] = "left",
  [defines.mouse_button_type.right] = "right",
  [defines.mouse_button_type.middle] = "middle",
}

-- awful hack to export res table function, this will be assigned in GUIResourceList
GUICommon.get_or_create_reslist_button = nil

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
  if new_attrs.elem_tooltip == true then
    new_attrs.elem_tooltip = {
      type = fluid_name and "fluid" or "item",
      name = fluid_name or storage_key
    }
  end
  return parent.add(Util.table_merge(default_attrs, new_attrs))
end

function GUICommon.create_header(parent, title, close_event)
  local header_flow = parent.add({
    type = "flow",
    direction = "horizontal",
  })
  header_flow.drag_target = parent

  header_flow.add {
    type = "label",
    caption = title,
    style = "frame_title",
    ignored_by_interaction = true,
  }

  local header_drag = header_flow.add {
    type = "empty-widget",
    style = "draggable_space_header",
    ignored_by_interaction = true,
  }
  header_drag.style.height = 24
  header_drag.style.horizontally_stretchable = true
  header_drag.style.vertically_stretchable = true

  header_flow.add {
    type = "sprite-button",
    sprite = "utility/close_white",
    hovered_sprite = "utility/close_black",
    clicked_sprite = "utility/close_black",
    style = "cancel_close_button",
    tags = { event = close_event },
  }

  return header_flow
end

return GUICommon
