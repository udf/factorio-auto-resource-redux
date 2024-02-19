local EntityGroups = {}

-- mapping of entity names to our "group" for them
EntityGroups.names_to_groups = {}

-- TODO: rocket silo, reactor
EntityGroups.entity_group_filters = {
  ["car"] =  { filter = "type", type = "car" },
  ["boiler"] =  { filter = "type", type = "boiler" },
  ["furnace"] =  { filter = "type", type = "furnace" },
  ["mining-drill"] =  { filter = "type", type = "mining-drill" },
  ["ammo-turret"] =  { filter = "type", type = "ammo-turret" },
  ["assembling-machine"] =  { filter = "type", type = "assembling-machine" },
  ["lab"] =  { filter = "type", type = "lab" },
  ["sink-chest"] = { filter = "name", name = "arr-hidden-sink-chest" },
  ["sink-tank"] = { filter = "name", name = "arr-sink-tank" },
  ["logistic-sink-chest"] = { filter = "name", name = "arr-logistic-sink-chest" },
  ["logistic-requester-chest"] = { filter = "name", name = "arr-logistic-requester-chest" },
  ["arr-requester-tank"] = { filter = "name", name = "arr-requester-tank" },
}

function EntityGroups.calculate_groups()
  EntityGroups.names_to_groups = {}
  for group_name, prototype_filter in pairs(EntityGroups.entity_group_filters) do
    local entity_prototypes = game.get_filtered_entity_prototypes({ prototype_filter })
    for name, prototype in pairs(entity_prototypes) do
      EntityGroups.names_to_groups[name] = group_name
    end
  end
end

function EntityGroups.can_manage(entity)
  return EntityGroups.names_to_groups[entity.name] ~= nil
end

function EntityGroups.initialise()
  EntityGroups.calculate_groups()
end

return EntityGroups