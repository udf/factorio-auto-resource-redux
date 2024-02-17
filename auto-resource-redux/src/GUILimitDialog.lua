local GUILimitDialog = {}
local Storage = require "src.Storage"
local GUIDispatcher = require "src.GUIDispatcher"
local GUIComponentSliderInput = require "src.GUIComponentSliderInput"
local GUICommon = require "src.GUICommon"

local GUI_CLOSE_EVENT = "arr-limit-close"
local CLOSE_BUTTON_EVENT = "arr-limit-close-btn"
local UPDATED_LIMIT_EVENT = "arr-limit-updated-limit"
local UPDATED_RESERVED_EVENT = "arr-limit-updated-reserved"
local RESERVE_CHECKBOX_EVENT = "arr-limit-reserve-checked"
local CONFIRM_BUTTON_EVENT = "arr-limit-confirm"
local INPUT_CONFIRMED_EVENT = "arr-limit-input-confirm"

local SLIDER_STEPS = { 0, 1, 2, 3, 4, 5, 10, 15, 20, 25, 50, 75, 100, 150, 200, 250, math.huge }


local function highlight_reslist_button(player, storage_key, state)
  local elem = GUICommon.get_or_create_reslist_button(player, storage_key)
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
    direction = "horizontal"
  })

  local fluid_name = Storage.unpack_fluid_item_name(storage_key)
  GUICommon.create_item_button(
    inner_frame,
    storage_key,
    {
      elem_tooltip = true,
      style = "inventory_slot"
    }
  )

  local controls_flow = inner_frame.add({
    type = "flow",
    name = "controls_flow",
    direction = "vertical",
  })

  local limit_controls_flow = controls_flow.add({
    type = "flow",
    name = "limit",
    direction = "horizontal",
    style = "player_input_horizontal_flow"
  })
  limit_controls_flow.style.minimal_height = 40

  local max_limit = fluid_name and Storage.MAX_FLUID_LIMIT or Storage.MAX_ITEM_LIMIT
  local prototype = (game.item_prototypes[storage_key] or {})
  local slider_mult = fluid_name and 1000 or (prototype.stack_size or 50)
  GUIComponentSliderInput.create(
    limit_controls_flow,
    {
      value = item_limit,
      tags = { event = { [UPDATED_LIMIT_EVENT] = true } }
    },
    {
      allow_negative = false,
      tags = { event = { [INPUT_CONFIRMED_EVENT] = true, [UPDATED_LIMIT_EVENT] = true } }
    },
    SLIDER_STEPS,
    slider_mult,
    0,
    max_limit
  )

  limit_controls_flow.add({
    type = "sprite-button",
    sprite = "utility/check_mark",
    style = "item_and_count_select_confirm",
    tags = { event = CONFIRM_BUTTON_EVENT }
  })

  controls_flow.add({
    type = "line"
  })

  local reservation = Storage.get_item_reservation(storage, storage_key)
  controls_flow.add({
    type = "checkbox",
    state = reservation > 0,
    caption = "Reserve [img=info]",
    tooltip = "Reserve some items for usage by prioritised entities",
    tags = { event = RESERVE_CHECKBOX_EVENT }
  })

  local reservation_controls_flow = controls_flow.add({
    type = "flow",
    name = "reservation",
    direction = "horizontal",
    style = "player_input_horizontal_flow"
  })
  reservation_controls_flow.visible = reservation > 0

  GUIComponentSliderInput.create(
    reservation_controls_flow,
    {
      value = reservation,
      tags = { event = { [UPDATED_RESERVED_EVENT] = true } }
    },
    {
      allow_negative = false,
      tags = { event = { [INPUT_CONFIRMED_EVENT] = true, [UPDATED_RESERVED_EVENT] = true } }
    },
    SLIDER_STEPS,
    slider_mult,
    0,
    max_limit
  )
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
  local controls_flow = dialog.inner_frame.controls_flow
  local storage = Storage.get_storage(player)
  local storage_key = dialog.tags.item
  Storage.set_item_limit_and_reservation(
    storage, storage_key, player,
    tonumber(controls_flow.limit.input.text),
    tonumber(controls_flow.reservation.input.text)
  )
  on_close(event, tags, player)
end

local function on_gui_confirm(event, tags, player)
  local dialog = player.gui.screen[GUICommon.GUI_LIMIT_DIALOG]
  if not dialog or player.opened ~= dialog then
    return
  end
  on_confirm(event, tags, player)
end

local function on_value_changed(player, fix_limit, fix_reservation)
  local dialog = player.gui.screen[GUICommon.GUI_LIMIT_DIALOG]
  local controls_flow = dialog.inner_frame.controls_flow
  local storage = Storage.get_storage(player)
  local storage_key = dialog.tags.item
  local gui_limit = tonumber(controls_flow.limit.input.text)
  local gui_reservation = tonumber(controls_flow.reservation.input.text)
  local new_limit, new_reservation, cur_limit, cur_reservation = Storage.calc_new_limit_and_reservation(
    storage, storage_key,
    gui_limit,
    gui_reservation,
    fix_limit and gui_limit,
    fix_reservation and gui_reservation
  )
  if new_reservation ~= cur_reservation then
    GUIComponentSliderInput.set_value(controls_flow.reservation, new_reservation)
  end
  if new_limit ~= cur_limit then
    GUIComponentSliderInput.set_value(controls_flow.limit, new_limit)
  end
end

local function on_limit_changed(event, tags, player)
  on_value_changed(player, false, true)
end

local function on_reservation_changed(event, tags, player)
  on_value_changed(player, true, false)
end

local function on_reserve_checked(event, tags, player)
  local dialog = player.gui.screen[GUICommon.GUI_LIMIT_DIALOG]
  local controls_flow = dialog.inner_frame.controls_flow
  controls_flow.reservation.visible = event.element.state
  if event.element.state then
    local storage = Storage.get_storage(player)
    local storage_key = dialog.tags.item
    local reservation = Storage.get_item_reservation(storage, storage_key)
    GUIComponentSliderInput.set_value(controls_flow.reservation, reservation)
  else
    GUIComponentSliderInput.set_value(controls_flow.reservation, 0)
  end
end

GUIDispatcher.register(defines.events.on_gui_closed, GUI_CLOSE_EVENT, on_close)
GUIDispatcher.register(defines.events.on_gui_closed, nil, on_close)
GUIDispatcher.register(defines.events.on_gui_click, CLOSE_BUTTON_EVENT, on_close)

GUIDispatcher.register(defines.events.on_gui_click, CONFIRM_BUTTON_EVENT, on_confirm)
GUIDispatcher.register(defines.events.on_gui_confirmed, INPUT_CONFIRMED_EVENT, on_confirm)
GUIDispatcher.register(GUIDispatcher.ON_CONFIRM_KEYPRESS, nil, on_gui_confirm)

GUIDispatcher.register(defines.events.on_gui_value_changed, UPDATED_LIMIT_EVENT, on_limit_changed)
GUIDispatcher.register(defines.events.on_gui_text_changed, UPDATED_LIMIT_EVENT, on_limit_changed)

GUIDispatcher.register(defines.events.on_gui_value_changed, UPDATED_RESERVED_EVENT, on_reservation_changed)
GUIDispatcher.register(defines.events.on_gui_text_changed, UPDATED_RESERVED_EVENT, on_reservation_changed)

GUIDispatcher.register(defines.events.on_gui_checked_state_changed, RESERVE_CHECKBOX_EVENT, on_reserve_checked)


return GUILimitDialog
