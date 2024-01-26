local LogisticManager = {}

local Util = require "src.Util"
local Storage = require "src.Storage"
local TICKS_PER_UPDATE = 120

local function handle_player_logistics(player)
  if player.force.character_logistic_requests == false then
    player.force.character_logistic_requests = true
    if player.force.character_trash_slot_count < 10 then
      player.force.character_trash_slot_count = 10
    end
    return
  end

  local trash_inv = player.get_inventory(defines.inventory.character_trash)
  local storage = Storage.get_storage(player)
  Storage.take_all_from_inventory(storage, trash_inv, true)

  -- TODO: requests
end

function LogisticManager.initialise()
  if global.player_logistics_last_update == nil then
    global.player_logistics_last_update = {}
  end
end

function LogisticManager.on_tick()
  local _, player = Util.get_next_updatable("player_logistics", TICKS_PER_UPDATE, game.connected_players)
  if player then
    handle_player_logistics(player)
  end
end

return LogisticManager
