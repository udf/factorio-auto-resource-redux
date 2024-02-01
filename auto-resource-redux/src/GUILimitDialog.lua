local GUILimitDialog = {}
local Storage = require "src.Storage"
local GUIDispatcher = require "src.GUIDispatcher"
local GUIComponentSliderInput = require "src.GUIComponentSliderInput"
local GUICommon = require "src.GUICommon"

local GUI_CLOSE_EVENT = "arr-limit-close"
local CLOSE_BUTTON_EVENT = "arr-limit-close-btn"
local CONFIRM_BUTTON_EVENT = "arr-limit-confirm"


local function highlight_reslist_button(player, storage_key, state)
  local elem = player.gui.top[GUICommon.GUI_RESOURCE_TABLE][storage_key]
  elem.toggled = state == true
end

function GUILimitDialog.open(player, storage_key, cursor_location)
  local storage = Storage.get_storage(player)
  local screen = player.gui.screen
  local dialog = screen[GUICommon.GUI_LIMIT_DIALOG]
  if dialog then
    local old_item = dialog.tags.item
    highlight_reslist_button(player, old_item, false)
    dialog.destroy()
    -- clicking a second time will close the GUI
    if old_item == storage_key then
      return
    end
  end
  local item_limit = Storage.get_item_limit(storage, storage_key)
  if not item_limit then
    return
  end

  highlight_reslist_button(player, storage_key, true)

  dialog = screen.add({
    type = "frame",
    name = GUICommon.GUI_LIMIT_DIALOG,
    direction = "vertical",
    tags = { item = storage_key, event = GUI_CLOSE_EVENT }
  })
  dialog.location = { cursor_location.x, cursor_location.y + 30 }
  -- Only count as the "current" gui if nothing else is open
  if player.opened_gui_type == defines.gui_type.none then
    player.opened = dialog
  end

  GUICommon.create_header(dialog, "Set storage limit", CLOSE_BUTTON_EVENT)

  local inner_frame = dialog.add({
    type = "frame",
    name = "inner_frame",
    style = "inside_shallow_frame_with_padding",
  })

  local content_flow = inner_frame.add({
    type = "flow",
    name = "content",
    direction = "horizontal",
    style = "player_input_horizontal_flow"
  })

  local fluid_name = Storage.unpack_fluid_item_name(storage_key)
  GUICommon.create_item_button(
    content_flow,
    storage_key,
    {
      elem_tooltip = true,
      style = "inventory_slot"
    }
  )

  local max_limit = fluid_name and Storage.MAX_FLUID_LIMIT or Storage.MAX_ITEM_LIMIT
  GUIComponentSliderInput.create(
    content_flow,
    {
      value_step = math.floor(max_limit / 20),
      maximum_value = max_limit,
      value = item_limit
    },
    {
      allow_negative = false,
    }
  )

  content_flow.add({
    type = "sprite-button",
    sprite = "utility/check_mark",
    style = "item_and_count_select_confirm",
    tags = { event = CONFIRM_BUTTON_EVENT }
  })
end

local function on_close(event, tags, player)
  local dialog = player.gui.screen[GUICommon.GUI_LIMIT_DIALOG]
  if not dialog then
    return
  end

  -- make ourselves the currently open GUI if something else closed
  if not tags and player.opened_gui_type == defines.gui_type.none then
    player.opened = dialog
    return
  end

  highlight_reslist_button(player, dialog.tags.item, false)
  dialog.destroy()
end

local function on_confirm(event, tags, player)
  local dialog = player.gui.screen[GUICommon.GUI_LIMIT_DIALOG]
  if not dialog or player.opened ~= dialog then
    return
  end
  local storage_key = dialog.tags.item
  local storage = Storage.get_storage(player)
  local new_limit = tonumber(dialog.inner_frame.content.input.text) or Storage.get_item_limit(storage, storage_key)
  Storage.set_item_limit(storage, storage_key, new_limit)
  on_close(event, tags, player)
end

GUIDispatcher.register(defines.events.on_gui_click, CLOSE_BUTTON_EVENT, on_close)
GUIDispatcher.register(defines.events.on_gui_click, CONFIRM_BUTTON_EVENT, on_confirm)
GUIDispatcher.register(GUIDispatcher.ON_CONFIRM, nil, on_confirm)
GUIDispatcher.register(defines.events.on_gui_closed, GUI_CLOSE_EVENT, on_close)
GUIDispatcher.register(defines.events.on_gui_closed, nil, on_close)

return GUILimitDialog
