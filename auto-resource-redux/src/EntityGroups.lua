local EntityGroups = {}

-- mapping of entity names to our "group" for them
EntityGroups.names_to_groups = {}

local entity_group_filters = {
  ["car"] =  { filter = "type", type = "car" },
  ["boiler"] =  { filter = "type", type = "boiler" },
  ["furnace"] =  { filter = "type", type = "furnace" },
  ["mining-drill"] =  { filter = "type", type = "mining-drill" },
  ["ammo-turret"] =  { filter = "type", type = "ammo-turret" },
  ["assembling-machine"] =  { filter = "type", type = "assembling-machine" },
  ["lab"] =  { filter = "type", type = "lab" },
  ["sink-chest"] = { filter = "name", name = "arr-sink-chest" },
  ["sink-tank"] = { filter = "name", name = "arr-sink-tank" },
}

function EntityGroups.calculate_groups()
  EntityGroups.names_to_groups = {}
  for group_name, prototype_filter in pairs(entity_group_filters) do
    local entity_prototypes = game.get_filtered_entity_prototypes({ prototype_filter })
    for name, prototype in pairs(entity_prototypes) do
      EntityGroups.names_to_groups[name] = group_name
    end
  end
end

function EntityGroups.initialise()
  EntityGroups.calculate_groups()
end

return EntityGroups