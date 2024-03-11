local Storage = {}
local DomainStore = require "src.DomainStore";
local ItemPriorityManager = require "src.ItemPriorityManager"
local R = require "src.RichText"
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
local DEFAULT_FLUID_RESERVATION = 2500
Storage.MAX_FLUID_LIMIT = 1000000
Storage.MAX_ITEM_LIMIT = 100000
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
    reservations = {},
    domain_key = domain_key
  }
end

function Storage.get_storage(entity)
  local storage = DomainStore.get_subdomain(DomainStore.get_domain_key(entity), "storage", default_storage)
  storage.last_entity = entity
  return storage
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
    if storage.reservations == nil then
      storage.reservations = {}
    end
    for item_name, _ in pairs(storage.items) do
      local fluid_name = Storage.unpack_fluid_item_name(item_name)
      if (fluid_name and game.fluid_prototypes[fluid_name] == nil) or (not fluid_name and game.item_prototypes[item_name] == nil) then
        log(("Removing unknown item key %s:%s"):format(domain_name, item_name))
        storage.items[item_name] = nil
      end
    end
  end
end

function Storage.can_store(storage_key)
  return blacklisted_items[storage_key] == nil
end

--- Prints info about a setting being changed for the force
---@param setting_name string
---@param storage_key string
---@param entity LuaEntity
---@param new_value integer
local function print_setting_changed_info(setting_name, storage_key, entity, new_value)
  local reason = ""
  if entity.is_player() then
    reason = ("(requested by %s)"):format(R.get_coloured_text(entity.chat_color, entity.name))
  else
    reason = ("(requested by [entity=%s] at %s)"):format(entity.name, entity.gps_tag)
  end
  entity.force.print(
    ("Auto Resource@%s: Setting %s for %s to %d %s"):format(
      entity.surface.name,
      setting_name,
      Storage.get_item_tag(storage_key),
      new_value,
      reason
    )
  )
end

function Storage.calc_new_limit_and_reservation(
  storage, storage_key,
  new_limit, new_reservation,
  cur_limit, cur_reservation
)
  cur_limit = cur_limit or Storage.get_item_limit(storage, storage_key)
  cur_reservation = cur_reservation or Storage.get_item_reservation(storage, storage_key)
  new_limit = new_limit or cur_limit
  new_reservation = new_reservation or cur_reservation

  -- ensure limit >= reservation
  if new_reservation ~= cur_reservation then
    new_limit = math.max(new_limit, new_reservation)
  end
  if new_limit ~= cur_limit then
    new_reservation = math.min(new_limit, new_reservation)
  end

  local fluid_name = Storage.unpack_fluid_item_name(storage_key)
  local max_limit = fluid_name and Storage.MAX_FLUID_LIMIT or Storage.MAX_ITEM_LIMIT
  new_limit = Util.clamp(new_limit, 0, max_limit)
  new_reservation = Util.clamp(new_reservation, 0, new_limit)
  return new_limit, new_reservation, cur_limit, cur_reservation
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
  if not Storage.can_store(storage_key) then
    return nil
  end
  local limit = storage.limits[storage_key]
  if limit == nil then
    limit = get_default_item_limit(storage_key)
    storage.limits[storage_key] = limit
  end
  return limit
end

function Storage.set_item_limit_and_reservation(storage, storage_key, src_entity, new_limit, new_reservation)
  if not Storage.can_store(storage_key) then
    return
  end
  local new_limit, new_reservation, cur_limit, cur_reservation = Storage.calc_new_limit_and_reservation(
    storage, storage_key,
    new_limit, new_reservation
  )
  if new_limit ~= cur_limit then
    print_setting_changed_info("limit", storage_key, src_entity, new_limit)
    storage.limits[storage_key] = new_limit
  end
  if new_reservation ~= cur_reservation then
    print_setting_changed_info("reservation", storage_key, src_entity, new_reservation)
    storage.reservations[storage_key] = new_reservation
  end
