local LogisticManager = {}

local Storage = require "src.Storage"
local Util = require "src.Util"

local TICKS_PER_LOGISTIC_UPDATE = 90
local TICKS_PER_ALERT_UPDATE = 60 * 2
local TICKS_PER_ALERT_TRANSFER = 60 * 10

local function handle_requests(o, inventory, ammo_inventory, extra_stack)
  local inventory_items = inventory.get_contents()
  local ammo_items = ammo_inventory and ammo_inventory.get_contents() or {}
  local total_inserted = 0
  extra_stack = extra_stack or {}
  for i = 1, o.entity.request_slot_count do
    local request = o.entity.get_request_slot(i)
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
            o.storage, ammo_inventory,
            item_name, amount_needed,
            o.use_reserved
          )
          amount_needed = amount_needed - inserted
          total_inserted = total_inserted + inserted
        end
        total_inserted = total_inserted + Storage.put_in_inventory(
          o.storage, inventory,
          item_name, amount_needed,
          o.use_reserved
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
  handle_requests(
    {
      storage = storage,
      entity = player.character,
      use_reserved = true
    },
    inventory,
    ammo_inventory,
    cursor_stack
  )
end

local function get_entity_key(entity)
  return entity.unit_number or string.format("%s,%s", entity.position.x, entity.position.y)
end

local function handle_items_request(storage, player, entity, item_requests)
  for item_name, needed_count in pairs(item_requests) do
    local amount_can_give = math.min(storage.items[item_name] or 0, needed_count)
    item_requests[item_name] = amount_can_give > 0 and amount_can_give or nil
  end
  if table_size(item_requests) == 0 then
    return false
  end

  local entity_position = entity.position
  local chest_sort_fn = function(a, b)
    local dist_a = (entity_position.x - a.position.x) ^ 2 + (entity_position.y - a.position.y) ^ 2
    local dist_b = (entity_position.x - b.position.x) ^ 2 + (entity_position.y - b.position.y) ^ 2
    return dist_a < dist_b
  end
  local nets = entity.surface.find_logistic_networks_by_construction_area(entity_position, player.force)
  local gave_items = false
  for _, net in ipairs(nets) do
    if net.available_construction_robots == 0 then
      goto continue
    end

    -- sort chests by their distance to the alert entity
    local chests = {}
    for _, chest in ipairs(net.storages) do
      if chest.name == "arr-logistic-sink-chest" then
        table.insert(chests, chest)
      end
    end
    if table_size(chests) == 0 then
      goto continue
    end
    table.sort(chests, chest_sort_fn)

    -- place items in chests, starting from the closest one
    for item_name, amount_to_give in pairs(item_requests) do
      for _, chest in ipairs(chests) do
        local inventory = chest.get_inventory(defines.inventory.chest)
        local amount_given = Storage.put_in_inventory(storage, inventory, item_name, amount_to_give, true)
        if amount_given > 0 then
          gave_items = true
          -- mark chest as busy so items don't get sucked back into storage
          global.busy_logistic_chests[chest.unit_number] = game.tick + TICKS_PER_ALERT_TRANSFER
        end
        amount_to_give = amount_to_give - amount_given
        item_requests[item_name] = amount_to_give > 0 and amount_to_give or nil
      end
    end

    if table_size(item_requests) == 0 then
      break
    end
    ::continue::
  end

  if gave_items then
    global.alert_build_transfers[get_entity_key(entity)] = game.tick + TICKS_PER_ALERT_TRANSFER
    return true
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
  return handle_requests(o, inventory)
end

function LogisticManager.handle_spidertron_requests(o)
  if o.paused then
    return false
  end
  local entity = o.entity
  local trash_inv = entity.get_inventory(defines.inventory.spider_trash)
  if not trash_inv then
    -- no trash inventory means no requests to process
    return false
  end
  Storage.add_from_inventory(o.storage, trash_inv, true)

  local inventory = entity.get_inventory(defines.inventory.spider_trunk)
  local ammo_inventory = entity.get_inventory(defines.inventory.spider_ammo)
  return handle_requests(o, inventory, ammo_inventory)
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
