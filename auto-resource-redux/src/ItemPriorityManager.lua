local ItemPriorityManager = {}

local flib_table = require("__flib__/table")
local Util = require "src.Util"
local DomainStore = require "src.DomainStore";
local EntityGroups = require "src.EntityGroups"

local DEFAULT_VEHICLE_AMMO_AMOUNT = 10
local FUEL_BURN_SECONDS_TARGET = 60

local default_priority_sets = {}
local entity_name_mapping = {}
ItemPriorityManager.item_names = {}

local function get_new_priority_sets(domain_key)
  local priorities = flib_table.deep_copy(default_priority_sets)
  priorities.domain_key = domain_key
  log(("Creating new priority sets list for domain %s"):format(domain_key))
  return priorities
end

local function create_subset(group, category, entity_name, sub_item_name)
  return {
    item_counts = {},
    item_order = {},
    entity_name = entity_name,
    sub_item_name = sub_item_name,
    category = category,
    group = group
  }
end

function ItemPriorityManager.get_fuel_key(entity_name)
  return "fuel." .. (entity_name_mapping[entity_name] or entity_name)
end

function ItemPriorityManager.get_ammo_key(entity_name, inv_slot_index)
  return "ammo." .. (entity_name_mapping[entity_name] or entity_name) .. "." .. inv_slot_index
end

local function clamp_to_stack_size(item_name, count)
  local stack_size = game.item_prototypes[item_name].stack_size
  return Util.clamp(count, 1, stack_size)
end

local function create_default_priority_sets()
  -- map AAI vehicles to their original names
  for entity_name, entity in pairs(game.entity_prototypes) do
    local original_name = entity_name:match("(.+)%-_%-solid") or entity_name:match("(.+)%-_%-ghost")
    if original_name then
      entity_name_mapping[entity_name] = original_name
    end
  end

  local fuels = {}
  local ammunitions = {}
  for category, _ in pairs(game.ammo_category_prototypes) do
    ammunitions[category] = {}
  end
  for category, _ in pairs(game.fuel_category_prototypes) do
    fuels[category] = {}
  end
  for name, item in pairs(game.item_prototypes) do
    local ammo_type = item.get_ammo_type()
    if ammo_type ~= nil then
      table.insert(ammunitions[ammo_type.category], name)
    end
    local fuel_category = item.fuel_category
    if fuel_category ~= nil then
      table.insert(fuels[fuel_category], name)
    end
  end

  local sort_fn = Util.prototype_order_comp_fn(
    function(item)
      return game.item_prototypes[item]
    end,
    function(a, b)
      return a > b
    end
  )
  for category, item_list in pairs(fuels) do
    table.sort(item_list, sort_fn)
  end
  for category, item_list in pairs(ammunitions) do
    table.sort(item_list, sort_fn)
  end

  for entity_name, entity in pairs(game.entity_prototypes) do
    if EntityGroups.names_to_groups[entity.name] == nil then
      goto continue
    end
    if entity_name_mapping[entity_name] ~= nil then
      goto continue
    end
    -- spiders' logistic requests should be used instead of priority insertion
    -- TODO: find out how to detect a spider-vehicle with no logistics, instead of assuming all of them support it
    if entity.type == "spider-vehicle" then
      goto continue
    end

    local attack_parameters = entity.attack_parameters or {}
    -- ammo for turrets
    if attack_parameters.ammo_categories ~= nil then
      local key = ItemPriorityManager.get_ammo_key(entity_name, 1)
      local category = "ammo." .. table.concat(attack_parameters.ammo_categories, "+")
      default_priority_sets[key] = create_subset("Ammo", category, entity_name)
      for _, category in ipairs(attack_parameters.ammo_categories) do
        for _, ammo_item in ipairs(ammunitions[category]) do
          default_priority_sets[key].item_counts[ammo_item] = entity.automated_ammo_count
        end
      end
    end

    -- fuel
    local burner_prototype = entity.burner_prototype
    if burner_prototype ~= nil then
      local key = ItemPriorityManager.get_fuel_key(entity_name)
      local category = "fuel." .. table.concat(Util.table_keys(burner_prototype.fuel_categories), "+")
      default_priority_sets[key] = create_subset(entity.is_building and "Fuel" or "Vehicle Fuel", category, entity_name)
      for category, _ in pairs(burner_prototype.fuel_categories) do
        for _, fuel_item in ipairs(fuels[category]) do
          local fuel_value = game.item_prototypes[fuel_item].fuel_value
          local watts = entity.max_energy_usage * 60
          local num_items = math.ceil(FUEL_BURN_SECONDS_TARGET / (fuel_value / watts))
          default_priority_sets[key].item_counts[fuel_item] = clamp_to_stack_size(fuel_item, num_items)
        end
      end
    end

    -- vehicle ammo
    -- TODO: set ammo count from fire rate?
    if entity.guns ~= nil then
      for i, gun_prototype in ipairs(entity.indexed_guns) do
        local key = ItemPriorityManager.get_ammo_key(entity_name, i)
        local category = "ammo." .. table.concat(gun_prototype.attack_parameters.ammo_categories, "+")
        default_priority_sets[key] = create_subset("Ammo", category, entity_name, gun_prototype.name)
        for _, category in ipairs(gun_prototype.attack_parameters.ammo_categories) do
          for _, ammo_item in ipairs(ammunitions[category]) do
            default_priority_sets[key].item_counts[ammo_item] = clamp_to_stack_size(
              ammo_item,
              DEFAULT_VEHICLE_AMMO_AMOUNT
            )
          end
        end
      end
    end
    ::continue::
  end

  -- Compute default list order
  for set_key, set in pairs(default_priority_sets) do
    for item_name, _ in pairs(set.item_counts) do
      table.insert(default_priority_sets[set_key].item_order, item_name)
      ItemPriorityManager.item_names[item_name] = true
    end
  end
  default_priority_sets.domain_key = ""

  log("Computed prioritisable items:")
  log(serpent.block(default_priority_sets))
  ::continue::
