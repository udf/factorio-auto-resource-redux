local EntityHandlers = {}

-- seconds to attempt to keep assemblers fed for
local TARGET_INGREDIENT_CRAFT_TIME = 2

local ItemPriorityManager = require "src.ItemPriorityManager"
local Storage = require "src.Storage"
local Util = require "src.Util"

local function store_fluids(storage, entity, prod_type_pattern, ignore_limit)
  local remaining_fluids = {}
  prod_type_pattern = prod_type_pattern or "output"
  for i, fluid in Util.iter_fluidboxes(entity, prod_type_pattern, false) do
    local new_fluid, amount_added = Storage.add_fluid(storage, fluid, ignore_limit)
    local fluid_key = Storage.get_fluid_storage_key(fluid.name)
    if amount_added > 0 then
      entity.fluidbox[i] = new_fluid.amount > 0 and new_fluid or nil
    end
    if new_fluid.amount > 0 then
      remaining_fluids[fluid_key] = new_fluid.amount
    end
  end
  return remaining_fluids
end

function EntityHandlers.store_all_fluids(entity)
  store_fluids(Storage.get_storage(entity), entity, ".", true)
end

local function insert_fluids(storage, entity, prod_type_pattern, target_amounts, default_amount)
  prod_type_pattern = prod_type_pattern or "input"
  for i, fluid, filter in Util.iter_fluidboxes(entity, prod_type_pattern, true) do
    if not filter then
      goto continue
    end
    fluid = fluid or { name = filter.name, amount = 0 }
    local amount_needed = math.max(0, (target_amounts[filter.name] or default_amount) - fluid.amount)
    local amount_removed = Storage.remove_fluid_in_temperature_range(
      storage,
      Storage.get_fluid_storage_key(filter.name),
      filter.minimum_temperature,
      filter.maximum_temperature,
      amount_needed
    )
    -- We could compute the new temperature but recipes don't take the specific temperature into account
    fluid.amount = fluid.amount + amount_removed
    entity.fluidbox[i] = fluid.amount > 0 and fluid or nil
    ::continue::
  end
end

local function insert_using_priority_set(storage, entity, priority_set_key, stack, filter_name)
  local priority_sets = ItemPriorityManager.get_priority_sets(entity)
  if not priority_sets[priority_set_key] then
    log(("FIXME: missing priority set \"%s\" for %s!"):format(priority_set_key, entity.name))
    return
  end
  local usable_items = ItemPriorityManager.get_usable_items(priority_sets, priority_set_key)
  if filter_name then
    usable_items = { [filter_name] = usable_items[filter_name] }
  end
  if table_size(usable_items) == 0 then
    return
  end

  local current_count = stack.count
  local current_item = current_count > 0 and stack.name or nil
  local expected_count = usable_items[current_item] or 0
  -- set satisfaction to 0 if the item is unknown so that it immediately gets "upgraded" to a better item
  local current_satisfaction = (expected_count > 0) and math.min(1, current_count / expected_count) or 0

  -- insert first usable item
  for item_name, wanted_amount in pairs(usable_items) do
    local stored_amount = storage.items[item_name] or 0
    if wanted_amount <= 0 then
      goto continue
    end
    if stored_amount > 0 then
      if item_name == current_item then
        stored_amount = stored_amount + current_count
      end
      local new_satisfaction = math.min(1, stored_amount / wanted_amount)

      if new_satisfaction >= current_satisfaction then
        Storage.add_to_or_replace_stack(storage, stack, item_name, wanted_amount, true)
        break
      end
    end
    if item_name == current_item then
      -- avoid downgrading
      break
    end
    ::continue::
  end
end

local function insert_fuel(storage, entity)
  local inventory = entity.get_fuel_inventory()
  if inventory then
    insert_using_priority_set(
      storage,
      entity,
      ItemPriorityManager.get_fuel_key(entity.name),
      inventory[1]
    )
  end
end