end

function Storage.get_item_tag(storage_key)
  local fluid_name = Storage.unpack_fluid_item_name(storage_key)
  return fluid_name and ("[fluid=%s]"):format(fluid_name) or ("[item=%s]"):format(storage_key)
end

function Storage.get_item_reservation(storage, storage_key)
  return storage.reservations[storage_key] or 0
end

--- Counts the available quantity of an item, taking the reservation into account
---@param storage table
---@param storage_key string
---@param amount_requested integer
---@param use_reserved boolean
---@return integer amount_available The amount that is available to be removed from the storage
---@return integer amount_stored The total amount stored
function Storage.get_available_item_count(storage, storage_key, amount_requested, use_reserved)
  local amount_stored = storage.items[storage_key] or 0
  local amount_reserved = storage.reservations[storage_key] or 0
  -- make sure reservation works by automatically marking up to a stack of the item as reserved
  if use_reserved and storage.items[storage_key] and amount_reserved <= 0 and not storage.last_entity.is_player() then
    local fluid_name = Storage.unpack_fluid_item_name(storage_key)
    local prototype = game.item_prototypes[storage_key] or { stack_size = 1 }
    amount_reserved = fluid_name and DEFAULT_FLUID_RESERVATION or math.min(amount_requested, prototype.stack_size)
    Storage.set_item_limit_and_reservation(storage, storage_key, storage.last_entity, nil, amount_reserved)
  end
  if use_reserved then
    return math.min(amount_requested, amount_stored), amount_stored
  end
  return Util.clamp(amount_stored - amount_reserved, 0, amount_requested), amount_stored
end

local get_available_item_count = Storage.get_available_item_count

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

local function get_item_or_fluid_count(storage, item_or_fluid_name, temperature)
  local amount_stored = storage.items[item_or_fluid_name]
  if temperature then
    item_or_fluid_name = Storage.get_fluid_storage_key(item_or_fluid_name)
    temperature = math.floor(temperature)
    amount_stored = (storage.items[item_or_fluid_name] or {})[temperature]
  end
  return amount_stored, item_or_fluid_name
end

local function add_item_or_fluid(storage, item_or_fluid_name, amount, ignore_limit, temperature)
  if not Storage.can_store(item_or_fluid_name) then
    return 0
  end
  local amount_stored, item_or_fluid_name = get_item_or_fluid_count(storage, item_or_fluid_name, temperature)
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

--- Adds items from an inventory
---@param storage table
---@param inventory LuaInventory
---@param ignore_limit boolean
---@return table added_items The counts of items that were added to storage
---@return table remaining_items The counts of the items that could not fit into storage
function Storage.add_from_inventory(storage, inventory, ignore_limit)
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

--- Removes an item from storage
---@param storage table
---@param item_name string
---@param amount_requested integer
---@param use_reserved boolean
---@return integer amount_removed
function Storage.remove_item(storage, item_name, amount_requested, use_reserved)
  local amount_can_give, amount_stored = get_available_item_count(storage, item_name, amount_requested, use_reserved)
  local amount_to_give = math.min(amount_can_give, amount_requested)
  storage.items[item_name] = math.max(0, amount_stored - amount_to_give)
  return amount_to_give
end

--- Inserts an item into an inventory
---@param storage table
---@param inventory LuaInventory
---@param item_name string
---@param amount_requested integer
---@param use_reserved boolean
---@return integer amount_given
function Storage.put_in_inventory(storage, inventory, item_name, amount_requested, use_reserved)
  local amount_to_give, amount_stored = get_available_item_count(storage, item_name, amount_requested, use_reserved)
  if amount_to_give <= 0 then
    return 0
  end
  local amount_given = inventory.insert({ name = item_name, count = amount_to_give })
  storage.items[item_name] = math.max(0, amount_stored - amount_given)
  return amount_given
end

