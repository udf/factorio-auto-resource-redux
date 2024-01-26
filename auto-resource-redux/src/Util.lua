local Util = {}

Util.UINT_MAX = 4294967295

--- Clamps a value to be in the range [low, high]
---@param val number The value to clamp
---@param low number The minimum value
---@param high number The maximum value
---@return number n The clamped value
function Util.clamp(val, low, high)
  return math.min(high, math.max(val, low))
end

--- Adds the new keys from src into dest
---@param dest table The table to add keys to, this table will be modified
---@param src table The table to get keys from
---@return table dest The destination table
function Util.dictionary_merge(dest, src)
  for k, v in pairs(src) do
    if dest[k] == nil then
      dest[k] = v
    end
  end
  return dest
end

--- Returns the keys from dict as an array
---@param dict table The table to get keys from
---@return table keys The array of keys from dict
function Util.table_keys(dict)
  local keys = {}
  for k, v in pairs(dict) do
    table.insert(keys, k)
  end
  return keys
end

--- Filters the given table using the given filter function
---@param t any The table to filter
---@param filter_fn function A filter function that takes the arguments (k, v),
---return a truthy value to include it in the filtered table
---@return table filtered The filtered result
function Util.table_filter(t, filter_fn)
  local ret = {}
  for k, v in pairs(t) do
    if filter_fn(k, v) then
      ret[k] = v
    end
  end
  return ret
end

--- Gets the min, max and sum of all the values in a table
---@param dict table The table to get values from
---@return number num_vals The number of values in the table
---@return number sum The sum of all the values
---@return number min The minimum of all the values
---@return number max The maximum of all the values
function Util.table_val_stats(dict)
  local num_vals = 0
  local sum = 0
  local min = math.huge
  local max = -math.huge
  for k, v in pairs(dict) do
    num_vals = num_vals + 1
    sum = sum + v
    min = math.min(min, v)
    max = math.max(max, v)
  end
  return num_vals, sum, min, max
end

--- Gets the sum of all the values in a table
---@param dict table The table to get values from
---@return number sum The sum of all the values
function Util.table_sum_vals(dict)
  local sum = 0
  for k, v in pairs(dict) do
    sum = sum + v
  end
  return sum
end

--- Gets the next key+value pair from t that was fetched at least min_tick_diff ticks ago
---@param state_key string The key to use when storing the timing state in global
---@param min_tick_diff integer Minimum number of ticks for an item to be considered out of date
---@param t table The table of values to check
---@return any k The first key that needs updating
---@return any v The corresponding value of the key that needs updating
function Util.get_next_updatable(state_key, min_tick_diff, t)
  local last_table_key = global[state_key .. "_last_key"]
  local last_update_key = state_key .. "_last_update"
  if global[last_update_key] == nil then
    global[last_update_key] = {}
  end

  local last_updates = global[last_update_key]
  if next(t, last_table_key) == nil then
    last_table_key = nil
  end

  for k, v in next, t, last_table_key do
    if game.tick - (last_updates[k] or 0) >= min_tick_diff then
      last_updates[k] = game.tick
      global[state_key .. "_last_key"] = k
      return k, v
    end
  end
end

--- Iterates fluidboxes that are of a certain production_type
---@param entity LuaEntity The entity with fluidboxes to iterate over
---@param prod_type_pattern string The pattern to check against the production_type of each fluidbox
---@param iter_all boolean Set to true to iterate all fluidboxes instead of only those containing a fluid
---@return function iterator An iterator over the matched fluidboxes
function Util.iter_fluidboxes(entity, prod_type_pattern, iter_all)
  local i = 0
  local n = #entity.fluidbox
  return function()
    while i < n do
      i = i + 1
      local fluid = entity.fluidbox[i]
      local proto = entity.fluidbox.get_prototype(i)
      if (iter_all or fluid ~= nil) and string.match(proto.production_type, prod_type_pattern) then
        local filter = entity.fluidbox.get_filter(i)
        if not fluid and filter then
          fluid = { name = filter.name, temperature = filter.minimum_temperature, amount = 0 }
        end
        return i, fluid, filter
      end
    end
  end
end

--- Gets the default temperature for given fluid
---@param fluid_name string The name of the fluid
---@return number temperature The default temperature for the fluid
function Util.get_default_fluid_temperature(fluid_name)
  local temp = game.fluid_prototypes[fluid_name].default_temperature
  assert(temp ~= nil)
  return temp
end

return Util
