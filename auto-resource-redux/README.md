# Auto Resource Redux
A Factorio mod that automates most logistics so you can focus on combat.
This makes the gameplay similar to a RTS game.

# Features
## Global Storage
Each force (team) gets a global storage that's unique to each surface.
  The items in the storage are shown in a table at the top of the screen:  
  ![List of items in the storage](https://raw.githubusercontent.com/udf/factorio-auto-resource-redux/master/images/resource-list.png)

An item can be removed from storage by clicking its corresponding button:
- **Click** to take 1 item, **Right-Click** to take 5
- **Shift-Left Click** to take a stack, **Shift-Right Click** for half a stack
- **Ctrl-Left Click** to take all, **Ctrl-Right** click for half of the total

To add an item, simply move it to the logistics trash in the inventory screen.

**Middle-Click** an item to open the limit settings:
![Limit dialogue](https://raw.githubusercontent.com/udf/factorio-auto-resource-redux/master/images/resource-limit.png)  
A limit can be set to prevent producing too much of an item.  
A reservation can be set to always keep some resources in storage.

Most items can be stored, aside from ones that contain other items - like armours or vehicles (storing these would strip them of their contents, as the items are removed from the game world when they are stored).

## Multiplayer Compatible
Storages are separated by forces, allowing you to play co-op or PvP.
When joining a new force, the gear icon in the top left must be clicked to activate the mod for your force.

## Automated assemblers
- Items and fluids needed by assemblers are automatically managed. Simply set a recipe and the machine will receive items automatically.
- You can prevent overproduction of an item by setting a limit for it, or by setting a condition on the machine.

## Conditional insertion
A UI has been added to every entity that this mod manages:  
![Entity panel](https://raw.githubusercontent.com/udf/factorio-auto-resource-redux/master/images/entity-panel.png)
- **Prioritise**: Allows a machine to use reserved resources (this will set a reservation on the items if necessary). Boilers and vehicles automatically have this set which ensures that your power production always gets fuel.
- **Enabled condition**: if set, items will only be inserted when the condition is met.

These settings will be stored in blueprints and can also be copied/pasted.  
Additionally, you can copy and paste the settings by **Shift-Middle-Clicking** over an entity whose that you want to copy:  
(TODO: gif of settings copypasta)

Using these options it is possible to manage complex production chains, like cracking or Kovarex enrichment:

- Vanilla cracking: the machines should only operate when there is a surplus of the inputs:  
(TODO: image of cracking with entity panels shown)

- Kovarex enrichment: reserve 40+ U-235 so that the enrichment machines always have access to enough to be able to run:  
(TODO: image of Kovarex with entity panel and reserve menu shown)

## Furnaces
- Furnace recipes can be set in the custom UI that opens next to the standard furnace UI.  
(TODO: gif of furnace recipe being set)
- Recipes can also be copied/pasted as well as blueprinted:  
(TODO: gif of furnace recipe copy paste, and then full furnace copy paste)

## Fuel/ammo selection
The **Item Priority** section of the conditions UI allows you to select which fuel/ammo item gets inserted first:  
(TODO: image of item priority on a vehicle's entity panel)

Clicking on an item allows the quantity that should be inserted to be configured.  
Read the in-game tooltips to learn how to rearrange the items.

A UI containing all configurable items can also be accessed by clicking the gear icon in the top left of the screen:  
(TODO: gif of clicking gear in entity panel and big UI opening)

## Collection of mined resources
Resources mined by a mining drill are placed into a hidden chest that is created when the mining drill is built - the mod collects items from this hidden chest:  
(TODO: image of hidden chests alt-mode)

Miners needing fluids (like uranium) are not handled automatically as there is no simple way to determine what fluid they need - you will have to manually request fluid using the "Requester Tank":  
(TODO: image of mining uranium using requester chest)

Miners mining fluids (like pumpjacks) have an internal fluid storage, so nothing extra is needed for those.

## Fluid handling
Fluids can be requested from storage using the "Requester Tank". It has a custom UI allowing you to choose the temperature and quantity of fluid to request:  
(TODO: image of requester tank UI on steam)

The fluid requester can be used for flamethrower turrets or even to power your outposts remotely:  
(TODO: image of requester tank going into steam engines)

Fluids can be inserted into storage using the "Sink Tank", any fluid inserted into it will be transferred into your storage if there is space.  
(TODO: image of water pump going into sink tank)

## Logistics
- Logistic and trash requests from players are automatically fulfilled.
- Items can be requested using the "Auto Resource Requester Chest", this is useful if you want to insert items into something that this mod does currently support.

## Construction logistics
- Items requested by construction bots will automatically be inserted into the logistics network.  
(TODO: gif of bots pulling items out of storage chest)
- It is recommended to use the "Auto Resource Storage Chest" as its contents will automatically be sent back to your storage when it is idle, this allows you to remotely collect items using construction bots.  
(TODO: gif of bots eating trees and wood count increasing)

# Performance
Performance on a large base has not yet been evaluated. Care has been taken to ensure that the mod spreads its work out over time to not cause any stutters.

# Mod support
- Mods that replace entities like [AAI Programmable Vehicles](https://mods.factorio.com/mod/aai-programmable-vehicles) are supported (`on_entity_replaced` interface).

This mod should be compatible with most mods, however specific mod compatibility has not yet been evaluated.

# Similar mods
- [auto resource](https://mods.factorio.com/mod/auto-resource) - The main inspiration for this mod
- [Quantum Resource Distribution](https://mods.factorio.com/mod/QuantumResourceDistribution2)
- [Quasar chests](https://mods.factorio.com/mod/quasar-chest)
- [Item Network](https://mods.factorio.com/mod/item-network)