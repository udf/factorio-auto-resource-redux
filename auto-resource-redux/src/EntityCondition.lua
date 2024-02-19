local EntityCondition = {}
local Storage = require "src.Storage"
local Util = require "src.Util"

EntityCondition.OPERATIONS = { "≥", "≤" }

-- TODO: draw paused indicator
function EntityCondition.evaluate(condition, storage)
  if not condition or not condition.item then
    return true
  end
  local storage_key = condition.item
  local amount_stored = storage.items[storage_key] or 0
  if type(amount_stored) == "table" then
    amount_stored = Util.table_min_val(amount_stored)
  end
  local percent_stored = amount_stored / Storage.get_item_limit(storage, storage_key) * 100
  local op = condition.op or 1
  local value = condition.value or 0
  if op == 1 and percent_stored >= value then
    return true
  elseif op == 2 and percent_stored <= value then
    return true
  end
  return false
end

return EntityCondition
