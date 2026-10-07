class_name ScrambledStatus
extends StatusModifier
## Every die that reaches the ship lands on its opposite face (1-6, 2-5, 3-4),
## spending one Scrambled. Dice only arrive as rolled once it has run out.
##
## The flip happens as the die is handed over rather than when the ship uses
## it, so the player watches their 6 land as a 1 and the targeting computer
## shows the action the ship will really take. Dice the ship was already
## holding are untouched — scramble first, then hand over.
##
## Hooks the ship's dice intake instead of an engine event, because dice reach
## ships by several routes (a tile's give, a refused Feed, a dying ship's dice
## scattering) and EnemyDiceManager.add() is the one door they all pass.


func _init() -> void:
	status_id = &"scrambled"
	display_name = "Scrambled"
	title_color = "green"
	icon = preload("res://Assets/Textures/Statuses/scrambled.png")
	info_icon = preload("res://Assets/Textures/Statuses/scrambled_info.png")
	is_temporary = false


func on_registered(engine: ScenarioEngine) -> void:
	super(engine)
	var intake: EnemyDiceManager = _intake()
	if intake and not intake.die_arriving.is_connected(on_die_arriving):
		intake.die_arriving.connect(on_die_arriving)


func on_unregistered(engine: ScenarioEngine) -> void:
	var intake: EnemyDiceManager = _intake()
	if intake and intake.die_arriving.is_connected(on_die_arriving):
		intake.die_arriving.disconnect(on_die_arriving)
	super(engine)


## Typed as Node and read by duck typing, like an event's activator_die.
func on_die_arriving(die: Node) -> void:
	if stacks <= 0 or not is_instance_valid(die):
		return
	die.value = 7 - die.value
	if die.has_method("play_pop"):
		die.play_pop(0.5)
	announce_triggered()
	consume(1)


func _intake() -> EnemyDiceManager:
	var ship: Node2D = host()
	if ship == null:
		return null
	return ship.get("dice_manager") as EnemyDiceManager
