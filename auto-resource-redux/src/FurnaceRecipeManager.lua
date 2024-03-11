local FurnaceRecipeManager = {}

function FurnaceRecipeManager.get_recipe_label(recipe)
  return ("[recipe=%s] %s (%s)"):format(recipe.name, recipe.name, recipe.category)
end

local function store_furnace_recipe(entity_id, recipe)
  if global.entity_data[entity_id] == nil then
    global.entity_data[entity_id] = {}
  end
  global.entity_data[entity_id].furnace_recipe = recipe and recipe.name
end

local function read_stored_furnace_recipe(entity_id)
  local data = global.entity_data[entity_id]
  if data == nil then
    return nil
  end
  return game.recipe_prototypes[data.furnace_recipe]
end

function FurnaceRecipeManager.can_craft(entity, recipe_name)
  local recipe_category = game.recipe_prototypes[recipe_name].category
  return entity.prototype.crafting_categories[recipe_category] ~= nil
end

function FurnaceRecipeManager.clear_marks(entity_id)
  for _, mark_id in ipairs(global.furnace_marks[entity_id] or {}) do
    rendering.destroy(mark_id)
  end
  global.furnace_marks[entity_id] = nil
end

function FurnaceRecipeManager.clear_pending_recipe(entity, recipe_to_clear)
  if recipe_to_clear then
    local stored_recipe = read_stored_furnace_recipe(entity.unit_number)
    if stored_recipe and stored_recipe.name ~= recipe_to_clear then
      return
    end
  end
  store_furnace_recipe(entity.unit_number, nil)
  FurnaceRecipeManager.clear_marks(entity.unit_number)
end

function FurnaceRecipeManager.get_recipe(entity)
  local current_recipe = entity.get_recipe() or entity.previous_recipe
  local stored_recipe = read_stored_furnace_recipe(entity.unit_number)
  if not stored_recipe then
    store_furnace_recipe(entity.unit_number, current_recipe)
    return current_recipe
  end
  return stored_recipe
end

function FurnaceRecipeManager.get_new_recipe(entity)
  local current_recipe = entity.get_recipe() or entity.previous_recipe
  local target_recipe = read_stored_furnace_recipe(entity.unit_number)
  if not target_recipe then
    store_furnace_recipe(entity.unit_number, current_recipe)
    return current_recipe, false
  end

  -- successfully switched
  if current_recipe and current_recipe.name == target_recipe.name then
    FurnaceRecipeManager.clear_marks(entity.unit_number)
    return current_recipe, false
  end

  -- only switch recipe if productivity bar is about to reset (or has just reset) so we don't lose progress
  local bonus_progress = entity.bonus_progress
  if entity.is_crafting() then
    bonus_progress = bonus_progress + (1 - entity.crafting_progress) * entity.productivity_bonus
  end
  if bonus_progress <= 0.01 or bonus_progress >= 0.999 then
    return target_recipe, true
  end

  return current_recipe, false
end

function FurnaceRecipeManager.set_recipe(entity, recipe_name)
  FurnaceRecipeManager.clear_marks(entity.unit_number)
  local current_recipe = entity.get_recipe() or entity.previous_recipe
  if current_recipe and current_recipe.name == recipe_name then
    return
  end

  local offset = { 0, -1.1 }
  local bg = rendering.draw_sprite({
    sprite = "utility/entity_info_dark_background",
    render_layer = "selection-box",
    target = entity,
    target_offset = offset,
    forces = { entity.force },
    surface = entity.surface,
    only_in_alt_mode = true
  })
  local arrows = rendering.draw_sprite({
    sprite = "arr-changing-icon",
    render_layer = "selection-box",
    target = entity,
    target_offset = offset,
    forces = { entity.force },
    surface = entity.surface,
    only_in_alt_mode = true,
  })
  local recipe_icon = rendering.draw_sprite({
    sprite = "recipe/" .. recipe_name,
    render_layer = "selection-box",
    target = entity,
    target_offset = offset,
    forces = { entity.force },
    surface = entity.surface,
    only_in_alt_mode = true,
  })

  if entity.type ~= "entity-ghost" then
    store_furnace_recipe(entity.unit_number, { name = recipe_name })
  end
  global.furnace_marks[entity.unit_number] = { bg, arrows, recipe_icon }
end

function FurnaceRecipeManager.initialise()
  if global.furnace_marks == nil then
    global.furnace_marks = {}
  end
end

return FurnaceRecipeManager
