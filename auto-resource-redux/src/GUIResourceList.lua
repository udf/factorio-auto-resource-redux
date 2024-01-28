local GUIResourceList = {}
local Util = require "src.Util"
local Storage = require "src.Storage"
local ItemPriorityManager = require "src.ItemPriorityManager"
local GUICommon = require "src.GUICommon"
local GUIDispatcher = require "src.GUIDispatcher"
local GUILimitDialog = require "src.GUILimitDialog"


local TICKS_PER_UPDATE = 12
local RES_BUTTON_EVENT = "arr-res-btn"
local COLOUR_END = "[/color]"
local COLOUR_LABEL = "[color=#e6d0ae]"
local COLOUR_RED = "[color=red]"
local COLOUR_GREEN = "[color=green]"
local FONT_END = "[/font]"
local FONT_BOLD = "[font=default-bold]"

-- TODO: ctrl-right click to go to last pickup location?
local function update_gui(player)
  local storage = Storage.get_storage(player)

  local gui_top = player.gui.top
  local table_elem = gui_top[GUICommon.GUI_RESOURCE_TABLE]
  if table_elem == nil then
    table_elem = gui_top.add({
      type = "table",
      column_count = 28,
      name = GUICommon.GUI_RESOURCE_TABLE
    })
  end

  if #table_elem.children > table_size(storage.items) then
    table_elem.clear()
  end

  for storage_key, count in pairs(storage.items) do
    local button = table_elem[storage_key]
    local fluid_name = Storage.unpack_fluid_item_name(storage_key)
    if button == nil then
      button = GUICommon.create_item_button(
        table_elem,
        storage_key,
        {
          name = storage_key,
          tags = { event = RES_BUTTON_EVENT, item = storage_key, flash_anim = 0 },
          mouse_button_filter = { "left", "right", "middle" },
        }
      )
    end

    local num_vals, sum, min, max
    if fluid_name then
      num_vals, sum, min, max = Util.table_val_stats(count)
    end

    local quantity = min or count
    local item_limit = Storage.get_item_limit(storage, storage_key) or 0
    local is_red = quantity / item_limit < 0.01
    local tooltip = {
      "", FONT_BOLD, COLOUR_LABEL,
      { fluid_name and "fluid-name." .. fluid_name or "item-name." .. storage_key },
      COLOUR_END,
      "\n",
      (is_red and COLOUR_RED or ""), (min or count), (is_red and COLOUR_END or ""),
      "/", item_limit,
      FONT_END
    }
    -- List the levels of each fluid temperature
    if fluid_name then
      if num_vals > 1 then
        Util.array_extend(
          tooltip,
          { "\n", COLOUR_LABEL, FONT_BOLD, { "gui.total" }, FONT_END, COLOUR_END, ": ", sum }
        )
      end
      local i = 0
      local qty_strs = {}
      local wrap = math.max(1, math.floor(num_vals / 10))
      for temperature, qty in pairs(count) do
        local colour_tag = nil
        if is_red and qty == min then
          colour_tag = COLOUR_RED
        elseif qty == max then
          colour_tag = COLOUR_GREEN
        end
        table.insert(
          qty_strs,
          string.format(
            "%s[color=#e6d0ae][font=default-bold]%d°C[/font][/color]: %s%d%s",
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

function GUIResourceList.initialise()
  if global.gui_resources_last_update == nil then
    global.gui_resources_last_update = {}
  end
end

function GUIResourceList.on_tick()
  local _, player = Util.get_next_updatable("resource_gui", TICKS_PER_UPDATE, game.connected_players)
  if player then
    update_gui(player)
  end
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
    ItemPriorityManager.recalculate_priority_items(storage, Storage)
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
    Storage.put_in_inventory(storage, player.get_inventory(defines.inventory.character_main), storage_key, amount_to_give)
    update_gui(player)
  end
end

GUIDispatcher.register(defines.events.on_gui_click, RES_BUTTON_EVENT, on_button_clicked)

return GUIResourceList
