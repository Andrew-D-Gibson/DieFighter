class_name FateSelfPresentation
extends Node2D
## How "You" looks in the Reckoning (RECKONING_ENDINGS.md §4): the canopy die
## leaving for it, the die hanging over it, its corruption, and its death.
## Pure show: the ReckoningDirector spawns and fights it, and says so through
## Events.fate_self_arrived / fate_self_destroyed; this only listens.
##
## Made by FateDieDisplay, which it borrows the bone die from. Draws in world
## space whatever its parent does (top_level).
##
##   arrival  the canopy die rattles, its chain snaps, it shatters, and the
##            shards stream out to "You" and become a small turning cube
##            (FateDieShards, then FateSelfDie);
##   fight    the cube hangs over the hull, slowing toward the face Fate will
##            throw next and tumbling onto each throw; the hull is dressed in
##            Fate's corruption (FateSelfLook);
##   death    no explosion: the slices pull the hull apart, the cube stops and
##            floats back to where the bone die hung.
##
## The canopy die comes back when the fight is over: the next scenario, the
## end of combat, or a Continue that reloads the fight.

const _SHATTER_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/glass_crack.tres")
const _SHARDS_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/glass_tinkle.tres")
const _FORMED_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/upgrade_trigger.tres")
const _FORMED_THUNK_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/die_dread_thunk.tres")

const _SHATTER_GLITCH_MS: int = 280
const _FORMED_GLITCH_MS: int = 140
## After the cube settles at the canopy, how long before a combat end that
## came during the death may put the bone die back.
const _SETTLED_HOLD_SECONDS: float = 0.4

## The bone die's display, which made this.
var display: FateDieDisplay

var _ship: Enemy
var _die: FateSelfDie
var _look: FateSelfLook
var _shards: FateDieShards
## Bumped by every reset, so a sequence still awaiting can tell it's stale.
var _run: int = 0
var _dying: bool = false
## A combat end came while the death played: reset once it has.
var _reset_after_death: bool = false


func _ready() -> void:
	top_level = true
	Events.fate_self_arrived.connect(_on_arrived)
	Events.fate_self_destroyed.connect(_on_destroyed)
	Events.fate_die_rolled.connect(_on_rolled)
	Events.load_scenario.connect(func(_scenario: ScenarioResource) -> void: _reset())
	Events.load_game_save.connect(func(_save: GameSaveResource) -> void: _reset())
	Events.combat_finished.connect(_on_combat_finished)


## The absolute z [param item] draws at, for drawing just over a node that
## lives elsewhere in the tree.
static func absolute_z(item: CanvasItem) -> int:
	var z: int = 0
	var node: Node = item
	while node is CanvasItem:
		z += (node as CanvasItem).z_index
		if not (node as CanvasItem).z_as_relative:
			break
		node = node.get_parent()
	return z


func _on_arrived(ship: Enemy) -> void:
	_reset()
	if not is_instance_valid(ship):
		return
	var run: int = _run
	_ship = ship
	_look = FateSelfLook.new()
	add_child(_look)
	_look.dress(ship)
	_die = FateSelfDie.new()
	add_child(_die)
	_die.follow(ship, _look.hull_half_height())

	if display and display.is_hanging():
		await display.break_loose()
		if run != _run:
			return
		var from: Vector2 = display.die_position()
		_shatter_at(from)
		_shards = FateDieShards.new()
		add_child(_shards)
		_shards.fly(from, display.shown_texture(), _die.hover_point)
		await _shards.gathered
		if run != _run:
			return
	_form_die()


## The bone die bursts: the one violent beat of the arrival.
func _shatter_at(point: Vector2) -> void:
	Events.glitch_burst.emit(_SHATTER_GLITCH_MS)
	Events.camera_shake_large.emit()
	Events.play_sound.emit(_SHATTER_SFX)
	Events.play_sound.emit(_SHARDS_SFX)
	Juice.ring(self, point, Globals.purple, 16.0, 0.4, 3.0)
	Juice.sparkle(self, point, FateDieArt.BONE, 10, 45.0)


## The shards are in: the cube is there.
func _form_die() -> void:
	if not is_instance_valid(_die):
		return
	_die.appear()
	var point: Vector2 = _die.hover_point()
	Events.glitch_burst.emit(_FORMED_GLITCH_MS)
	Events.camera_shake_small.emit()
	Events.play_sound.emit(_FORMED_SFX)
	Events.play_sound.emit(_FORMED_THUNK_SFX)
	Juice.ring(self, point, Globals.purple, 20.0, 0.45, 4.0)
	Juice.glint(self, point, Globals.white, 7.0, 0.4)


func _on_rolled(slot: int, face: int) -> void:
	if is_instance_valid(_die) and not _dying:
		_die.throw(slot, face as FateDie.Face)


func _on_destroyed(ship: Enemy) -> void:
	if _dying or not is_instance_valid(_die):
		return
	if is_instance_valid(_ship) and ship != _ship:
		return
	_dying = true
	var run: int = _run
	if is_instance_valid(_shards):
		# Killed before the shards were in (a dev shortcut): skip to the cube.
		_shards.queue_free()
		_die.appear()
	if is_instance_valid(_look):
		_look.dismantle()
	var rest: Vector2 = display.rest_position() if display else _die.hover_point()
	var rest_z: int = absolute_z(display) + 1 if display else _die.z_index
	await _die.release_to(rest, rest_z)
	if run != _run:
		return
	await get_tree().create_timer(_SETTLED_HOLD_SECONDS).timeout
	if run != _run:
		return
	_dying = false
	if _reset_after_death:
		_reset()


func _on_combat_finished() -> void:
	if _dying:
		_reset_after_death = true
		return
	_reset()


## Everything of "You"'s gone, and the bone die back on its chain.
func _reset() -> void:
	_run += 1
	_dying = false
	_reset_after_death = false
	_ship = null
	# Untyped: the shards free themselves once in, and a freed node can't be
	# held as a Node.
	for node: Variant in [_die, _look, _shards]:
		if is_instance_valid(node):
			(node as Node).queue_free()
	_die = null
	_look = null
	_shards = null
	if display:
		display.restore()
