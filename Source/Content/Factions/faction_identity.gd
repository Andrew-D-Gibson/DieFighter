class_name FactionIdentity
extends Resource
## Which of the fleet's factions (LORE.md §2) a ship belongs to, and how that
## reads at a glance. Every ship of a faction shares its colours and shapes
## (LORE.md §12, the visual language); this resource carries the parts the UI
## draws, like the badge on the targeting computer.
##
## This is the ship's identity, not its side in a fight: who a ship fights for
## in an encounter is the scenario's ship state (ScenarioManager.Faction), so a
## Rearguard-built ship can still turn up as hired pirate muscle.

@export var display_name: String
## A 7x7 badge in the faction's own colours, shown beside the target's
## portrait on the targeting computer.
@export var icon: Texture2D
