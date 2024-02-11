EntityCustomData = {}

-- TODO: settings copy/paste
local DATA_TAG = "arr-data"

function EntityCustomData.on_setup_blueprint(event)
  local player = game.players[event.player_index]
  local blueprint = player.blueprint_to_setup
  local cursor = player.cursor_stack
  if not blueprint.valid_for_read and cursor.valid_for_read and cursor.type == "blueprint" then
    blueprint = cursor
  end
  if not blueprint.valid_for_read then
    log("FIXME: don't know how to get blueprint! player=" .. event.player_index)
    return
  end

  local blueprint_entities_arr = blueprint.get_blueprint_entities() or {}
  local blueprint_entities = {}
  for id, entity in ipairs(blueprint_entities_arr) do
    blueprint_entities[id] = entity
  end

  local next_id = blueprint.get_blueprint_entity_count() + 1
  local changed = false
  for id, entity in pairs(event.mapping.get()) do
    if entity.valid then
      local entity_data = global.entity_data[entity.unit_number]
      local blueprint_entity = blueprint_entities[id]
      if entity_data and blueprint_entity then
        entity_data.entity_name = entity.name
        table.insert(
          blueprint_entities_arr,
          {
            entity_number = next_id,
            name = "arr-data-proxy",
            position = blueprint_entity.position,
            tags = entity_data
          }
        )
        next_id = next_id + 1
        changed = true
      end
    end
  end

  if changed then
    blueprint.set_blueprint_entities(blueprint_entities_arr)
  end
end

function EntityCustomData.on_built(event)
  local entity = event.created_entity or event.entity
  if entity.type == "entity-ghost" and entity.ghost_name == "arr-data-proxy" then
    local target_name = entity.tags.entity_name
    local search_area = {
      { entity.position.x - 0.1, entity.position.y - 0.1 },
      { entity.position.x + 0.1, entity.position.y + 0.1 }
    }
    local new_tags = entity.tags
    new_tags.entity_name = nil

    -- look for entity to assign tags to
    local found_entities = entity.surface.find_entities_filtered({
      area = search_area,
      name = target_name,
      force = entity.force,
    })
    if #found_entities > 0 then
      local found_entity = found_entities[1]
      global.entity_data[found_entity.unit_number] = new_tags
      entity.destroy()
      return
    end

    -- look for ghost to assign tags to
    found_entities = entity.surface.find_entities_filtered({
      area = search_area,
      ghost_name = target_name,
      force = entity.force,
    })
    if #found_entities > 0 then
      local found_entity = found_entities[1]
      -- store tags in a separate attribute to not change other tags
      new_tags = { [DATA_TAG] = new_tags }
      found_entity.tags = new_tags
      entity.destroy()
      return
    end

    log("Couldn't find entity! " .. serpent.block({
      area = search_area,
      name = target_name,
      force = entity.force.name
    }))
    entity.destroy()
    return
  end

  -- use data from tags when a ghost is built
  if event.tags then
    local entity_data = event.tags[DATA_TAG]
    global.entity_data[entity.unit_number] = entity_data
  end
end

function EntityCustomData.on_cloned(event)
  local dest_id = event.destination.unit_number
  local src_id = event.source.unit_number
  global.entity_data[dest_id] = global.entity_data[src_id]
end

function EntityCustomData.initialise()
  if global.entity_data == nil then
    global.entity_data = {}
  end
end

return EntityCustomData
