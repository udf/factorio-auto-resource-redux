local LogisticManager = {}

local Storage = require "src.Storage"
local Util = require "src.Util"

local TICKS_PER_LOGISTIC_UPDATE = 90
local TICKS_PER_ALERT_UPDATE = 60 * 2
local TICKS_PER_ALERT_TRANSFER = 60 * 10


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

local function get_entity_key(entity)
  return entity.unit_number or string.format("%s,%s", entity.position.x, entity.position.y)
end

local function handle_items_request(storage, player, entity, item_requests)
  local nets = entity.surface.find_logistic_networks_by_construction_area(entity.position, player.force)
  for _, net in ipairs(nets) do
    if net.all_construction_robots > 0 then
      local gave_items = false

      for item_name, needed_count in pairs(item_requests) do
        local amount_can_give = math.min(storage.items[item_name] or 0, needed_count)
        if amount_can_give > 0 then
          local amount_given = net.insert({ name = item_name, count = amount_can_give })
          Storage.remove_item(storage, item_name, amount_given)
          gave_items = true
        end
      end

      if gave_items then
        return true
      end
    end
  end
  return false
end

local function clean_up_handled_alerts(alert_table)
  for alert_key, deadline in pairs(alert_table) do
    if game.tick >= deadline then
      alert_table[alert_key] = nil
    end
  end
end

local function handle_player_alerts(player)
  clean_up_handled_alerts(global.alert_build_transfers)
  local storage = Storage.get_storage(player)
  local alerts = player.get_alerts({ type = defines.alert_type.no_material_for_construction })
  for surface_id, alerts_by_type in pairs(alerts) do
    for _, alert in ipairs(alerts_by_type[defines.alert_type.no_material_for_construction]) do
      if alert.target == nil then
        goto continue
      end
      local entity = alert.target
      local alert_key = get_entity_key(entity)
      if global.alert_build_transfers[alert_key] then
        goto continue
      end
      local item_requests = {}
      if entity.type == "entity-ghost" or entity.type == "tile-ghost" then
        local stack = entity.ghost_prototype.items_to_place_this[1]
        item_requests[stack.name] = stack.count
      elseif entity.type == "cliff" then
        item_requests[entity.prototype.cliff_explosive_prototype] = 1
      elseif entity.type == "item-request-proxy" then
        item_requests = entity.item_requests
      else
        local upgrade_proto = entity.get_upgrade_target()
        if upgrade_proto then
          local stack = upgrade_proto.items_to_place_this[1]
          item_requests[stack.name] = stack.count
        end
      end
      if table_size(item_requests) > 0 and handle_items_request(storage, player, entity, item_requests) then
        global.alert_build_transfers[alert_key] = game.tick + TICKS_PER_ALERT_TRANSFER
      end
      ::continue::
    end
  end

  clean_up_handled_alerts(global.alert_repair_transfers)
  alerts = player.get_alerts({ type = defines.alert_type.not_enough_repair_packs })
  for surface_id, alerts_by_type in pairs(alerts) do
    for _, alert in ipairs(alerts_by_type[defines.alert_type.not_enough_repair_packs]) do
      if alert.target == nil then
        goto continue
      end
      local alert_key = get_entity_key(alert.target)
      if global.alert_repair_transfers[alert_key] then
        goto continue
      end
      -- TODO: don't hardcode repair pack item
      if handle_items_request(storage, player, alert.target, { ["repair-pack"] = 1 }) then
        global.alert_repair_transfers[alert_key] = game.tick + TICKS_PER_ALERT_TRANSFER
      end
      ::continue::
    end
  end
end

function LogisticManager.initialise()
  if global.alert_build_transfers == nil then
    global.alert_build_transfers = {}
  end
  if global.alert_repair_transfers == nil then
    global.alert_repair_transfers = {}
  end
end

function LogisticManager.on_tick()
  local _, player = Util.get_next_updatable("player_logistics", TICKS_PER_LOGISTIC_UPDATE, game.connected_players)
  if player then
    handle_player_logistics(player)
  end

  _, player = Util.get_next_updatable("player_alerts", TICKS_PER_ALERT_UPDATE, game.connected_players)
  if player then
    handle_player_alerts(player)
  end
end

return LogisticManager
