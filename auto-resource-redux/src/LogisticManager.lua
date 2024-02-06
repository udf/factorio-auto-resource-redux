local LogisticManager = {}

local Util = require "src.Util"
local Storage = require "src.Storage"
local TICKS_PER_UPDATE = 90

local function handle_player_logistics(player)
  if player.force.character_logistic_requests == false then
    player.force.character_logistic_requests = true
    if player.force.character_trash_slot_count < 10 then
      player.force.character_trash_slot_count = 10
    end
    return
  end

  local trash_inv = player.get_inventory(defines.inventory.character_trash)
  local storage = Storage.get_storage(player)
  if trash_inv then
    Storage.take_all_from_inventory(storage, trash_inv, true)
  end

  local character = player.character
  local inventory = player.get_inventory(defines.inventory.character_main)
  local ammo_inventory = player.get_inventory(defines.inventory.character_ammo)
  if not character or not inventory then
    return
  end
  local inventory_items = inventory.get_contents()
  local ammo_items = ammo_inventory and ammo_inventory.get_contents() or {}
  local cursor_stack = {}
  if player.cursor_stack and player.cursor_stack.count > 0 then
    cursor_stack = { [player.cursor_stack.name] = player.cursor_stack.count }
  end
  for i = 1, character.request_slot_count do
    local request = character.get_request_slot(i)
    if request and request.count > 0 then
      local item_name = request.name
      local amount_needed = (
        request.count
        - (inventory_items[item_name] or 0)
        - (ammo_items[item_name] or 0)
        - (cursor_stack[item_name] or 0)
      )
      if amount_needed > 0 then
        if ammo_inventory and ammo_inventory.can_insert(request) then
          amount_needed = amount_needed - Storage.put_in_inventory(storage, ammo_inventory, item_name, amount_needed)
        end
        Storage.put_in_inventory(storage, inventory, item_name, amount_needed)
      end
    end
  end
end

function LogisticManager.initialise()
  if global.player_logistics_last_update == nil then
    global.player_logistics_last_update = {}
  end
end

function LogisticManager.on_tick()
  local _, player = Util.get_next_updatable("player_logistics", TICKS_PER_UPDATE, game.connected_players)
  if player then
    handle_player_logistics(player)
  end
end

return LogisticManager