--- Adds item to a stack, or replaces the stack if the items are different
---@param storage table
---@param item_name string
---@param stack LuaItemStack
---@param target_count integer
---@param ignore_limit boolean
---@param use_reserved boolean
---@return integer amount_to_add
function Storage.add_to_or_replace_stack(storage, item_name, stack, target_count, ignore_limit, use_reserved)
  -- try to clear if the item is different
  local stack_count = stack.count
  if stack_count > 0 and stack.name ~= item_name then
    local amount_removed = add_item_or_fluid(storage, stack.name, stack_count, ignore_limit)
    stack_count = stack_count - amount_removed
    if stack_count > 0 and amount_removed > 0 then
      stack.set_stack({ name = stack.name, count = stack_count })
    elseif stack_count == 0 then
      stack.clear()
    end
    if stack_count > 0 then
      return 0
    end
  end
  local amount_to_add = target_count - stack_count
  if amount_to_add <= 0 then
    return 0
  end
  local amount_to_add, amount_stored = get_available_item_count(storage, item_name, amount_to_add, use_reserved)
  if amount_to_add == 0 then
    return 0
  end
  local success = stack.set_stack({ name = item_name, count = stack_count + amount_to_add })
  if success then
    storage.items[item_name] = math.max(0, amount_stored - amount_to_add)
    return amount_to_add
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

--- Counts how much of a fluid (within a temperature range) is available for usage.
--- Automatically marks DEFAULT_FLUID_RESERVATION units as reserved if necessary.
---@param storage table
---@param storage_key string
---@param min_temp number
---@param max_temp number
---@param use_reserved boolean
---@return integer total
function Storage.count_available_fluid_in_temperature_range(storage, storage_key, min_temp, max_temp, use_reserved)
  local fluid = storage.items[storage_key] or {}
  local amount_reserved = storage.reservations[storage_key] or 0
  if use_reserved and amount_reserved <= 0 then
    amount_reserved = DEFAULT_FLUID_RESERVATION
    Storage.set_item_limit_and_reservation(storage, storage_key, storage.last_entity, nil, amount_reserved)
  end
  min_temp = math.floor(min_temp or -math.huge)
  max_temp = math.floor(max_temp or math.huge)
  local total = 0
  for temperature, amount in pairs(fluid) do
    if temperature >= min_temp and temperature <= max_temp then
      total = total + math.max(0, amount - amount_reserved)
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

--- Removes fluid within a temperature range
---@param storage table
---@param storage_key string
---@param min_temp number
---@param max_temp number
---@param amount_to_remove integer
---@param use_reserved boolean
---@return integer total_removed
---@return integer new_temperature
function Storage.remove_fluid_in_temperature_range(
  storage, storage_key,
  min_temp, max_temp,
  amount_to_remove,
  use_reserved
)
  local fluid = storage.items[storage_key]
  if not fluid then
    return 0, 0
  end
  min_temp = math.floor(min_temp or -math.huge)
  max_temp = math.floor(max_temp or math.huge)
  local total_to_remove = math.ceil(amount_to_remove)
  local total_removed = 0
  local new_temperature = 0
  local amount_reserved = use_reserved and 0 or (storage.reservations[storage_key] or 0)
  for temperature, stored_amount in pairs(fluid) do
    if temperature >= min_temp and temperature <= max_temp and stored_amount > 0 then
      local amount_available = stored_amount - amount_reserved
      amount_to_remove = math.min(amount_available, total_to_remove)
      fluid[temperature] = math.max(0, stored_amount - amount_to_remove)
      new_temperature = Util.weighted_average(new_temperature, total_removed, temperature, amount_to_remove)
      total_removed = total_removed + amount_to_remove
      total_to_remove = total_to_remove - amount_to_remove
      if total_to_remove <= 0 then
        break
      end
    end
  end
  storage.items[storage_key] = fluid
  return total_removed, new_temperature
end

return Storage