end

local function add_new_items_to_list(old_list, expected_items_dict)
  -- add items that should exist in the same order as they appear in dest
  local seen = {}
  local new_list = {}
  for _, val in ipairs(old_list) do
    if expected_items_dict[val] ~= nil then
      table.insert(new_list, val)
      seen[val] = true
    end
  end

  -- add new items that aren't already there
  for val, _ in pairs(expected_items_dict) do
    if seen[val] == nil then
      table.insert(new_list, val)
    end
  end

  return new_list
end

local function add_new_items_to_dict(old_dict, expected_items, removed_log_fmt, added_log_fmt)
  -- remove unknown keys
  for k, v in pairs(old_dict) do
    if expected_items[k] == nil then
      old_dict[k] = nil
      log(removed_log_fmt:format(k))
    end
  end
  -- add new keys
  for k, v in pairs(expected_items) do
    if old_dict[k] == nil then
      old_dict[k] = flib_table.deep_copy(v)
      log(added_log_fmt:format(k))
    end
  end
  return old_dict
end

function ItemPriorityManager.get_priority_sets(entity)
  return ItemPriorityManager.get_priority_sets_for_domain(DomainStore.get_domain_key(entity))
end

function ItemPriorityManager.get_priority_sets_for_entity(entity)
  local priority_sets = ItemPriorityManager.get_priority_sets_for_domain(DomainStore.get_domain_key(entity))
  local filtered_sets = {}
  for set_key, priority_set in pairs(priority_sets) do
    local entity_name = entity_name_mapping[entity.name] or entity.name
    if entity_name == priority_set.entity_name then
      filtered_sets[set_key] = priority_set
    end
  end
  filtered_sets.domain_key = priority_sets.domain_key
  return filtered_sets
end

function ItemPriorityManager.get_priority_sets_for_domain(domain_key)
  return DomainStore.get_subdomain(domain_key, "priorities", get_new_priority_sets)
end

function ItemPriorityManager.get_ordered_items(priority_sets, set_key)
  local usable_items = {}
  for _, item_name in ipairs(priority_sets[set_key].item_order) do
    usable_items[item_name] = priority_sets[set_key].item_counts[item_name]
  end
  return usable_items
end

function ItemPriorityManager.initialise()
  create_default_priority_sets()

  for domain_name, _ in pairs(global.domains) do
    local priority_sets = ItemPriorityManager.get_priority_sets_for_domain(domain_name)
    priority_sets.domain_key = domain_name
    add_new_items_to_dict(
      priority_sets,
      default_priority_sets,
      ("Removing unknown priority set %s:%%s"):format(domain_name),
      ("Adding priority set %s:%%s"):format(domain_name)
    )
    for set_key, priority_set in pairs(priority_sets) do
      if type(priority_set) ~= "table" then
        goto continue
      end
      local default_priority_set = default_priority_sets[set_key]
      -- add new top-level keys
      add_new_items_to_dict(
        priority_set,
        default_priority_set,
        ("Removing unknown key from priority set %s:%s:%%s"):format(domain_name, set_key),
        ("Adding new key to priority set %s:%s:%%s"):format(domain_name, set_key)
      )
      -- copy info keys
      priority_set.category = default_priority_set.category
      priority_set.entity_name = default_priority_set.entity_name
      priority_set.group = default_priority_set.group
      -- update items in this set
      add_new_items_to_dict(
        priority_set.item_counts,
        default_priority_set.item_counts,
        ("Removing unknown item %%s from priority set %s:%s"):format(domain_name, set_key),
        ("Adding new item %%s to priority set %s:%s"):format(domain_name, set_key)
      )
      -- recompute item ordering
      priority_set.item_order = add_new_items_to_list(priority_set.item_order, default_priority_set.item_counts)
      ::continue::
    end
  end
end

return ItemPriorityManager
