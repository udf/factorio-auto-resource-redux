# Auto Resource Redux
A Factorio mod that automates most logistics so you can focus on combat.
This makes the gameplay similar to a RTS game.

# Features
## Global Storage
- Each force (team) gets a global storage that's unique to each surface (planet).  
(TODO: image)

- The storage can be accessed from the table at the top of the screen:
    - **Click** to take 1 item, **right-click** to take 5
    - **Shift-left click** to take a stack, **shift-right click** for half a stack
    - **Ctrl-left click** to take all, **ctrl-right** click for half of the total

- Middle-click an item to open the limit settings
    - (TODO: image)
    - Set a limit to prevent producing too much of an item
    - Set a reservation to prevent a resource from going below that amount

- Most items can be stored, aside from ones that contain things - like armours or vehicles (storing items like these would strip them of their contents).

## Multiplayer Compatible
- Storages are separated by forces, allowing you to play co-op or PvP.
- When joining a new force, the gear icon in the top left must be clicked to activate the mod  
(TODO: image)

## Automated assemblers
- Items and fluids needed by assemblers are automatically managed. Simply set a recipe and the machine will begin working automatically.
- You can prevent overproduction of an item by setting a limit for it, or by setting a condition on the machine.

## Conditional insertion
- A new UI has been added to every entity that this mod manages:  
(TODO: image)
- **Prioritise**: Allows a machine to use reserved resources (this will set a reservation on the items if necessary). Boilers and vehicles automatically have this set which ensures that your power production always gets fuel.
- **Enabled condition**: if set, items will only be inserted when the condition is met.
- These settings will be stored in blueprints and can also be copied/pasted.
- You can paste settings using a selection tool by **shift-middle-clicking** over an entity with the settings that you want to copy:  
(TODO: gif)

Using these options it is possible to manage complex production chains, like cracking or Kovarex enrichment:

- Vanilla cracking: the machines should only operate when there is a surplus of the inputs:  
TODO: image of cracking

- Kovarex enrichment: reserve 40+ U-235 so that the enrichment machines always have access to enough to be able to run.:  
TODO: image of Kovarex

## Furnaces
- Furnace recipes can be set in the custom UI that opens next to the standard furnace UI.  
(TODO: image)
- Recipes can also be copied/pasted as well as blueprinted:  
(TODO: gif)

## Fuel/ammo selection
The **Item Priority** section of the conditions UI allows you to select which fuel/ammo item gets inserted first:  
(TODO: image)

A UI containing all configurable items can also be accessed by clicking the gear icon in the top left of the screen:  
(TODO: image)

## Collection of mined resources
Resources mined by a mining drill are placed into a hidden chest that is created when the mining drill is placed - the mod then collects items from this hidden chest:  
(TODO: image)

Miners needing fluids (like uranium) are not handled automatically as there is no simple way to determine what fluid they need - you will have to manually request fluid using the "Requester Tank":  
(TODO: image)

Miners mining fluids (like pumpjacks) have an internal fluid storage, so nothing extra is needed for those.

## Fluid handling
Fluids can be requested from storage using the "Requester Tank". It has a custom UI allowing you to choose the temperature and quantity of fluid to request:  
(TODO: image)

The fluid requester can be used for flamethrower turrets or even to power your outposts remotely:  
(TODO: image)

Fluids can be inserted into storage using the "Sink Tank", any fluid inserted into it will be transferred into your storage if there is space.  
(TODO: image)

## Logistics
- Logistic and trash requests from players are automatically fulfilled.
- Items can be requested using the "Auto Resource Requester Chest", this is useful if you want to insert items into something that this mod does currently support.

## Construction logistics
- Items requested by construction bots will automatically be inserted into the logistics network.  
(TODO: gif)
- It is recommended to use the "Auto Resource Storage Chest" as its contents will automatically be sent back to your storage when it is idle, this allows you to remotely collect items using construction bots.  
(TODO: gif)

# Performance
Performance on a large base has not yet been evaluated. Care has been taken to ensure that the mod spreads its work out over time to not cause any stutters.

# Mod support
- Mods that replace entities like [AAI Programmable Vehicles](https://mods.factorio.com/mod/aai-programmable-vehicles) are supported.

This mod should be compatible with most mods, however specific mod compatibility has not yet been evaluated.

# Similar mods
- [auto resource](https://mods.factorio.com/mod/auto-resource) - The main inspiration for this mod
- [Quantum Resource Distribution](https://mods.factorio.com/mod/QuantumResourceDistribution2)
- [Quasar chests](https://mods.factorio.com/mod/quasar-chest)
- [Item Network](https://mods.factorio.com/mod/item-network)