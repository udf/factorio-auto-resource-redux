EntityCustomData = {}
local flib_table = require("__flib__/table")
local EntityCondition = require "src.EntityCondition"
local EntityGroups = require "src.EntityGroups"
local FurnaceRecipeManager = require "src.FurnaceRecipeManager"
local GUIDispatcher = require "src.GUIDispatcher"
local GUIRequesterTank = require "src.GUIRequesterTank"
local Storage = require "src.Storage"

local DATA_TAG = "arr-data"

function EntityCustomData.initialise()
  if global.entity_data == nil then
    global.entity_data = {}
  end
  if global.entity_data_clipboard == nil then
    global.entity_data_clipboard = {}
  end
end

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
        entity_data._name = entity.name
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
    local target_name = entity.tags._name
    local search_area = {
      { entity.position.x - 0.1, entity.position.y - 0.1 },
      { entity.position.x + 0.1, entity.position.y + 0.1 }
    }
    local new_tags = entity.tags
    new_tags._name = nil

    -- look for entity to assign data to
    local found_entities = entity.surface.find_entities_filtered({
      area = search_area,
      name = target_name,
      force = entity.force,
    })
    if #found_entities > 0 then
      local found_entity = found_entities[1]
      EntityCustomData.set_data(found_entity, new_tags)
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
      -- mark furnace ghosts
      if new_tags.furnace_recipe then
        FurnaceRecipeManager.set_recipe(found_entity, new_tags.furnace_recipe)
      end
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
    EntityCustomData.set_data(entity, event.tags[DATA_TAG])
  end
end

function EntityCustomData.set_data(entity_or_ghost, new_data)
  if entity_or_ghost.type == "entity-ghost" then
    local tags = entity_or_ghost.tags or {}
    tags[DATA_TAG] = new_data
    entity_or_ghost.tags = tags
    return
  end
  global.entity_data[entity_or_ghost.unit_number] = new_data
  if new_data and new_data.furnace_recipe then
    FurnaceRecipeManager.set_recipe(entity_or_ghost, new_data.furnace_recipe)
  end
end

function EntityCustomData.on_cloned(event)
  local dest_id = event.destination.unit_number
  local src_id = event.source.unit_number
  global.entity_data[dest_id] = flib_table.deep_copy(global.entity_data[src_id])
end

function EntityCustomData.on_settings_pasted(event)
  EntityCustomData.on_cloned(event)
end

local function get_condition_label(data)
  local label = { data.use_reserved and "Prioritise; " or "Not prioritised; " }
  local condition = data.condition
  if condition and condition.item then
    local fluid_name = Storage.unpack_fluid_item_name(condition.item)
    table.insert(label, (fluid_name and "[fluid=%s]" or "[item=%s]"):format(fluid_name or condition.item))
    local op_str = EntityCondition.OPERATIONS[condition.op] or EntityCondition.OPERATIONS[1]
    table.insert(label, " " .. op_str .. " ")
    table.insert(label, (condition.value or 0) .. "%")
  else
    table.insert(label, "Always on")
  end
  return table.concat(label)
end

local function copy_entity_data(player, entity, tool_name, tool_label, add_suffix)
  local cursor = player.cursor_stack
  local selected_data = global.entity_data[player.selected.unit_number] or {}
  if cursor.set_stack({ name = tool_name, count = 1 }) then
    local label_suffix = ""
    if add_suffix then
      label_suffix = " (" .. get_condition_label(selected_data) .. ")"
    end
    cursor.label = tool_label .. label_suffix
    player.cursor_stack_temporary = true
  end
  global.entity_data_clipboard[player.index] = {
    name = entity.name,
    type = entity.type,
    data = flib_table.deep_copy(selected_data),
  }
end

local function on_copy(event, tags, player)
  local selected = player.selected
  local cursor = player.cursor_stack
  if not selected or cursor.valid_for_read then
    return
  end

  local selected_data = global.entity_data[selected.unit_number] or {}
  local tool_name, label
  if selected.name == "arr-requester-tank" then
    tool_name = "arr-paste-tool-requester-tank"
    label = GUIRequesterTank.get_paste_label(selected_data)
  elseif selected.type == "furnace" then
    local recipe = FurnaceRecipeManager.get_recipe(selected)
    if recipe then
      tool_name = "arr-paste-tool-furnace-" .. recipe.category
      label = FurnaceRecipeManager.get_recipe_label(recipe)
    end
  end

  if tool_name then
    copy_entity_data(player, selected, tool_name, label, true)
  end
end

local function on_copy_conditions(event, tags, player)
  local selected = player.selected
  local cursor = player.cursor_stack
  if not selected or cursor.valid_for_read or not EntityGroups.can_manage(selected) then
    return
  end

  local selected_data = global.entity_data[selected.unit_number] or {}
  local label = "Auto Resource:" .. get_condition_label(selected_data)
  copy_entity_data(player, selected, "arr-paste-tool-condition", label)
end

function EntityCustomData.on_player_selected_area(event)
  local set_data = EntityCustomData.set_data
  local src = global.entity_data_clipboard[event.player_index]
  if event.item == "arr-paste-tool-requester-tank" then
    for _, entity in ipairs(event.entities) do
      set_data(entity, flib_table.deep_copy(src.data))
    end
    return
  end

  local furnace_tool_category = event.item:match("arr%-paste%-tool%-furnace%-(.+)")
  if furnace_tool_category then
    for _, entity in ipairs(event.entities) do
      set_data(entity, flib_table.deep_copy(src.data))
    end
  end

  if furnace_tool_category or event.item == "arr-paste-tool-condition" then
    local src_data = src.data or {}
    for _, entity in ipairs(event.entities) do
      local entity_data = global.entity_data[entity.unit_number] or {}
      entity_data.use_reserved = src_data.use_reserved
      entity_data.condition = flib_table.deep_copy(src_data.condition)
      set_data(entity, entity_data)
    end
    return
  end
end

function EntityCustomData.on_player_alt_selected_area(event)
  local furnace_tool_category = event.item:match("arr%-paste%-tool%-furnace%-(.+)")
  if furnace_tool_category then
    for _, entity in ipairs(event.entities) do
      FurnaceRecipeManager.clear_pending_recipe(entity)
    end
  end
end

function EntityCustomData.set_use_reserved(entity, use_reserved)
  if not global.entity_data[entity.unit_number] then
    global.entity_data[entity.unit_number] = {}
  end
  global.entity_data[entity.unit_number].use_reserved = use_reserved
end

function EntityCustomData.on_entity_removed(entity_id)
  global.entity_data[entity_id] = nil
end

function EntityCustomData.migrate_data(old_id, new_id)
  local data = global.entity_data[old_id]
  if data then
    global.entity_data[new_id] = data
    global.entity_data[old_id] = nil
  end
end

GUIDispatcher.register(GUIDispatcher.ON_COPY_SETTINGS_KEYPRESS, nil, on_copy)
GUIDispatcher.register(GUIDispatcher.ON_COPY_CONDITIONS_KEYPRESS, nil, on_copy_conditions)

return EntityCustomData
