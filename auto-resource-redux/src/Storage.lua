local Storage = {}
local DomainStore = require "src.DomainStore";
local Util = require "src.Util"

-- Don't store items that contain extra data, because the data would be lost
local blacklisted_item_types = {
  ["armor"] = true,
  ["deconstruction-item"] = true,
  ["blueprint"] = true,
  ["upgrade-item"] = true,
  ["blueprint-book"] = true,
  ["spidertron-remote"] = true,
  ["item-with-inventory"] = true,
  ["item-with-entity-data"] = true,
  ["item-with-tags"] = true
}

local DEFAULT_FLUID_LIMIT = 25000
Storage.MAX_FLUID_LIMIT = 100000
Storage.MAX_ITEM_LIMIT = 10000
-- number of stacks for the default limits (per item subgroup)
local default_item_subgroup_stacks = {
  ["raw-resource"] = 200,
  ["raw-material"] = 10,
  ["intermediate-product"] = 2.5,
  ["energy-pipe-distribution"] = 2,
  ["terrain"] = 10,
  ["ammo"] = 5
}

local blacklisted_items = {}

local function default_storage(domain_key)
  return {
    items = {},
    limits = {},
    domain_key = domain_key
  }
end

function Storage.get_storage(entity)
  return DomainStore.get_subdomain(DomainStore.get_domain_key(entity), "storage", default_storage)
end

function Storage.initialise()
  for name, item in pairs(game.item_prototypes) do
    if blacklisted_item_types[item.type] ~= nil then
      blacklisted_items[name] = true
    end
  end

  -- Delete non-existent items
  for domain_name, _ in pairs(global.domains) do
    local storage = DomainStore.get_subdomain(domain_name, "storage", default_storage)
    for item_name, _ in pairs(storage.items) do
      local fluid_name = Storage.unpack_fluid_item_name(item_name)
      if (fluid_name and game.fluid_prototypes[fluid_name] == nil) or (not fluid_name and game.item_prototypes[item_name] == nil) then
        log(("Removing unknown item key %s:%s"):format(domain_name, item_name))
        storage.items[item_name] = nil
      end
    end
  end
end

local function get_default_item_limit(storage_key)
  if Storage.unpack_fluid_item_name(storage_key) then
    return DEFAULT_FLUID_LIMIT
  end
  local prototype = (game.item_prototypes[storage_key] or {})
  local stack_size = prototype.default_request_amount or prototype.stack_size or 1
  local subgroup = (prototype.subgroup or {}).name
  return math.min(Storage.MAX_ITEM_LIMIT, math.ceil(stack_size * (default_item_subgroup_stacks[subgroup] or 1)))
end

function Storage.get_item_limit(storage, storage_key)
  if blacklisted_items[storage_key] ~= nil then
    return nil
  end
  local limit = storage.limits[storage_key]
  if limit == nil then
    limit = get_default_item_limit(storage_key)
    storage.limits[storage_key] = limit
  end
  return limit
end

function Storage.set_item_limit(storage, storage_key, new_limit)
  if blacklisted_items[storage_key] ~= nil then
    return
  end
  local fluid_name = Storage.unpack_fluid_item_name(storage_key)
  local max_limit = fluid_name and Storage.MAX_FLUID_LIMIT or Storage.MAX_ITEM_LIMIT
  storage.limits[storage_key] = Util.clamp(new_limit, 0, max_limit)
end

function Storage.filter_items(storage, storage_keys, min_qty, use_qty_from_filters)
  local found_items = {}
  min_qty = min_qty or 0
  for storage_key, stored_qty in pairs(storage_keys) do
    local needed_amount = use_qty_from_filters and min_qty or stored_qty
    local amount = storage.items[storage_key]
    if amount and Storage.unpack_fluid_item_name(storage_key) then
      amount = Util.table_sum_vals(amount)
    end
    if (amount or -1) >= needed_amount then
      found_items[storage_key] = stored_qty
    end
  end
  return found_items
end

function Storage.get_item_count(storage, item_or_fluid_name, temperature)
  local amount_stored = storage.items[item_or_fluid_name]
  if temperature then
    item_or_fluid_name = Storage.get_fluid_storage_key(item_or_fluid_name)
    temperature = math.floor(temperature)
    amount_stored = (storage.items[item_or_fluid_name] or {})[temperature]
  end
  return item_or_fluid_name, amount_stored
end

