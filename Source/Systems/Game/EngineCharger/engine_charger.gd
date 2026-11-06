class_name EngineCharger
extends Node2D

@export var progress_bar: TextureProgressBar
@export var fill_head: Sprite2D
@export var charged_indicator: Sprite2D
@export var display_text: RichTextLabel

## Applied to the charged indicator while the drive is past the gate.
const _REDLINE_TINT: Color = Color(1.0, 0.45, 0.45)
## The Horizon Drive's colour (LORE.md §4): the gold of the halo on its
## tile. The charger wears it from the moment the dying Bastion hands the
## drive over, and the ending cutscene's engines burn with it.
const DRIVE_COLOR: Color = Color("#eed35d")
const _DRIVE_RINGS: Texture2D = preload("res://Assets/Textures/Enemies/ParticleTextures/engine_ring_large_drive.png")
## The flat purple the bar's fill and charged light are drawn in.
const _FILL_PURPLE: Color = Color("#c552f1")
## Multiplies that purple into the drive's gold, channel by channel: the
## Reckoning's bar is the escape, worn in the Horizon Drive's colour
## (RECKONING_ENDINGS.md §1) without a second set of art.
const _GOLD_TINT: Color = Color(
	DRIVE_COLOR.r / _FILL_PURPLE.r, DRIVE_COLOR.g / _FILL_PURPLE.g, DRIVE_COLOR.b / _FILL_PURPLE.b)

## How far the readout may shrink for a three-digit goal (the 3/6 pixel step).
const _READOUT_MIN_SCALE: float = 0.5

## What the fill and the charged light are multiplied by: white normally,
## _GOLD_TINT for the Reckoning.
var _dress: Color = Color.WHITE

## The fill level the bar is currently animating towards. Tracked separately
## from progress_bar.value because several charge changes can land in the same
## frame before any tween has stepped, and the bar's value would still read as
## the pre-tween one.
var _target_proportion: float = -1.0
var _bar_tween: Tween
var _head_tween: Tween


func _ready() -> void:
	# Effects that move engine charge draw to and from here (Juice.engine_anchor).
	add_to_group(&"engine_charger")
	# The charger opens empty: a run starts mid-ambush, with the engine cold.
	progress_bar.value = 0
	fill_head.position = Vector2(60, 2)
	fill_head.visible = true
	charged_indicator.visible = false
	# The Reckoning's goal runs to three digits ("110/165"), well past the
	# label's authored room: it shrinks in whole pixels to stay inside it
	# rather than spilling off the gauge. align_by_ink off keeps "10/10" sitting
	# where the label's line box always put it.
	var fitter: TextFitter = TextFitter.attach(display_text, TextFitPolicy.single_line(_READOUT_MIN_SCALE))
	fitter.box_source = TextFitter.BoxSource.AUTHORED
	fitter.policy.align_by_ink = false
	# The tile's info shows the drive as it stands, as the hull's shows the hull.
	var tile: Tile = get_node_or_null(^"EngineChargerTile") as Tile
	if tile:
		tile.info_picture = _info_picture.bind(tile)

	Events.engine_charge_changed.connect(_update_ui)
	Events.start_scenario.connect(_update_ui)
	Events.load_scenario.connect(_check_for_combat_scenario)
	Events.start_combat.connect(func() -> void:
		Globals.player.engine_charge = 0
		_update_ui()
	)
	Events.combat_finished.connect(_refill_after_combat)
	Events.vanguard_drive_taken.connect(_install_drive.bind(true))
	Events.load_game_save.connect(func(_save: GameSaveResource) -> void: _refresh_drive.call_deferred())
	Events.die_added.connect(func() -> void:
		if Globals.state_manager.state == GameStateManager.GameState.OUT_OF_COMBAT:
			Globals.player.engine_charge = Globals.player.max_engine_charge
		_update_ui()
	)


## A Continue puts back the drive the run was handed.
func _refresh_drive() -> void:
	if Globals.fate_ledger and Globals.fate_ledger.has_drive:
		_install_drive(false)


## The Horizon Drive goes into the charger: the tile shimmers as upgraded,
## in the drive's colour, and its rings burn gold. [param announce] is the
## hand-over itself, with the upgrade's burst and a callout.
func _install_drive(announce: bool) -> void:
	var tile: Tile = get_node_or_null(^"EngineChargerTile") as Tile
	if not tile:
		return
	TileUpgradeLook.set_override(tile, DRIVE_COLOR)
	var rings: GPUParticles2D = tile.get_node_or_null(^"ParticleMask/LargeEngineParticles") as GPUParticles2D
	if rings:
		rings.texture = _DRIVE_RINGS
	if announce:
		TileUpgradeLook.burst_in(tile, DRIVE_COLOR)
		Juice.callout(tile, tr(&"CALLOUT_VANGUARD_DRIVE"), DRIVE_COLOR, true)


## The Reckoning's dress (RECKONING_ENDINGS.md §1): the bar fills gold, as
## the escape. [param on] false puts the purple back.
func set_escape_dress(on: bool) -> void:
	_dress = _GOLD_TINT if on else Color.WHITE
	progress_bar.tint_progress = _dress
	_update_ui()


