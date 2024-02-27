local GUIResourceList = {}

local flib_table = require("__flib__/table")
local GUICommon = require "src.GUICommon"
local GUIDispatcher = require "src.GUIDispatcher"
local GUILimitDialog = require "src.GUILimitDialog"
local R = require "src.RichText"
local Storage = require "src.Storage"
local Util = require "src.Util"


local OLD_GUI_RESOURCE_TABLE = "arr-table"
local TICKS_PER_UPDATE = 12
local RES_BUTTON_EVENT = "arr-res-btn"
-- { [storage_key] = order int }
local storage_keys_order = {}
-- { [storage_key] = group str }
local storage_keys_groups = {}
-- { [group_str] = order int }
local storage_keys_group_order = {}

local function find_gui_index_for(parent, ordering, element_name)
  for i, child in ipairs(parent.children) do
    if ordering[child.name] > ordering[element_name] then
      return i
    end
  end
  return nil
end

function GUIResourceList.get_or_create_button(player, storage_key)
  local gui_top = player.gui.top
  local table_flow = gui_top[GUICommon.GUI_RESOURCE_TABLE] or gui_top.add({
    type = "flow",
    direction = "vertical",
    name = GUICommon.GUI_RESOURCE_TABLE
  })

  local group_name = storage_keys_groups[storage_key]
  local table_elem = table_flow[group_name] or table_flow.add({
    type = "table",
    column_count = 20,
    name = group_name,
    index = find_gui_index_for(table_flow, storage_keys_group_order, group_name)
  })

  local button = table_elem[storage_key] or GUICommon.create_item_button(
    table_elem,
    storage_key,
    {
      name = storage_key,
      tags = { event = RES_BUTTON_EVENT, item = storage_key, flash_anim = 0 },
      mouse_button_filter = { "left", "right", "middle" },
      index = find_gui_index_for(table_elem, storage_keys_order, storage_key)
    }
  )
  return button
end

GUICommon.get_or_create_reslist_button = GUIResourceList.get_or_create_button

local function update_gui(player)
  local storage = Storage.get_storage(player)

  local gui_top = player.gui.top
  local old_table = gui_top[OLD_GUI_RESOURCE_TABLE]
  if old_table then
    old_table.destroy()
  end

  for storage_key, count in pairs(storage.items) do
    local button = GUIResourceList.get_or_create_button(player, storage_key)
    local fluid_name = Storage.unpack_fluid_item_name(storage_key)

    local num_vals, sum, min, max
    if fluid_name then
      num_vals, sum, min, max = Util.table_val_stats(count)
    end

    local quantity = min or count
    local item_limit = Storage.get_item_limit(storage, storage_key) or 0
    local reserved = Storage.get_item_reservation(storage, storage_key)
    local is_red = quantity <= (reserved > 0 and reserved or item_limit * 0.01)
    local tooltip = {
      "", R.FONT_BOLD, R.COLOUR_LABEL,
      fluid_name and { "fluid-name." .. fluid_name } or game.item_prototypes[storage_key].localised_name,
      R.COLOUR_END,
      "\n",
      (is_red and R.COLOUR_RED or ""), (min or count), (is_red and R.COLOUR_END or ""),
      "/", item_limit,
      R.FONT_END,
      reserved > 0 and ("\n[color=#e6d0ae][font=default-bold]Reserved:[/font][/color] " .. reserved) or ""
    }
    -- List the levels of each fluid temperature
    if fluid_name then
      if num_vals > 1 then
        Util.array_extend(
          tooltip,
          { "\n", R.LABEL, { "gui.total" }, R.LABEL_END, ": ", sum }
        )
      end
      local i = 0
      local qty_strs = {}
      local wrap = math.max(1, math.floor(num_vals / 10))
      for temperature, qty in pairs(count) do
        local colour_tag = nil
        if is_red and qty == min then
          colour_tag = R.COLOUR_RED
        elseif qty == max then
          colour_tag = R.COLOUR_GREEN
        end
        table.insert(
          qty_strs,
          string.format(
            "%s[color=#e6d0ae][font=default-bold]%d°C:[/font][/color] %s%d%s",
            i % wrap == 0 and "\n" or ", ",
            temperature,
            colour_tag and colour_tag or "",
            qty,
            colour_tag and "[/color]" or ""
          )
        )
        i = i + 1
      end
      table.insert(tooltip, table.concat(qty_strs))
    end
    if button.tags.flash_anim <= 3 then
      button.toggled = button.tags.flash_anim % 2 == 0
      local tags = button.tags
      tags.flash_anim = tags.flash_anim + 1
      button.tags = tags
    end
    button.number = quantity
    button.tooltip = tooltip
    button.style = is_red and "red_slot_button" or "slot_button"
  end
