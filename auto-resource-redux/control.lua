if script.active_mods["gvv"] then require("__gvv__.gvv")() end

local DomainStore = require "src.DomainStore";
local EntityCustomData = require "src.EntityCustomData"
local EntityGroups = require "src.EntityGroups";
local EntityManager = require "src.EntityManager"
local FurnaceRecipeManager = require "src.FurnaceRecipeManager"
local GUIDispatcher = require "src.GUIDispatcher"
local GUIModButton = require "src.GUIModButton"
local GUIRequesterTank = require "src.GUIRequesterTank"
local GUIEntityPanel = require "src.GUIEntityPanel"
local GUIResourceList = require "src.GUIResourceList"
local ItemPriorityManager = require "src.ItemPriorityManager"
local LogisticManager = require("src.LogisticManager")
local Storage = require "src.Storage"
local Util = require("src.Util")

local initialised = false

local function initialise()
  -- automatically enable processing the player force
  if global.forces == nil then
    global.forces = { player = true }
  end

  DomainStore.initialise()
  EntityGroups.initialise()
  ItemPriorityManager.initialise()
  Storage.initialise()
  EntityCustomData.initialise()
  FurnaceRecipeManager.initialise()
  EntityManager.initialise()
  LogisticManager.initialise()
  GUIResourceList.initialise()
  GUIEntityPanel.initialise()
end

local function on_tick()
  if not initialised then
    initialised = true
    initialise()
  end

  EntityManager.on_tick()
  LogisticManager.on_tick()
  GUIModButton.on_tick()
  GUIResourceList.on_tick()
  GUIEntityPanel.on_tick()
end

local function on_built(event)
  EntityManager.on_entity_created(event)
  EntityCustomData.on_built(event)
end

local function on_cloned(event)
  EntityManager.on_entity_created(event)
  EntityCustomData.on_cloned(event)
end

local function on_player_changed_surface(event)
  if not initialised then
    return
  end
  GUIResourceList.on_player_changed_surface(event)
end

script.on_nth_tick(1, on_tick)

-- create
script.on_event(defines.events.on_built_entity, on_built)
script.on_event(defines.events.on_robot_built_entity, on_built)
script.on_event(defines.events.script_raised_revive, on_built)
script.on_event(defines.events.on_entity_cloned, on_cloned)
script.on_event(defines.events.script_raised_built, EntityManager.on_entity_created)

-- delete
script.on_event(defines.events.on_pre_player_mined_item, EntityManager.on_entity_removed)
script.on_event(defines.events.on_robot_mined_entity, EntityManager.on_entity_removed)
script.on_event(defines.events.script_raised_destroy, EntityManager.on_entity_removed)
script.on_event(defines.events.on_entity_died, EntityManager.on_entity_died)

-- custom
remote.add_interface("auto-resource-redux", { on_entity_replaced = EntityManager.on_entity_replaced })

-- gui
script.on_event(defines.events.on_gui_click, GUIDispatcher.on_event)
script.on_event(defines.events.on_gui_closed, GUIDispatcher.on_event)
script.on_event(defines.events.on_gui_value_changed, GUIDispatcher.on_event)
script.on_event(defines.events.on_gui_text_changed, GUIDispatcher.on_event)
script.on_event(defines.events.on_gui_elem_changed, GUIDispatcher.on_event)
script.on_event(defines.events.on_gui_checked_state_changed, GUIDispatcher.on_event)
script.on_event(GUIDispatcher.ON_CONFIRM_KEYPRESS, GUIDispatcher.on_event)
script.on_event(defines.events.on_gui_confirmed, GUIDispatcher.on_event)
script.on_event(defines.events.on_gui_opened, GUIDispatcher.on_event)
script.on_event(defines.events.on_gui_selection_state_changed, GUIDispatcher.on_event)
script.on_event(defines.events.on_gui_location_changed, GUIEntityPanel.on_location_changed)

-- blueprint/settings
script.on_event(defines.events.on_player_setup_blueprint, EntityCustomData.on_setup_blueprint)
script.on_event(defines.events.on_entity_settings_pasted, EntityCustomData.on_settings_pasted)
script.on_event(GUIDispatcher.ON_COPY_SETTINGS_KEYPRESS, GUIDispatcher.on_event)
script.on_event(defines.events.on_player_selected_area, EntityCustomData.on_player_selected_area)
script.on_event(defines.events.on_player_alt_selected_area, EntityCustomData.on_player_alt_selected_area)
script.on_event(GUIDispatcher.ON_COPY_CONDITIONS_KEYPRESS, GUIDispatcher.on_event)

-- other
script.on_event(defines.events.on_player_changed_surface, on_player_changed_surface)