## The bank just filled: the gauge flares gold and the drive calls out on the
## last point (RECKONING_ENDINGS.md §6.1).
func flare_full() -> void:
	var tile: Tile = get_node_or_null(^"EngineChargerTile") as Tile
	var at: Vector2 = get_juice_anchor()
	Juice.sparkle(self, at, DRIVE_COLOR, 16, 40.0, true)
	Juice.ring(self, at, DRIVE_COLOR, 28.0, 0.45, 3.0)
	if tile:
		TileUpgradeLook.burst_in(tile, DRIVE_COLOR)
		Juice.callout(tile, tr(&"CALLOUT_VANGUARD_DRIVE"), DRIVE_COLOR, true)


## Where effects that move engine charge draw to and from: the middle of the
## gauge. The node's own origin sits off to its left, out in the tile grid.
func get_juice_anchor() -> Vector2:
	return progress_bar.get_global_rect().get_center()


func _info_picture(tile: Tile) -> Texture2D:
	var art: Texture2D = tile.tile_resource.textures.get_frame_texture(&"default", 0)
	if not Globals.player:
		return art
	return EngineChargeInfoArt.texture_for(
		Globals.player.engine_charge, Globals.player.max_engine_charge, art
	)


## Winning a fight refills the drive.
##
## A plain assignment is safe because combat_finished is now emitted from
## EndCombatEvent, which resolves after the chain that won the fight — so a
## tile that strikes and then charges a price against the engine has already
## been paid for by the time this runs.
func _refill_after_combat() -> void:
	Globals.player.engine_charge = Globals.player.max_engine_charge
	_update_ui()


## Sets the drive for a scenario the player is arriving at: cold for an
## ambush, full otherwise.
##
## A Continue from a mid-scenario save is not an arrival. Player restores the
## checkpointed charge from the save just before this scenario's load_scenario,
## and that value already accounts for the arrival plus anything since —
## redline surplus from the last fight, charge spent in a shop. Resetting it
## here would erase both. (A Continue from an arrival checkpoint recomputes
## here to the same charge it saved.)
func _check_for_combat_scenario(scenario: ScenarioResource) -> void:
	if Globals.state_manager and not Globals.state_manager.get_restore().is_empty():
		return

	var in_combat: bool = false
	for ship: EnemyStateRewardResource in scenario.starting_enemies:
		var opening: ScenarioShipState = ship.opening_state()
		if opening and opening.attitude == Enemy.Attitude.AGGRESSIVE:
			in_combat = true
			break

	Globals.player.engine_charge = 0 if in_combat else Globals.player.max_engine_charge


func _update_ui() -> void:
	if not Globals.player:
		return
		
	# The bar tops out at the jump gate. Charge above it is redline, shown by
	# recolouring the charged indicator and spelling the surplus out in the
	# readout, rather than by overflowing a bar that has nowhere to go.
	var charge_proportion: float = minf(
		1.0, Globals.player.engine_charge / float(Globals.player.max_engine_charge)
	)
	if charge_proportion != _target_proportion:
		_target_proportion = charge_proportion
		var tween_time: float = 0.25
		
		# Any tween still in flight is chasing a stale charge value, so it has
		# to die before a new one starts or the two fight over the bar.
		if _bar_tween and _bar_tween.is_valid():
			_bar_tween.kill()
		if _head_tween and _head_tween.is_valid():
			_head_tween.kill()
		
		_bar_tween = get_tree().create_tween()
		_bar_tween.tween_property(
			progress_bar, 
			'value', 
			charge_proportion, 
			tween_time
		)\
		.from_current()\
		.set_trans(Tween.TRANS_QUAD)
		
		# The bar is 32 long and the head bar's maximum y is 2
		var desired_head_ypos: float = 2 - (charge_proportion * 32)
		_head_tween = get_tree().create_tween()
		_head_tween.tween_property(
			fill_head, 
			'position', 
			Vector2(60, desired_head_ypos), 
			tween_time
		)\
		.from_current()\
		.set_trans(Tween.TRANS_QUAD)
		
	if charge_proportion >= 1:
		fill_head.visible = false
		charged_indicator.visible = true
		# Redlining is dangerous, so the "you may leave" light stops reading
		# as reassurance and goes hot.
		charged_indicator.modulate = (
			_REDLINE_TINT if Globals.player.is_overcharged() else Color.WHITE
		) * _dress
	else:
		fill_head.visible = true
		charged_indicator.visible = false
		charged_indicator.modulate = _dress
		
	# The readout is only about five characters wide, so the redline can't just
	# be appended to "10/10" — it clips. Past the gate the denominator carries
	# no information (it's always full), so the surplus takes its place: "10+3".
	if Globals.player.is_overcharged():
		display_text.text = str(Globals.player.max_engine_charge) \
			+ '+' + str(Globals.player.overcharge_amount())
	else:
		display_text.text = str(Globals.player.engine_charge) \
			+ '/' + str(Globals.player.max_engine_charge)
