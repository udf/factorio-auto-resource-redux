local EntityManager = {}

local EntityGroups = require "src.EntityGroups"
local EntityHandlers = require "src.EntityHandlers"
local LoopBuffer = require "src.LoopBuffer"
local Util = require "src.Util"

-- TODO: fluid access, logistic chests (call into logistic mananager)
local entity_queue_specs = {
  ["sink-chest"] = { handler = EntityHandlers.handle_sink_chest, n_per_tick = 20 },
  ["sink-tank"] = { handler = EntityHandlers.handle_sink_tank, n_per_tick = 20 },
  ["car"] = { handler = EntityHandlers.handle_car },
  ["ammo-turret"] = { handler = EntityHandlers.handle_turret },
  ["boiler"] = { handler = EntityHandlers.handle_boiler },
  ["mining-drill"] = { handler = EntityHandlers.handle_mining_drill },
  ["furnace"] = { handler = EntityHandlers.handle_furnace },
  ["assembling-machine"] = { handler = EntityHandlers.handle_assembler },
  ["lab"] = { handler = EntityHandlers.handle_lab },
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

local function reload_entities()
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
    reload_entities()
  end
end

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
      elseif not entity.to_be_deconstructed() then
        spec.handler(entity)
        num_processed = num_processed + 1
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
  local queue_key = manage_entity(entity)
  if queue_key == nil then
    return
  end

  -- place invisible chest to catch outputs for things like mining drills
  if entity.drop_position ~= nil and entity.drop_target == nil then
    local chest = entity.surface.create_entity({
      name = "arr-sink-chest",
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
      EntityHandlers.handle_sink_chest(attached_chest, true)
    end
    attached_chest.destroy({ raise_destroy = true })
  end
end

function EntityManager.on_entity_died(event)
  EntityManager.on_entity_removed(event, true)
end

return EntityManager
