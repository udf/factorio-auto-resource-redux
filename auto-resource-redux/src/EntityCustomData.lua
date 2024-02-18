EntityCustomData = {}
local flib_table = require("__flib__/table")
local EntityCondition = require "src.EntityCondition"
local EntityManager = require "src.EntityManager"
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
  global.entity_data[dest_id] = flib_table.deep_copy(global.entity_data[src_id])
end

function EntityCustomData.on_settings_pasted(event)
  EntityCustomData.on_cloned(event)
end

local function get_paste_tool(entity)
  if entity.name == "arr-requester-tank" then
    return "arr-paste-tool-requester-tank", GUIRequesterTank.get_paste_label
  elseif entity.type == "furnace" then
    local recipe = entity.get_recipe() or entity.previous_recipe
    if recipe then
      return "arr-paste-tool-furnace-" .. recipe.category, FurnaceRecipeManager.get_recipe_label, recipe
    end
  end
end

local function copy_entity_data(player, entity, tool_name, tool_label, extra_data, add_suffix)
  local cursor = player.cursor_stack
  local selected_data = global.entity_data[player.selected.unit_number] or {}
  if cursor.set_stack({ name = tool_name, count = 1 }) then
    local label_suffix = ""
    if add_suffix and selected_data.use_reserved then
      label_suffix = " (prioritised)"
    end
    cursor.label = tool_label .. label_suffix
    player.cursor_stack_temporary = true
  end
  global.entity_data_clipboard[player.index] = {
    name = entity.name,
    type = entity.type,
    extra_data = extra_data,
    data = flib_table.deep_copy(selected_data),
  }
end

local function on_copy(event, tags, player)
  local selected = player.selected
  local cursor = player.cursor_stack
  if not selected or cursor.valid_for_read then
    return
  end

  local tool_name, label_fn, extra_data = get_paste_tool(selected)
  if tool_name then
    local selected_data = global.entity_data[selected.unit_number] or {}
    local label = label_fn(extra_data or selected_data, selected_data)
    copy_entity_data(player, selected, tool_name, label, extra_data, true)
  end
end

local function on_copy_conditions(event, tags, player)
  local selected = player.selected
  local cursor = player.cursor_stack
  if not selected or cursor.valid_for_read or not EntityManager.can_manage(selected) then
    return
  end

  local selected_data = global.entity_data[selected.unit_number] or {}
  local label = { "Auto Resource:" }
  table.insert(label, selected_data.use_reserved and "Prioritise; " or "Not prioritised; ")
  local condition = selected_data.condition
  if condition and condition.item then
    local fluid_name = Storage.unpack_fluid_item_name(condition.item)
    table.insert(label, (fluid_name and "[fluid=%s]" or "[item=%s]"):format(fluid_name or condition.item))
    table.insert(label, " " .. (condition.op or EntityCondition.OPERATIONS[1]) .. " ")
    table.insert(label, (condition.value or 0) .. "%")
  else
    table.insert(label, "Always on")
  end
  copy_entity_data(player, selected, "arr-paste-tool-condition", table.concat(label))
end

function EntityCustomData.on_player_selected_area(event)
  local src = global.entity_data_clipboard[event.player_index]
  if event.item == "arr-paste-tool-requester-tank" then
    for _, entity in ipairs(event.entities) do
      if entity.name == src.name then
        global.entity_data[entity.unit_number] = flib_table.deep_copy(src.data)
      end
    end
    return
  end

  local furnace_tool_category = event.item:match("arr%-paste%-tool%-furnace%-(.+)")
  if furnace_tool_category then
    for _, entity in ipairs(event.entities) do
      FurnaceRecipeManager.set_recipe(entity, src.extra_data)
    end
    return
  end

  if event.item == "arr-paste-tool-condition" then
    local src_data = src.data or {}
    for _, entity in ipairs(event.entities) do
      local entity_data = global.entity_data[entity.unit_number]
      if entity_data == nil then
        entity_data = {}
        global.entity_data[entity.unit_number] = entity_data
      end
      entity_data.use_reserved = src_data.use_reserved
      entity_data.condition = flib_table.deep_copy(src_data.condition)
    end
    return
  end
end

function EntityCustomData.set_use_reserved(entity, use_reserved)
  if not global.entity_data[entity.unit_number] then
    global.entity_data[entity.unit_number] = {}
  end
  global.entity_data[entity.unit_number].use_reserved = use_reserved
end

GUIDispatcher.register(GUIDispatcher.ON_COPY_SETTINGS_KEYPRESS, nil, on_copy)
GUIDispatcher.register(GUIDispatcher.ON_COPY_CONDITIONS_KEYPRESS, nil, on_copy_conditions)

return EntityCustomData
