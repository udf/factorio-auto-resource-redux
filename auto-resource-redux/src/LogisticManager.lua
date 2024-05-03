local LogisticManager = {}

local Storage = require "src.Storage"
local Util = require "src.Util"

-- Ticks between handling player logistics
local TICKS_PER_LOGISTIC_UPDATE = 90

-- Ticks between checking alerts
local TICKS_PER_ALERT_UPDATE = 10
-- Number of alerts to handle each time alerts are checked
local ALERTS_TO_HANDLE_PER_UPDATE = 100
-- How to long to wait before transferring items for an alert again
-- (also how long to prevent the chest from sucking items back up)
local TICKS_PER_ALERT_TRANSFER = 610

local function handle_requests(o, inventory, ammo_inventory, extra_stack)
  local inventory_items = inventory.get_contents()
  local ammo_items = ammo_inventory and ammo_inventory.get_contents() or {}
  local total_inserted = 0
  local requests = {}
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
        local inserted = Storage.put_in_inventory(
          o.storage, inventory,
          item_name, amount_needed,
          o.use_reserved
        )
        amount_needed = amount_needed - inserted
        total_inserted = total_inserted + inserted
      end

      requests[request.name] = request.count
    end
  end
  return total_inserted > 0, requests
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

local function handle_items_request(storage, force, entity, item_requests)
  for item_name, needed_count in pairs(item_requests) do
    local amount_can_give = math.min(storage.items[item_name] or 0, needed_count)
    item_requests[item_name] = amount_can_give > 0 and amount_can_give or nil
  end
  if table_size(item_requests) == 0 then
    return false
  end

  -- find all chests from networks that can handle the requests
  local entity_position = entity.position
  local nets = entity.surface.find_logistic_networks_by_construction_area(entity_position, force)
  local chests = {}
  local avail_net
  for _, net in ipairs(nets) do
    if net.available_construction_robots == 0 then
      goto continue
    end
    avail_net = net

    for _, chest in ipairs(net.storages) do
      if chest.name == "arr-logistic-sink-chest" then
        table.insert(
          chests,
          {
            entity = chest,
            dist = (entity_position.x - chest.position.x) ^ 2 + (entity_position.y - chest.position.y) ^ 2
          }
        )
      end
    end

    ::continue::
  end

  if table_size(chests) == 0 and avail_net == nil then
    return false
  end
  -- sort chests by their distance to the alert's entity
  table.sort(
    chests,
    function(a, b)
      return a.dist < b.dist
    end
  )

  -- place items in chests, starting from the closest one
  local gave_items = false
  for item_name, amount_to_give in pairs(item_requests) do
    for _, chest in ipairs(chests) do
      chest = chest.entity
      local inventory = chest.get_inventory(defines.inventory.chest)
      local amount_given = Storage.put_in_inventory(storage, inventory, item_name, amount_to_give, true)
      if amount_given > 0 then
        gave_items = true
        -- mark chest as busy so items don't get sucked back into storage
        global.busy_logistic_chests[chest.unit_number] = game.tick + TICKS_PER_ALERT_TRANSFER
      end
      amount_to_give = amount_to_give - amount_given
      if amount_to_give <= 0 then
        break
      end
    end

    -- if there is still some left, just insert it anywhere in the network
    if amount_to_give > 0 and avail_net ~= nil then
      local amount_given = avail_net.insert({ name=item_name, count=amount_to_give })
      if amount_given > 0 then
        gave_items = true
        amount_to_give = amount_to_give - amount_given
      end
    end
  end

  return gave_items
end

local function clean_up_deadline_table(deadlines)
  for key, deadline in pairs(deadlines) do
    if game.tick >= deadline then
      deadlines[key] = nil
    end
  end
end

local function handle_build_alert(alert, alert_key, storage, force)
  if alert.target == nil then
    return false
  end
  if global.alert_item_transfers[alert_key] then
    return false
  end
  local entity = alert.target
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
    if handle_items_request(storage, force, entity, item_requests) then
      global.alert_item_transfers[alert_key] = game.tick + TICKS_PER_ALERT_TRANSFER
    end
    return true
  end
  return false
end

local function handle_repair_alert(alert, alert_key, storage, force)
  if alert.target == nil then
    return false
  end
  if global.alert_item_transfers[alert_key] then
    return false
  end
  -- TODO: don't hardcode repair pack item
  if handle_items_request(storage, force, alert.target, { ["repair-pack"] = 1 }) then
    global.alert_item_transfers[alert_key] = game.tick + TICKS_PER_ALERT_TRANSFER
  end
  return true
end

local function get_alert_key(alert_type, surface_id, entity)
  if not entity then
    return nil
  end
  local entity_id = entity.unit_number or string.format("%d,%d", entity.position.x, entity.position.y)
  return string.format("%d,%d,%s", alert_type, surface_id, entity_id)
end

local function handle_player_alerts(player, handled_surfaces, alert_type, handler_fn)
  local force = player.force
  local alerts = player.get_alerts({ type = alert_type })
  local num_processed = 0
  for surface_id, alerts_by_type in pairs(alerts) do
    local storage = Storage.get_storage_for_surface(surface_id, player)
    local handled_alerts = global.handled_alerts[surface_id]
    if not handled_alerts then
      handled_alerts = {}
      global.handled_alerts[surface_id] = handled_alerts
    end

    for _, alert in ipairs(alerts_by_type[alert_type]) do
      local alert_key = get_alert_key(alert_type, surface_id, alert.target)
      if not alert_key or handled_alerts[alert_key] then
        goto continue
      end
      handled_alerts[alert_key] = true
      handled_surfaces[surface_id] = true
      if handler_fn(alert, alert_key, storage, force) then
        num_processed = num_processed + 1
        if num_processed >= ALERTS_TO_HANDLE_PER_UPDATE then
          return
        end
      end
      ::continue::
    end
  end

  -- clear list of handled alerts for surfaces that had nothing to handle
  -- this will restart the alert handling from the beginning
  for surface_id, _ in pairs(global.handled_alerts) do
    if not handled_surfaces[surface_id] then
      global.handled_alerts[surface_id] = {}
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
  local busy, requests = handle_requests(o, inventory)
  if o.return_excess then
    local inventory_items = inventory.get_contents()
    for item_name, count in pairs(inventory_items) do
      local extra = count - (requests[item_name] or 0)
      if extra > 0 then
        local removed = inventory.remove({ name = item_name, count = extra })
        Storage.add_item_or_fluid(o.storage, item_name, removed, true)
      end
    end
  end
  return busy
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
  if global.alert_item_transfers == nil then
    global.alert_item_transfers = {}
  end
  if global.handled_alerts == nil then
    global.handled_alerts = {}
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
    clean_up_deadline_table(global.alert_item_transfers)
    local handled_surfaces = {}
    handle_player_alerts(player, handled_surfaces, defines.alert_type.no_material_for_construction, handle_build_alert)
    handle_player_alerts(player, handled_surfaces, defines.alert_type.not_enough_repair_packs, handle_repair_alert)
  end
end

return LogisticManager
