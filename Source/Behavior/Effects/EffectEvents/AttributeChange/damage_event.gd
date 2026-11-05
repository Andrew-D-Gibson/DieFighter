class_name DamageEvent
extends EffectEvent


var _hit_particles_scene: PackedScene = preload("uid://doi43icsr46q0")
var _explosion_particles_scene: PackedScene = preload("uid://566ykra4buin")

## A killing hit must be at least this many times what the ship had left...
const OVERKILL_FACTOR: int = 2
## ...and spill at least this much past it, so finishing off a ship on its
## last point or two with an ordinary die doesn't shout every time.
const OVERKILL_MIN_EXCESS: int = 6
## Long enough to cover the kill freeze (Enemy._KILL_HOLD_MSEC) and then
## slow the wreck's first flight.
const _OVERKILL_SLOW_MO_MS: int = 900
const _OVERKILL_SLOW_MO_SCALE: float = 0.35


## Whether this hit can reach the hull once the shields are gone. A modifier
## that only matters for hull damage (a death save) asks this rather than
## naming every kind of damage there is.
func reaches_hull() -> bool:
	return true


## Whether the target's shields take this hit before the hull does. A
## hull-stealing hit (StealHullEvent) goes straight to the hull.
func soaked_by_shields() -> bool:
	return true


## The colour of this hit's number and sparks: blue when the shields will
## take all of it, red when it reaches the hull.
func _hit_color(target: Node) -> Color:
	if soaked_by_shields() and target.health.shields >= amount:
		return Globals.blue
	return Globals.red


func resolve(_engine: ScenarioEngine) -> void:
	if targets.is_empty():
		return

	for target: Node in targets:
		if not is_instance_valid(target):
			continue

		_spawn_hit_particles(target)

		enter_combat_if_ship_hit(target)
		if actor is Player and target is Enemy:
			Events.player_attacked_ship.emit(target, target.scenario_state.faction)
		elif actor is Enemy and target is Enemy and actor != target:
			Events.ship_attacked_ship.emit(actor, target)
		if target is Enemy:
			(target as Enemy).last_damaged_by = actor
		_announce_attack_on(target)

		# Read before the hit lands: afterwards the shields it spent are gone.
		var number_color: Color = _hit_color(target)
		var hull_before: int = target.health.health
		# A hull-stealing hit skips the shields, so they don't count toward overkill.
		var shields_before: int = target.health.shields if soaked_by_shields() else 0
		if soaked_by_shields():
			target.health.take_damage(amount)
		else:
			target.health.take_hull_damage(amount)
		if not target.health.invulnerable:
			DamageNumber.spawn(target, amount, number_color, uncapped_for_popup(amount), cap_color())
		if actor is Player and target is Enemy and target.health.health <= 0 \
		and is_overkill(amount, shields_before, hull_before):
			_play_overkill(target as Enemy)
		# Player tiles author their own impact hitstop; enemy fire doesn't, so
		# a hit to the hull gets a short one here to give it weight.
		if target is Player and target.health.health < hull_before:
			TimeDirector.hitstop(45)


## Whether a killing hit of [param amount] was overkill: at least twice what
## the ship had left to give (shields and hull together), and at least
## OVERKILL_MIN_EXCESS more than it.
static func is_overkill(amount: int, shields_before: int, hull_before: int) -> bool:
	return hull_before > 0 and amount >= overkill_threshold(shields_before, hull_before)


## The smallest hit that is overkill on a ship with this much left.
static func overkill_threshold(shields_before: int, hull_before: int) -> int:
	var left: int = shields_before + hull_before
	return maxi(OVERKILL_FACTOR * left, left + OVERKILL_MIN_EXCESS)


## Overkill makes the kill bigger: a shout, a yellow blast ring under the
## kill cam's, and slow-mo that outlasts the kill freeze, so the wreck
## tumbles away slowed. The slow-mo is filed now and TimeDirector lets the
## freeze win while both run.
func _play_overkill(target: Enemy) -> void:
	Juice.callout(target, TranslationServer.translate(&"CALLOUT_OVERKILL"), Globals.yellow, true)
	TimeDirector.slow_mo(_OVERKILL_SLOW_MO_SCALE, roundi(_OVERKILL_SLOW_MO_MS / Globals.animation_speed))
	var layer: Node2D = target.graphics_manager.wreck_layer()
	Juice.ring(layer, target.global_position, Globals.yellow, 80.0, 0.7, 12.0, 0)


## Tells the world an enemy's hit was aimed at the player. Sent before the hit
## lands, so the shields that take it don't change whether it counts; anything
## answering it is queued behind the rest of the attacker's chain anyway.
func _announce_attack_on(target: Node) -> void:
	if target is Player and actor is Enemy and is_instance_valid(actor) and amount > 0:
		Events.player_attacked.emit(actor as Enemy)


## Spawn directional hit particles + an explosion at the target's position.
## Color is based on whether the damage will reach HP or be shield-absorbed.
func _spawn_hit_particles(target: Node) -> void:
	# Zero damage (fully negated) has nothing to burst, and a particle node
	# refuses an amount of zero.
	if amount <= 0:
		return
	var color: Color = _hit_color(target)

	# Directional hit burst: points from source to target.
	var hit: Node = _hit_particles_scene.instantiate()
	hit.color = color
	hit.amount = 10 * amount
	if effect_source:
		hit.rotation = (PI / 2.0) + effect_source.global_position.angle_to_point(
			target.global_position
		)
	target.add_child(hit)

	# Non-directional explosion at the target.
	var explosion: Node = _explosion_particles_scene.instantiate()
	explosion.color = color
	explosion.amount = 2 * amount
	target.add_child(explosion)
