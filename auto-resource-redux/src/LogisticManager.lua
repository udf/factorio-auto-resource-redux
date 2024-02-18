local LogisticManager = {}

local Storage = require "src.Storage"
local Util = require "src.Util"

local TICKS_PER_LOGISTIC_UPDATE = 90
local TICKS_PER_ALERT_UPDATE = 60 * 2
local TICKS_PER_ALERT_TRANSFER = 60 * 10

local function handle_requests(storage, entity, inventory, ammo_inventory, extra_stack)
  local inventory_items = inventory.get_contents()
  local ammo_items = ammo_inventory and ammo_inventory.get_contents() or {}
  local total_inserted = 0
  extra_stack = extra_stack or {}
  for i = 1, entity.request_slot_count do
    local request = entity.get_request_slot(i)
    if request and request.count > 0 then
      local item_name = request.name
      local amount_needed = (
        request.count
        - (inventory_items[item_name] or 0)
        - (ammo_items[item_name] or 0)
        - (extra_stack[item_name] or 0)
      )
      if amount_needed > 0 then
        if ammo_inventory and ammo_inventory.can_insert(request) then
          local inserted = Storage.put_in_inventory(
            storage, item_name,
            ammo_inventory, amount_needed,
            true
          )
          amount_needed = amount_needed - inserted
          total_inserted = total_inserted + inserted
        end
        total_inserted = total_inserted + Storage.put_in_inventory(
          storage, item_name,
          inventory, amount_needed,
          true
        )
      end
    end
  end
  return total_inserted > 0
end

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
    Storage.add_from_inventory(storage, trash_inv, true)
  end

  local inventory = player.get_inventory(defines.inventory.character_main)
  local ammo_inventory = player.get_inventory(defines.inventory.character_ammo)
  if not player.character or not inventory then
    return
  end
  local cursor_stack = {}
  if player.cursor_stack and player.cursor_stack.count > 0 then
    cursor_stack = { [player.cursor_stack.name] = player.cursor_stack.count }
  end
  handle_requests(storage, player.character, inventory, ammo_inventory, cursor_stack)
end

local function get_entity_key(entity)
  return entity.unit_number or string.format("%s,%s", entity.position.x, entity.position.y)
end

local function mark_chests_as_busy(net)
  for _, entity in ipairs(net.storages) do
    if entity.name == "arr-logistic-sink-chest" then
      global.busy_logistic_chests[entity.unit_number] = game.tick + TICKS_PER_ALERT_TRANSFER
    end
  end
end

local function handle_items_request(storage, player, entity, item_requests)
  local nets = entity.surface.find_logistic_networks_by_construction_area(entity.position, player.force)
  for _, net in ipairs(nets) do
    if net.available_construction_robots > 0 then
      local gave_items = false

      for item_name, needed_count in pairs(item_requests) do
        local amount_can_give = math.min(storage.items[item_name] or 0, needed_count)
        if amount_can_give > 0 then
          local amount_given = net.insert({ name = item_name, count = amount_can_give })
          Storage.remove_item(storage, item_name, amount_given, true)
          gave_items = true
        end
      end

      if gave_items then
        mark_chests_as_busy(net)
        global.alert_build_transfers[get_entity_key(entity)] = game.tick + TICKS_PER_ALERT_TRANSFER
        return true
      end
    end
  end
  return false
end

local function clean_up_deadline_table(deadlines)
  for key, deadline in pairs(deadlines) do
    if game.tick >= deadline then
      deadlines[key] = nil
    end
  end
end

local function handle_player_alerts(player)
  clean_up_deadline_table(global.alert_build_transfers)
  local storage = Storage.get_storage(player)
  local alerts = player.get_alerts({ type = defines.alert_type.no_material_for_construction })
  for surface_id, alerts_by_type in pairs(alerts) do
    for _, alert in ipairs(alerts_by_type[defines.alert_type.no_material_for_construction]) do
      if alert.target == nil then
        goto continue
      end
      local entity = alert.target
      if global.alert_build_transfers[get_entity_key(entity)] then
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
      if table_size(item_requests) > 0 then
        handle_items_request(storage, player, entity, item_requests)
      end
      ::continue::
    end
  end

  clean_up_deadline_table(global.alert_repair_transfers)
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
      handle_items_request(storage, player, alert.target, { ["repair-pack"] = 1 })
      ::continue::
    end
  end
end

function LogisticManager.handle_sink_chest(o)
  clean_up_deadline_table(global.busy_logistic_chests)
  if global.busy_logistic_chests[o.entity.unit_number] or o.paused then
    return false
  end
  local inventory = o.entity.get_inventory(defines.inventory.chest)
  local added_items, _ = Storage.add_from_inventory(o.storage, inventory, true)
  return table_size(added_items) > 0
end

function LogisticManager.handle_requester_chest(o)
  if o.paused then
    return false
  end
  local inventory = o.entity.get_inventory(defines.inventory.chest)
  return handle_requests(o.storage, o.entity, inventory)
end

function LogisticManager.initialise()
  if global.alert_build_transfers == nil then
    global.alert_build_transfers = {}
  end
  if global.alert_repair_transfers == nil then
    global.alert_repair_transfers = {}
  end
  if global.busy_logistic_chests == nil then
    global.busy_logistic_chests = {}
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
