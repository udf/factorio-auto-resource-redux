--[[
Scans the fluid boxes to discover the best config for a requester-tank.
]]
local FluidBoxScan = {}

local debug_fluids = false

-- look up the fluid for mining drill
local function get_drill_fluid(entity)
  local target = entity.mining_target
  if target ~= nil then
    return target.prototype.mineable_properties.required_fluid
  end
end

--[[
Check the fluidbox on the entity. We start with a requester-tank, so there should only be 1 fluidbox.
Search connected fluidboxes to find all filters.
That gives what the system should contain.
]]
local function search_fluid_system(entity, sysid, visited, extra_debug)
  if entity == nil or not entity.valid then
    return
  end
  local unum = entity.unit_number
  local fluidbox = entity.fluidbox

  -- only look at an entity once
  -- visited contains [unit_number]=true, ['locked'= { names }, 'min_temp'=X, max_temp=X}]
  visited = visited or { filter={} }
  if unum == nil or fluidbox == nil or visited[unum] ~= nil then
    return
  end
  visited[unum] = true

  -- special case for generators: they allow steam up to 1000 C, but it is a waste, so limit to the real max
  local max_temp
  if entity.type == 'generator' then
    max_temp = entity.prototype.maximum_temperature
  end
  -- and there is at least one mining drill that declared its output as 'input-output'
  local mining_drill
  if entity.type == 'mining-drill' then
    local fbp = entity.prototype.fluidbox_prototypes
    for _, v in ipairs(fbp) do
      mining_drill = v.production_type
    end
  end

  -- scan, locking onto the first fluid_system_id.
  if debug_fluids or extra_debug then
    log(('fluid visiting [%s] name=%s type=%s #fluidbox=%s'):format(unum, entity.name, entity.type, #fluidbox))
  end
  for idx = 1, #fluidbox do
    local fluid = fluidbox[idx]
    local id = fluidbox.get_fluid_system_id(idx)
    if id ~= nil and (sysid == nil or id == sysid) then
      sysid = id
      local conn = fluidbox.get_connections(idx)
      local filt = fluidbox.get_filter(idx)
      local pipes = fluidbox.get_pipe_connections(idx)

      if debug_fluids or extra_debug then
        log(("   [%s] id=%s capacity=%s fluid=%s filt=%s lock=%s #conn=%s #pipes=%s mining_drill=%s"):format(idx,
          id,
          fluidbox.get_capacity(idx),
          serpent.line(fluid),
          serpent.line(filt),
          serpent.line(fluidbox.get_locked_fluid(idx)),
          #conn,
          #pipes, serpent.line(mining_drill)))
      end

      -- fluid holds what is currently present
      if fluid ~= nil then
        local tt = visited.contents[fluid.name]
        if tt == nil then
          tt = {}
          visited.contents[fluid.name] = tt
        end
        tt[fluid.temperature] = (tt[fluid.temperature] or 0) + fluid.amount
      end

      if filt == nil and mining_drill == 'input-output' then
        local mf_name = get_drill_fluid(entity)
        if mf_name ~= nil then
          local sap = game.fluid_prototypes[mf_name]
          if sap ~= nil then
            filt = { name = sap.name, minimum_temperature = sap.default_temperature, maximum_temperature = sap.default_temperature }
          end
        end
      end

      -- only care about a fluidbox with pipe connections
      if #pipes > 0 then
        -- only update the flow_direction if there is a filter
        if filt ~= nil then
          local f = visited.filter
          local old = f[filt.name]
          if old == nil then
            old = { minimum_temperature=filt.minimum_temperature, maximum_temperature=filt.maximum_temperature }
            f[filt.name] = old
          else
            old.minimum_temperature = math.max(old.minimum_temperature, filt.minimum_temperature)
            old.maximum_temperature = math.min(old.maximum_temperature, filt.maximum_temperature)
          end
          old.output_override = (mining_drill == 'output')
          old.mining_drill = mining_drill
          -- correct the max steam temp for generators
          if max_temp ~= nil and max_temp < old.maximum_temperature then
            old.maximum_temperature = max_temp
          end
          for _, pip in ipairs(pipes) do
            visited.flows[pip.flow_direction] = true
          end
        end

        for ci = 1, #conn do
          search_fluid_system(conn[ci].owner, sysid, visited, extra_debug)
        end
      end
    end
  end
end

--[[
Determine the best configuration for the entity (requester-tank).

]]
function FluidBoxScan.autoconfig_request(entity, data)
  if debug_fluids then
    log(("autoconfig [%s] '%s' @ %s"):format(entity.unit_number, entity.name, serpent.line(entity.position)))
  end

  local fluidbox = entity.fluidbox
  if fluidbox == nil or #fluidbox ~= 1 then
    return false
  end

  local sysid = fluidbox.get_fluid_system_id(1)
  local visited = { filter={}, flows={}, contents={} }

  search_fluid_system(entity, sysid, visited, false)

  if debug_fluids then
    log(("flows=%s filter=%s"):format(serpent.line(visited.flows), serpent.line(visited.filter)))
  end

  if next(visited.filter) == nil then
    if debug_fluids then
      log("AUTO: Connect to a fluid consumer")
    end
    return false
  end

  -- if there are multitple filters, then we can't auto-config
  if table_size(visited.filter) ~= 1 then
    if debug_fluids then
      log(("AUTO: Too many fluids: %s"):format(serpent.line(visited.filter)))
    end
    return false
  end

  -- if there are multiple flow types, then we can't auto-config
  if table_size(visited.flows) ~= 1 then
    if debug_fluids then
      log("AUTO: Too many connections.")
    end
    return false
  end

  -- if anything is feeding into the fluid network (assembler), then we can't autoconfig
  if visited.flows.output == true then
    if debug_fluids then
      log("AUTO: flows.output=true")
    end
    return false
  end

  -- single input or input-output, find the best fluid temperature
  local name, filt = next(visited.filter)

  -- if we have an input-output, then we need to wait to see if there is fluid provided
  if visited.flows['input-output'] == true then
    if filt.output_override == true then
      if debug_fluids then
        log("AUTO: flows.input-output=true output_override=true")
      end
      return false
    end
  end

  local fluid_proto = game.fluid_prototypes[name]
  if fluid_proto == nil then
    return false
  end

  -- We can auto config!
  data.fluid    = name
  data.min_temp = filt.minimum_temperature
  data.max_temp = filt.maximum_temperature
  -- max out the percent for water and steam
  if name == 'water' or name == 'steam' then
    data.percent = 100
  else
    data.percent = 10
  end

  log(("AUTO: [%s] %s @ %s => %s"):format(
      entity.unit_number, entity.name, serpent.line(entity.position), serpent.line(data)))

  return true
end

return FluidBoxScan