function EntityHandlers.handle_assembler(entity)
  local recipe = entity.get_recipe()
  if recipe == nil then
    return
  end

  -- always try to pick up outputs
  local storage = Storage.get_storage(entity)
  local output_inventory = entity.get_inventory(defines.inventory.assembling_machine_output)
  local _, remaining_items = Storage.take_all_from_inventory(storage, output_inventory)
  Util.dictionary_merge(remaining_items, store_fluids(storage, entity))

  -- check if we should craft
  local has_empty_slot = false
  for _, item in ipairs(recipe.products) do
    local amount_produced = item.amount or item.amount_max
    local storage_key = item.name
    if item.type == "fluid" then
      storage_key = Storage.get_fluid_storage_key(item.name)
    end

    if remaining_items[storage_key] == nil then
      has_empty_slot = true
    end

    -- skip crafting if any slot contains 1x or more products
    if (remaining_items[storage_key] or 0) >= amount_produced then
      -- print_if(
      --   entity,
      --   string.format(
      --     "%s: Not crafting recipe %s because %d remaining %s >= %d per cycle",
      --     entity.gps_tag,
      --     recipe.name,
      --     remaining_items[storage_key],
      --     storage_key,
      --     amount_produced
      --   ))
      return
    end
  end
  if not has_empty_slot then
    -- print_if(
    --   entity,
    --   string.format(
    --     "%s: Not crafting recipe %s because there are no empty output slots remaining=%s",
    --     entity.gps_tag,
    --     recipe.name,
    --     serpent.block(remaining_items)
    --   ))
    return
  end

  local crafts_per_second = entity.crafting_speed / recipe.energy
  local ingredient_multiplier = math.max(1, math.ceil(TARGET_INGREDIENT_CRAFT_TIME * crafts_per_second))
  local input_inventory = entity.get_inventory(defines.inventory.assembling_machine_input)
  local input_items = input_inventory.get_contents()
  for i, fluid in Util.iter_fluidboxes(entity, "input", false) do
    local storage_key = Storage.get_fluid_storage_key(fluid.name)
    input_items[storage_key] = math.floor(fluid.amount)
  end
  -- reduce the multiplier if we don't have enough of an ingredient
  for _, ingredient in ipairs(recipe.ingredients) do
    local storage_key, storage_amount
    if ingredient.type == "fluid" then
      storage_key = Storage.get_fluid_storage_key(ingredient.name)
      storage_amount = Storage.count_fluid_in_temperature_range(
        storage,
        storage_key,
        ingredient.minimum_temperature,
        ingredient.maximum_temperature
      )
    else
      storage_key = ingredient.name
      storage_amount = storage.items[storage_key] or 0
    end
    local craftable_ratio = math.floor((storage_amount + (input_items[storage_key] or 0)) / math.ceil(ingredient.amount))
    ingredient_multiplier = math.min(ingredient_multiplier, craftable_ratio)
    if ingredient_multiplier == 0 then
      -- print_if(
      --   entity,
      --   (
      --     "%s: Can't craft %s because not enough %s (we have %d, machine has %d, but need %d)"
      --   ):format(
      --     entity.gps_tag,
      --     recipe.name,
      --     storage_key,
      --     storage_amount,
      --     (input_items[storage_key] or 0),
      --     math.ceil(ingredient.amount)
      --   ))
      return
    end
  end

  -- insert ingredients
  local fluid_targets = {}
  for _, ingredient in ipairs(recipe.ingredients) do
    local target_amount = math.ceil(ingredient.amount) * ingredient_multiplier
    if ingredient.type == "fluid" then
      fluid_targets[ingredient.name] = target_amount
    else
      local amount_needed = target_amount - (input_items[ingredient.name] or 0)
      if amount_needed > 0 then
        Storage.put_in_inventory(storage, input_inventory, ingredient.name, amount_needed)
      end
    end
  end
  insert_fluids(storage, entity, "input", fluid_targets)
end

function EntityHandlers.handle_furnace(entity)
  if entity.get_recipe() then
    local storage = Storage.get_storage(entity)
    insert_fuel(storage, entity)
    EntityHandlers.handle_assembler(entity)
  end
end

function EntityHandlers.handle_lab(entity)
  local pack_count_target = math.ceil(entity.speed_bonus * 0.5) + 1
  local lab_inv = entity.get_inventory(defines.inventory.lab_input)
  local storage = Storage.get_storage(entity)
  for i, item_name in ipairs(game.entity_prototypes[entity.name].lab_inputs) do
    Storage.add_to_or_replace_stack(storage, lab_inv[i], item_name, pack_count_target)
  end
end

function EntityHandlers.handle_mining_drill(entity)
  local storage = Storage.get_storage(entity)
  insert_fuel(storage, entity)
  if #entity.fluidbox > 0 then
    -- there is no easy way to know what fluid a miner wants, the fluid is a property of the ore's prototype
    -- and the expected resources aren't simple to find: https://forums.factorio.com/viewtopic.php?p=247019
    -- so it will have to be done manually using the fluid access tank
    store_fluids(storage, entity, "output")
  end
end

function EntityHandlers.handle_boiler(entity)
  local storage = Storage.get_storage(entity)
  insert_fuel(storage, entity)
end

function EntityHandlers.handle_turret(entity)
  local storage = Storage.get_storage(entity)
  insert_using_priority_set(
    storage,
    entity,
    ItemPriorityManager.get_ammo_key(entity.name, 1),
    entity.get_inventory(defines.inventory.turret_ammo)[1]
  )
end

function EntityHandlers.handle_car(entity)
  local storage = Storage.get_storage(entity)
  insert_fuel(storage, entity)
  local ammo_inventory = entity.get_inventory(defines.inventory.car_ammo)
  if ammo_inventory then
    for i = 1, #ammo_inventory do
      insert_using_priority_set(
        storage,
        entity,
        ItemPriorityManager.get_ammo_key(entity.name, i),
        ammo_inventory[i],
        ammo_inventory.get_filter(i)
      )
    end
  end
  -- TODO: maybe fulfil some inventory filters?
end

function EntityHandlers.handle_sink_chest(entity, ignore_limit)
  local storage = Storage.get_storage(entity)
  Storage.take_all_from_inventory(storage, entity.get_output_inventory(), ignore_limit)
end

function EntityHandlers.handle_sink_tank(entity)
  local storage = Storage.get_storage(entity)
  local fluid = entity.fluidbox[1]
  if fluid == nil then
    return
  end
  local new_fluid, amount_added = Storage.add_fluid(storage, fluid)
  if amount_added > 0 then
    entity.fluidbox[1] = new_fluid.amount > 0 and new_fluid or nil
  end
end

return EntityHandlers