local function add_item_or_fluid(storage, item_or_fluid_name, amount, ignore_limit, temperature)
  if blacklisted_items[item_or_fluid_name] ~= nil then
    return 0
  end
  local item_or_fluid_name, amount_stored = Storage.get_item_count(storage, item_or_fluid_name, temperature)
  local item_limit = ignore_limit and math.huge or (Storage.get_item_limit(storage, item_or_fluid_name) or 0)
  local new_amount = Util.clamp((amount_stored or 0) + amount, 0, math.max((amount_stored or 0), item_limit))
  if temperature then
    local fluid = storage.items[item_or_fluid_name] or {}
    fluid[temperature] = new_amount
    storage.items[item_or_fluid_name] = fluid
  else
    storage.items[item_or_fluid_name] = new_amount
  end
  return new_amount - (amount_stored or 0)
end

--- Items

function Storage.take_all_from_inventory(storage, inventory, ignore_limit)
  local added_items = {}
  local remaining_items = {}
  for item, amount in pairs(inventory.get_contents()) do
    local amount_added = add_item_or_fluid(storage, item, amount, ignore_limit)
    if amount_added > 0 then
      inventory.remove({ name = item, count = amount_added })
      added_items[item] = amount_added
    end
    local amount_remaining = amount - amount_added
    if amount_remaining > 0 then
      remaining_items[item] = amount_remaining
    end
  end
  return added_items, remaining_items
end

function Storage.put_in_inventory(storage, inventory, item_name, amount_requested)
  local amount_stored = storage.items[item_name] or 0
  local amount_can_give = math.min(amount_stored, amount_requested)
  if amount_can_give <= 0 then
    return 0
  end
  local amount_given = inventory.insert({ name = item_name, count = amount_can_give })
  storage.items[item_name] = math.max(0, amount_stored - amount_given)
  return amount_given
end

function Storage.add_to_or_replace_stack(storage, stack, item_name, target_count, ignore_limit)
  -- try to clear if the item is different
  local stack_count = stack.count
  if stack_count > 0 and stack.name ~= item_name then
    local amount_removed = add_item_or_fluid(storage, stack.name, stack_count, ignore_limit)
    if amount_removed < stack_count then
      return 0
    end
    stack_count = 0
  end
  local amount_needed = target_count - stack_count
  if amount_needed <= 0 then
    return 0
  end
  local amount_stored = storage.items[item_name] or 0
  amount_needed = math.min(amount_stored, amount_needed)
  if amount_needed == 0 then
    return 0
  end
  local success = stack.set_stack({ name = item_name, count = stack_count + amount_needed })
  if success then
    storage.items[item_name] = math.max(0, amount_stored - amount_needed)
    return amount_needed
  end
  return 0
end

--- Fluids

function Storage.get_fluid_storage_key(fluid_name)
  return "fluid;" .. fluid_name
end

function Storage.unpack_fluid_item_name(storage_key)
  return string.match(storage_key, "fluid;(.+)")
end

function Storage.count_fluid_in_temperature_range(storage, storage_key, min_temp, max_temp)
  local fluid = storage.items[storage_key] or {}
  min_temp = math.floor(min_temp or -math.huge)
  max_temp = math.floor(max_temp or math.huge)
  local total = 0
  for temperature, amount in pairs(fluid) do
    if temperature >= min_temp and temperature <= max_temp then
      total = total + amount
    end
  end
  return total
end

function Storage.add_fluid(storage, fluid, ignore_limit)
  local amount_added = add_item_or_fluid(
    storage,
    fluid.name,
    math.floor(fluid.amount),
    ignore_limit,
    fluid.temperature
  )
  if amount_added > 0 then
    fluid.amount = fluid.amount - amount_added
  end
  return fluid, amount_added
end

function Storage.remove_fluid_in_temperature_range(storage, storage_key, min_temp, max_temp, amount_to_remove)
  local fluid = storage.items[storage_key]
  if not fluid then
    return 0
  end
  min_temp = math.floor(min_temp or -math.huge)
  max_temp = math.floor(max_temp or math.huge)
  amount_to_remove = math.ceil(amount_to_remove)
  local total_removed = 0
  for temperature, stored_amount in pairs(fluid) do
    if temperature >= min_temp and temperature <= max_temp and stored_amount > 0 then
      local new_amount = math.max(0, stored_amount - amount_to_remove)
      fluid[temperature] = new_amount
      local amount_removed = stored_amount - new_amount
      amount_to_remove = math.max(0, amount_to_remove - amount_removed)
      total_removed = total_removed + amount_removed
    end
  end
  storage.items[storage_key] = fluid
  return total_removed
end

return Storage
