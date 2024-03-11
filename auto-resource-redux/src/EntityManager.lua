local EntityManager = {}

local EntityCondition = require "src.EntityCondition"
local EntityCustomData = require "src.EntityCustomData"
local EntityGroups = require "src.EntityGroups"
local EntityHandlers = require "src.EntityHandlers"
local FurnaceRecipeManager = require "src.FurnaceRecipeManager"
local LogisticManager = require "src.LogisticManager"
local LoopBuffer = require "src.LoopBuffer"
local Storage = require "src.Storage"
local Util = require "src.Util"

local evaluate_condition = EntityCondition.evaluate

-- number of ticks it takes to process the whole queue
local DEFAULT_TICKS_PER_CYCLE = 60
local entity_queue_specs = {
  ["sink-tank"] = { handler = EntityHandlers.handle_sink_tank },
  ["arr-requester-tank"] = { handler = EntityHandlers.handle_requester_tank },
  ["sink-chest"] = { handler = EntityHandlers.handle_sink_chest, ticks_per_cycle = 180 },
  ["logistic-sink-chest"] = { handler = LogisticManager.handle_sink_chest },
  ["logistic-requester-chest"] = { handler = LogisticManager.handle_requester_chest },
  ["car"] = { handler = EntityHandlers.handle_car },
  ["spidertron"] = { handler = LogisticManager.handle_spidertron_requests, ticks_per_cycle = 120 },
  ["ammo-turret"] = { handler = EntityHandlers.handle_turret },
  ["boiler"] = { handler = EntityHandlers.handle_boiler, ticks_per_cycle = 120 },
  ["reactor"] = { handler = EntityHandlers.handle_reactor, ticks_per_cycle = 120 },
  ["mining-drill"] = { handler = EntityHandlers.handle_mining_drill, ticks_per_cycle = 120 },
  ["furnace"] = { handler = EntityHandlers.handle_furnace, ticks_per_cycle = 120 },
  ["assembling-machine"] = { handler = EntityHandlers.handle_assembler, ticks_per_cycle = 120 },
  ["lab"] = { handler = EntityHandlers.handle_lab, ticks_per_cycle = 120 },
}

local function handle_entity(entity, handler)
  if not handler then
    local queue_key = EntityGroups.names_to_groups[entity.name]
    handler = entity_queue_specs[queue_key].handler
  end
  local entity_data = global.entity_data[entity.unit_number] or {}
  local use_reserved = entity_data.use_reserved
  local storage = Storage.get_storage(entity)
  local running = not entity.to_be_deconstructed() and evaluate_condition(entity_data.condition, storage)
  return handler({
    entity = entity,
    storage = storage,
    use_reserved = use_reserved,
    paused = not running
  })
end

local function manage_entity(entity, immediately_handle)
  local queue_key = EntityGroups.names_to_groups[entity.name]
  if queue_key == nil then
    return
  end
  log(string.format("Managing %d (name=%s, type=%s, queue=%s)", entity.unit_number, entity.name, entity.type, queue_key))
  global.entities[entity.unit_number] = entity
  local queue = global.entity_queues[queue_key]
  LoopBuffer.add(queue, entity.unit_number)
  if immediately_handle then
    handle_entity(entity)
  end
  return queue_key
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

local function on_entity_removed(entity_id)
  EntityCustomData.on_entity_removed(entity_id)
  FurnaceRecipeManager.clear_marks(entity_id)
end

local busy_counters = {}
function EntityManager.on_tick()
  local total_processed = 0
  for queue_key, spec in pairs(entity_queue_specs) do
    local queue = global.entity_queues[queue_key]
    -- evenly distribute updates across the whole cycle
    local ticks_per_cycle = spec.ticks_per_cycle or DEFAULT_TICKS_PER_CYCLE
    local update_index = game.tick % ticks_per_cycle
    local max_updates = (
      math.floor(queue.size * (update_index + 1) / ticks_per_cycle) -
      math.floor(queue.size * update_index / ticks_per_cycle)
    )
    if max_updates <= 0 then
      goto continue
    end

    local num_processed = 0
    repeat
      if queue.size == 0 then
        break
      end
      local entity_id = LoopBuffer.next(queue)
      local entity = global.entities[entity_id]
      if entity == nil or not entity.valid then
        on_entity_removed(entity_id)
        LoopBuffer.remove_current(queue)
      else
        if handle_entity(entity, spec.handler) then
          busy_counters[queue_key] = (busy_counters[queue_key] or 0) + 1
        end
        num_processed = num_processed + 1
      end
      if queue.iter_index == 1 and queue.size > 10 then
        -- local count = busy_counters[queue_key] or 0
        -- print(("%s: %d/%d (%.2f%%) busy, %d/%d (%.2f%%) idle, %d updates per tick"):format(
        --   queue_key,
        --   count,
        --   queue.size,
        --   count / queue.size * 100,
        --   (queue.size - count),
        --   queue.size,
        --   (queue.size - count) / queue.size * 100,
        --   max_updates
        -- ))
        busy_counters[queue_key] = 0
      end
    until num_processed >= max_updates or num_processed >= queue.size

    total_processed = total_processed + num_processed
    ::continue::
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
  local queue_key = manage_entity(entity, true)
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
    if chest then
      chest.destructible = false
      global.sink_chest_parents[entity.unit_number] = chest.unit_number
    end
  end
end

function EntityManager.on_entity_removed(event, died)
  local entity = event.entity
  if entity.unit_number then
    on_entity_removed(entity.unit_number)
  end
  if not EntityGroups.can_manage(entity) then
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
          use_reserved = false,
        },
        true
      )
    end
    attached_chest.destroy({ raise_destroy = true })
  end
end

function EntityManager.on_entity_died(event)
  EntityManager.on_entity_removed(event, true)
end

function EntityManager.on_entity_replaced(data)
  EntityCustomData.migrate_data(data.old_entity_unit_number, data.new_entity_unit_number)
  manage_entity(data.new_entity, true)
end

function EntityManager.on_entity_deployed(data)
  manage_entity(data.entity, true)
end

return EntityManager
