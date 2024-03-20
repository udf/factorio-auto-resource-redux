# Auto Resource Redux
A Factorio mod that automates most logistics so you can focus on combat.
This makes the gameplay similar to a RTS game.


# Features
## Shared Storage
Each force (team) gets a storage that's unique to each surface (game map/planet).
  The items in the storage are shown in a table at the top of the screen:  
  ![List of items in the storage](https://raw.githubusercontent.com/udf/factorio-auto-resource-redux/master/images/resource-list.png)

An item can be removed from storage by clicking its corresponding button:
- **Click** to take 1 item, **Right-Click** to take 5
- **Shift-Left Click** to take a stack, **Shift-Right Click** for half a stack
- **Ctrl-Left Click** to take all, **Ctrl-Right** click for half of the total

To store an item, simply move it to the logistics trash in the inventory screen.

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
Additionally, you can copy and paste the settings by **Shift-Middle-Clicking** over an entity:  
![Entity settings copy+paste](https://raw.githubusercontent.com/udf/factorio-auto-resource-redux/master/images/entity-settings-tool.gif)

Using these options it is possible to manage complex production chains, like cracking or Kovarex enrichment:

- Vanilla cracking: the machines should only operate when there is a surplus of the inputs:  
![Cracking](https://raw.githubusercontent.com/udf/factorio-auto-resource-redux/master/images/cracking.jpg)

- Kovarex enrichment: reserve 40+ U-235 so that the enrichment machines always have access to enough to be able to run:  
![Kovarex enrichment](https://raw.githubusercontent.com/udf/factorio-auto-resource-redux/master/images/kovarex-reservation.jpg)


## Furnaces
Furnace recipes can be set in the panel that opens next to the standard furnace UI:
![A furnace's recipe being set](https://raw.githubusercontent.com/udf/factorio-auto-resource-redux/master/images/furnace-recipe.gif)

Recipes can also be copied/pasted like with assemblers (also blueprinted):  
![copy pasting furnace recipes](https://raw.githubusercontent.com/udf/factorio-auto-resource-redux/master/images/furnace-recipe-copy-paste.gif)


## Fuel/ammo selection
The **Item Priority** section of the Auto Resource UI allows you to select which fuel/ammo item gets inserted first:  
![Vehicle item priority](https://raw.githubusercontent.com/udf/factorio-auto-resource-redux/master/images/entity-settings-vehicle.png)

Items are used from left to right, and clicking on an item allows the insertion quantity to be configured.
Read the in-game tooltips to learn how to rearrange the items.

A UI containing all configurable items can also be accessed by clicking the gear icon:  
![Vehicle item priority opening full UI](https://raw.githubusercontent.com/udf/factorio-auto-resource-redux/master/images/entity-settings-vehicle-priority.gif)

It can also be accessed via the gear icon at the top-left of the screen.


## Collection of mined resources
Resources mined by a mining drill are placed into a hidden chest that is created when the mining drill is built - the mod collects items from this hidden chest:  
![Mining drill hidden chests](https://raw.githubusercontent.com/udf/factorio-auto-resource-redux/master/images/miner-chest-alt-mode.png)

Miners mining fluids (like pumpjacks) have an internal fluid storage, so nothing extra is needed for those.

Miners needing fluids (like uranium) are not handled automatically as there is no simple way to determine what fluid they need - you will have to manually request fluid using the "Requester Tank":  
![Uranium mining](https://raw.githubusercontent.com/udf/factorio-auto-resource-redux/master/images/uranium-mining.jpg)


## Fluid handling
Fluids can be requested from storage using the "Requester Tank". It has a custom UI allowing you to choose the temperature and level of fluid to request:  
![Requester tank GUI](https://raw.githubusercontent.com/udf/factorio-auto-resource-redux/master/images/requester-tank-steam.png)

The fluid requester can be used for flamethrower turrets or even to power your outposts remotely:  
![Requester tank powering an outpost](https://raw.githubusercontent.com/udf/factorio-auto-resource-redux/master/images/requester-tank-power.jpg)

Fluids can be inserted into storage using the "Sink Tank", any fluid inserted into it will be transferred into your storage if there is space. The steam for the outpost above is provided this way:  
![Sink tank collecting steam](https://raw.githubusercontent.com/udf/factorio-auto-resource-redux/master/images/sink-tank-steam.jpg)


## Logistics
- Logistic and trash requests from players are automatically fulfilled.
- Items can be requested using the "Auto Resource Requester Chest", this is useful if you want to insert items into something that this mod does not currently support.


## Construction logistics
Items requested by construction bots will automatically be inserted into the nearest "Auto Resource Storage Chest":  
![Bot construction](https://raw.githubusercontent.com/udf/factorio-auto-resource-redux/master/images/bot-construction.mp4)

The "Auto Resource Storage Chest" will automatically send its contents back to your storage when not in use, this allows you to remotely collect items using construction bots:  
![Bot deconstruction](https://raw.githubusercontent.com/udf/factorio-auto-resource-redux/master/images/bot-deforestation.mp4)


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
