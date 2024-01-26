-- TODO: make this a submodule of storage "StoragePriorityManager"
local ItemPriorityManager = {}

local Util = require "src.Util"
local DomainStore = require "src.DomainStore";
local EntityGroups = require "src.EntityGroups"

local DEFAULT_VEHICLE_AMMO_AMOUNT = 10
local FUEL_BURN_SECONDS_TARGET = 90

-- TODO: loading stuff into local variable might cause desync
local possible_items = {}

local function default_priorities(domain_key)
  return { domain_key = domain_key }
end

function ItemPriorityManager.get_fuel_key(entity_name)
  return "fuel;" .. entity_name
end

function ItemPriorityManager.get_ammo_key(entity_name, inv_slot_index)
  return "ammo;" .. entity_name .. ";" .. inv_slot_index
end

local function clamp_to_stack_size(item_name, count)
  local stack_size = game.item_prototypes[item_name].stack_size
  return Util.clamp(count, 1, stack_size)
end

local function find_all_possible_items()
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
      fuels[fuel_category][name] = item.fuel_value
    end
  end

  for name, entity in pairs(game.entity_prototypes) do
    if EntityGroups.names_to_groups[entity.name] ~= nil then
      local attack_parameters = entity.attack_parameters or {}
      -- ammo for turrets
      if attack_parameters.ammo_categories ~= nil then
        local key = ItemPriorityManager.get_ammo_key(name, 1)
        possible_items[key] = {}
        for _, category in ipairs(attack_parameters.ammo_categories) do
          for _, ammo_item in ipairs(ammunitions[category]) do
            possible_items[key][ammo_item] = entity.automated_ammo_count
          end
        end
      end

      -- fuel
      local burner_prototype = entity.burner_prototype
      if burner_prototype ~= nil then
        local key = ItemPriorityManager.get_fuel_key(name)
        possible_items[key] = {}
        for category, _ in pairs(burner_prototype.fuel_categories) do
          for fuel_item, fuel_value in pairs(fuels[category]) do
            local watts = entity.max_energy_usage * 60
            local num_items = math.ceil(FUEL_BURN_SECONDS_TARGET / (fuel_value / watts))
            possible_items[key][fuel_item] = clamp_to_stack_size(fuel_item, num_items)
          end
        end
      end

      -- vehicle ammo
      -- TODO: set ammo count from fire rate?
      if entity.guns ~= nil then
        for i, gun_prototype in ipairs(entity.indexed_guns) do
          local key = ItemPriorityManager.get_ammo_key(name, i)
          possible_items[key] = {}
          for _, category in ipairs(gun_prototype.attack_parameters.ammo_categories) do
            for _, ammo_item in ipairs(ammunitions[category]) do
              possible_items[key][ammo_item] = clamp_to_stack_size(ammo_item, DEFAULT_VEHICLE_AMMO_AMOUNT)
            end
          end
        end
      end
    end
  end
  log("Computed prioritisable items:")
  log(serpent.block(possible_items))
end

local function add_new_items_to_list(old_list, expected_items)
  -- add items that should exist in the same order as they appear in dest
  local seen = {}
  local new_list = {}
  for _, val in ipairs(old_list) do
    if expected_items[val] ~= nil then
      table.insert(new_list, val)
      seen[val] = true
    end
  end

  -- add new items that aren't already there
  for val, _ in pairs(expected_items) do
    if seen[val] == nil then
      table.insert(new_list, val)
    end
  end

  return new_list
end

-- TODO: perhaps don't pass entire Storage module to this function
function ItemPriorityManager.recalculate_priority_items(storage, Storage)
  log("Recalculating prioritisable items for domain " .. storage.domain_key)
  local priorities = DomainStore.get_subdomain(storage.domain_key, "priorities", default_priorities)

  -- remove unknown keys
  for key, _ in pairs(priorities) do
    if possible_items[key] == nil then
      priorities[key] = nil
    end
  end
  for key, src_table in pairs(possible_items) do
    if priorities[key] == nil then
      priorities[key] = { seen = false }
    end
    local item_amounts = Storage.filter_items(storage, src_table)
    priorities[key].items = add_new_items_to_list(priorities[key].items or {}, item_amounts)
    priorities[key].amounts = Util.dictionary_merge(priorities[key].amounts or {}, item_amounts)
  end

  log(serpent.block(priorities))
end

function ItemPriorityManager.get_priority_list(entity)
  return DomainStore.get_subdomain(DomainStore.get_domain_key(entity), "priorities", default_priorities)
end

function ItemPriorityManager.get_usable_items(priority_set)
  local usable_items = {}
  priority_set.seen = true
  for _, item_name in ipairs(priority_set.items) do
    usable_items[item_name] = priority_set.amounts[item_name]
  end
  return usable_items
end

function ItemPriorityManager.initialise()
  find_all_possible_items()
end

return ItemPriorityManager
