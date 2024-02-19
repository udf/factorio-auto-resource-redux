local EntityManager = {}

local EntityCondition = require "src.EntityCondition"
local EntityGroups = require "src.EntityGroups"
local EntityHandlers = require "src.EntityHandlers"
local LogisticManager = require "src.LogisticManager"
local LoopBuffer = require "src.LoopBuffer"
local Storage = require "src.Storage"
local Util = require "src.Util"

local entity_queue_specs = {
  ["sink-chest"] = { handler = EntityHandlers.handle_sink_chest },
  ["sink-tank"] = { handler = EntityHandlers.handle_sink_tank },
  ["arr-requester-tank"] = { handler = EntityHandlers.handle_requester_tank, n_per_tick = 1 },
  ["logistic-sink-chest"] = { handler = LogisticManager.handle_sink_chest, n_per_tick = 1 },
  ["logistic-requester-chest"] = { handler = LogisticManager.handle_requester_chest, n_per_tick = 1 },
  ["car"] = { handler = EntityHandlers.handle_car },
  ["ammo-turret"] = { handler = EntityHandlers.handle_turret },
  ["boiler"] = { handler = EntityHandlers.handle_boiler },
  ["mining-drill"] = { handler = EntityHandlers.handle_mining_drill },
  ["furnace"] = { handler = EntityHandlers.handle_furnace },
  ["assembling-machine"] = { handler = EntityHandlers.handle_assembler },
  ["lab"] = { handler = EntityHandlers.handle_lab, n_per_tick = 2 },
}

local function manage_entity(entity)
  local queue_key = EntityGroups.names_to_groups[entity.name]
  if queue_key == nil then
    return
  end
  log(string.format("Managing %d (name=%s, type=%s, queue=%s)", entity.unit_number, entity.name, entity.type, queue_key))
  global.entities[entity.unit_number] = entity
  LoopBuffer.add(global.entity_queues[queue_key], entity.unit_number)
  return queue_key
end

function EntityManager.can_manage(entity)
  return EntityGroups.names_to_groups[entity.name] ~= nil
end

function EntityManager.reload_entities()
  log("Reloading entities")
  global.entity_queues = {}
  for queue_key, _ in pairs(entity_queue_specs) do
    global.entity_queues[queue_key] = LoopBuffer.new()
  end

  local entity_names = Util.table_keys(EntityGroups.names_to_groups)
  for _, surface in pairs(game.surfaces) do
    local entities = surface.find_entities_filtered({ force = Util.table_keys(global.forces), name = entity_names })
    for _, entity in ipairs(entities) do
      manage_entity(entity)
    end
  end

  log("Entity queue sizes:")
  for entity_type, queue in pairs(global.entity_queues) do
    log(entity_type .. ": " .. queue.size)
  end
end

function EntityManager.initialise()
  local should_reload_entities = false

  if global.sink_chest_parents == nil then
    global.sink_chest_parents = {}
  end
  if global.entities == nil then
    global.entities = {}
    should_reload_entities = true
  end

  for queue_key, _ in pairs(entity_queue_specs) do
    if global.entity_queues == nil or global.entity_queues[queue_key] == nil then
      should_reload_entities = true
      break
    end
  end
  if should_reload_entities then
    EntityManager.reload_entities()
  end
end

local busy_counters = {}
local evaluate_condition = EntityCondition.evaluate
function EntityManager.on_tick()
  local total_processed = 0
  for queue_key, spec in pairs(entity_queue_specs) do
    local max_updates = spec.n_per_tick or 10
    local queue = global.entity_queues[queue_key]
    local num_processed = 0
    repeat
      if queue.size == 0 then
        break
      end
      local entity_id = LoopBuffer.next(queue)
      local entity = global.entities[entity_id]
      if entity == nil or not entity.valid then
        LoopBuffer.remove_current(queue)
      else
        local entity_data = global.entity_data[entity_id] or {}
        local use_reserved = entity_data.use_reserved
        local storage = Storage.get_storage(entity)
        local running = not entity.to_be_deconstructed() and evaluate_condition(entity_data.condition, storage)
        local busy = spec.handler({
          entity = entity,
          storage = storage,
          use_reserved = use_reserved,
          paused = not running
        })
        if busy then
          busy_counters[queue_key] = (busy_counters[queue_key] or 0) + 1
        end
        num_processed = num_processed + 1
      end
      if queue.iter_index == 1 and queue.size > 10 then
        local count = busy_counters[queue_key] or 0
        -- print(("%s: %d/%d (%.2f%%) busy, %d/%d (%.2f%%) idle"):format(
        --   queue_key,
        --   count,
        --   queue.size,
        --   count / queue.size * 100,
        --   (queue.size - count),
        --   queue.size,
        --   (queue.size - count) / queue.size * 100
        -- ))
        busy_counters[queue_key] = 0
      end
    until num_processed >= max_updates or num_processed >= queue.size
    total_processed = total_processed + num_processed
  end
end

function EntityManager.on_entity_created(event)
  local entity = event.created_entity or event.destination
  if entity == nil then
    entity = event.entity
  end
  if global.forces[entity.force.name] == nil then
    return
  end
  local queue_key = manage_entity(entity)
  if queue_key == nil then
    return
  end

  -- place invisible chest to catch outputs for things like mining drills
  if entity.drop_position ~= nil and entity.drop_target == nil then
    local chest = entity.surface.create_entity({
      name = "arr-hidden-sink-chest",
      position = entity.drop_position,
      force = entity.force,
      player = entity.last_user,
      raise_built = true
    })
    chest.destructible = false
    global.sink_chest_parents[entity.unit_number] = chest.unit_number
  end
end

function EntityManager.on_entity_removed(event, died)
  local entity = event.entity
  if not EntityGroups.names_to_groups[entity.name] then
    return
  end
  if not died and #entity.fluidbox > 0 then
    EntityHandlers.store_all_fluids(entity)
  end
  global.entities[entity.unit_number] = nil
  local attached_chest = global.entities[global.sink_chest_parents[entity.unit_number]]
  if attached_chest ~= nil and attached_chest.valid then
    if not died then
      EntityHandlers.handle_sink_chest(
        {
          entity = attached_chest,
          storage = Storage.get_storage(attached_chest),
          use_reserved = true,
        },
        nil
      )
    end
    attached_chest.destroy({ raise_destroy = true })
  end
end

function EntityManager.on_entity_died(event)
  EntityManager.on_entity_removed(event, true)
end

return EntityManager
