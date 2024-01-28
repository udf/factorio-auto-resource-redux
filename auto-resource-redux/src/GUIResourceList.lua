local GUIResourceList = {}
local Util = require "src.Util"
local GUICommon = require "src.GUICommon"
local Storage = require "src.Storage"
local ItemPriorityManager = require "src.ItemPriorityManager"

local TICKS_PER_UPDATE = 12
-- "arr" stands for auto resource redux, matey
local GUI_RESOURCE_TABLE = "arr-table"
local COLOUR_END = "[/color]"
local COLOUR_LABEL = "[color=#e6d0ae]"
local COLOUR_RED = "[color=red]"
local COLOUR_GREEN = "[color=green]"
local FONT_END = "[/font]"
local FONT_BOLD = "[font=default-bold]"


-- TODO: ctrl-click/middle click to set limit
-- TODO: ctrl-right click to go to last pickup location?
-- TODO: use request_translation for item names
local function update_gui(player)
  local storage = Storage.get_storage(player)

  local gui_top = player.gui.top
  local table_elem = gui_top[GUI_RESOURCE_TABLE]
  if table_elem == nil then
    table_elem = gui_top.add({
      type = "table",
      column_count = 28,
      name = GUI_RESOURCE_TABLE
    })
  end

  if #table_elem.children > table_size(storage.items) then
    table_elem.clear()
  end

  for item_name, count in pairs(storage.items) do
    local button_name = "arr-res-" .. item_name
    local button = table_elem[button_name]
    local fluid_name = Storage.unpack_fluid_item_name(item_name)
    local is_new = false
    if button == nil then
      button = table_elem.add({
        type = "sprite-button",
        name = button_name,
        sprite = fluid_name and "fluid/" .. fluid_name or "item/" .. item_name,
      })
      is_new = true
    end

    local num_vals, sum, min, max
    if fluid_name then
      num_vals, sum, min, max = Util.table_val_stats(count)
    end

    local quantity = min or count
    local item_limit = Storage.get_item_limit(storage, item_name) or 0
    local is_red = quantity / item_limit < 0.01
    local tooltip = {
      "", FONT_BOLD, COLOUR_LABEL,
      { fluid_name and "fluid-name." .. fluid_name or "item-name." .. item_name },
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
    -- TODO: flash more than once
    button.toggled = (is_new and quantity > 0)
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

function GUIResourceList.on_click(event)
  -- TODO: use tags instead of parsing element name
  local item_name = string.match(event.element.name, "^arr%-res%-(.+)")
  -- click to take, or right click to clear (if 0)
  if item_name == nil then
    return
  end
  local click_str = GUICommon.get_click_str(event)
  local player = game.get_player(event.player_index)
  local storage = Storage.get_storage(player)
  local is_fluid = Storage.unpack_fluid_item_name(item_name)
  if click_str == "right" and is_fluid then
    storage.items[item_name] = Util.table_filter(
      storage.items[item_name],
      function(k, v)
        return v >= 1
      end
    )
  end
  if click_str == "right" and (
        storage.items[item_name] == 0
        or (is_fluid and table_size(storage.items[item_name]) == 0)
      ) then
    event.element.destroy()
    storage.items[item_name] = nil
    ItemPriorityManager.recalculate_priority_items(storage, Storage)
    return
  end
  if is_fluid then
    return
  end
  local stored_count = storage.items[item_name] or 0
  local stack_size = (game.item_prototypes[item_name] or {}).stack_size or 50
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
    Storage.put_in_inventory(storage, player.get_inventory(defines.inventory.character_main), item_name, amount_to_give)
    update_gui(player)
  end
end

return GUIResourceList
