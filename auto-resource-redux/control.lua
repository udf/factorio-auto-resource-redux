if script.active_mods["gvv"] then require("__gvv__.gvv")() end

local Util = require("src.Util")
local DomainStore = require "src.DomainStore";
local EntityGroups = require "src.EntityGroups";
local Storage = require "src.Storage"
local EntityManager = require "src.EntityManager"
local LogisticManager = require("src.LogisticManager")
local ItemPriorityManager = require "src.ItemPriorityManager"
local GUIResourceList = require "src.GUIResourceList"

local initialised = false

local function initialise()
  -- automatically enable processing the player force
  -- TODO: other forces will need to opt in
  if global.forces == nil then
    global.forces = { "player" }
  end

  DomainStore.initialise()
  EntityGroups.initialise()
  ItemPriorityManager.initialise()
  Storage.initialise()
  EntityManager.initialise()
  LogisticManager.initialise()
  GUIResourceList.initialise()
end

local function on_tick()
  if not initialised then
    initialised = true
    initialise()
  end

  EntityManager.on_tick()
  LogisticManager.on_tick()
  GUIResourceList.on_tick()
end

local function on_gui_click(event)
  GUIResourceList.on_click(event)
end

script.on_nth_tick(1, on_tick)

-- create
script.on_event(defines.events.on_built_entity, EntityManager.on_entity_created)
script.on_event(defines.events.script_raised_built, EntityManager.on_entity_created)
script.on_event(defines.events.on_robot_built_entity, EntityManager.on_entity_created)
script.on_event(defines.events.script_raised_revive, EntityManager.on_entity_created)
script.on_event(defines.events.on_entity_cloned, EntityManager.on_entity_created)

-- delete
script.on_event(defines.events.on_pre_player_mined_item, EntityManager.on_entity_removed)
script.on_event(defines.events.on_robot_mined_entity, EntityManager.on_entity_removed)
script.on_event(defines.events.script_raised_destroy, EntityManager.on_entity_removed)
script.on_event(defines.events.on_entity_died, EntityManager.on_entity_died)

-- gui
script.on_event(defines.events.on_gui_click, on_gui_click)
