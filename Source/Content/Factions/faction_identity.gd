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
## The faction's light accent (LORE.md §12), for its name on the info panel.
@export var color: Color = Color.WHITE
## Translation key: the faction's answer to the end, in a line (LORE.md §2).
@export var motto: String
## Translation key: who they are, in a sentence or two, for a player who
## clicks the badge to ask who they're facing.
@export var description: String


## The info panel for this faction: what the badge on the targeting computer
## says when clicked.
func info() -> InfoResource:
	var panel: InfoResource = InfoResource.new()
	panel.title_label_text = "[color=#%s]%s[/color]" % [color.to_html(false), display_name]
	panel.top_label_text = TranslationServer.translate(motto)
	panel.texture = icon
	panel.bottom_label_text = TranslationServer.translate(description)
	return panel