end

function GUIResourceList.on_tick()
  local _, player = Util.get_next_updatable("resource_gui", TICKS_PER_UPDATE, game.connected_players)
  if player then
    update_gui(player)
  end
end

function GUIResourceList.initialise()
  storage_keys_order = {}
  for item_name, item in pairs(game.item_prototypes) do
    table.insert(storage_keys_order, item_name)
  end
  for fluid_name, item in pairs(game.fluid_prototypes) do
    local storage_key = Storage.get_fluid_storage_key(fluid_name)
    table.insert(storage_keys_order, storage_key)
  end
  table.sort(
    storage_keys_order,
    function(a, b)
      local fluid_name_a = Storage.unpack_fluid_item_name(a)
      local fluid_name_b = Storage.unpack_fluid_item_name(b)
      local proto_a = fluid_name_a and game.fluid_prototypes[fluid_name_a] or game.item_prototypes[a]
      local proto_b = fluid_name_b and game.fluid_prototypes[fluid_name_b] or game.item_prototypes[b]
      if proto_a.group.order ~= proto_b.group.order then
        return proto_a.group.order < proto_b.group.order
      end
      if proto_a.subgroup.order ~= proto_b.subgroup.order then
        return proto_a.subgroup.order < proto_b.subgroup.order
      end
      return proto_a.order < proto_b.order
    end
  )

  storage_keys_groups = {}
  storage_keys_group_order = {}
  for i, storage_key in ipairs(storage_keys_order) do
    local fluid_name = Storage.unpack_fluid_item_name(storage_key)
    local proto = fluid_name and game.fluid_prototypes[fluid_name] or game.item_prototypes[storage_key]

    storage_keys_groups[storage_key] = proto.group.name
    if storage_keys_group_order[proto.group.name] == nil then
      storage_keys_group_order[proto.group.name] = true
    end
  end

  storage_keys_order = flib_table.invert(storage_keys_order)
  storage_keys_group_order = flib_table.invert(Util.table_keys(storage_keys_group_order))
end

local function on_button_clicked(event, tags, player)
  local storage_key = tags.item
  local click_str = GUICommon.get_click_str(event)

  if click_str == "middle" then
    GUILimitDialog.open(player, storage_key, event.cursor_display_location)
    return
  end

  -- click to take, or right click to clear (if 0)
  local storage = Storage.get_storage(player)
  local is_fluid = Storage.unpack_fluid_item_name(storage_key)
  if click_str == "right" and is_fluid then
    storage.items[storage_key] = Util.table_filter(
      storage.items[storage_key],
      function(k, v)
        return v >= 1
      end
    )
  end
  if click_str == "right" and (
        storage.items[storage_key] == 0
        or (is_fluid and table_size(storage.items[storage_key]) == 0)
      ) then
    event.element.destroy()
    storage.items[storage_key] = nil
    return
  end
  if is_fluid then
    return
  end
  local stored_count = storage.items[storage_key] or 0
  local stack_size = (game.item_prototypes[storage_key] or {}).stack_size or 50
  local amount_to_give = ({
    ["left"] = 1,
    ["right"] = 5,
    ["shift-left"] = stack_size,
    ["shift-right"] = math.ceil(stack_size / 2),
    ["control-left"] = stored_count,
    ["control-right"] = math.ceil(stored_count / 2),
  })[click_str] or 1
  amount_to_give = Util.clamp(amount_to_give, 0, stored_count)
  if amount_to_give > 0 then
    Storage.put_in_inventory(
      storage, storage_key,
      player.get_inventory(defines.inventory.character_main), amount_to_give,
      true
    )
    update_gui(player)
  end
end

GUIDispatcher.register(defines.events.on_gui_click, RES_BUTTON_EVENT, on_button_clicked)

return GUIResourceList
