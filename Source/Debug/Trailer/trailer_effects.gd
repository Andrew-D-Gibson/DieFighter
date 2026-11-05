class_name TrailerEffects
extends RefCounted
## Set pieces on demand, for B-roll: a trailer hotkey, `fx <name>` in the dev
## console, or an `fx` beat in a shot. Each one goes through the same events
## the game plays (a DamageEvent through the scenario engine, the hazard's
## own chain), so it looks and sounds exactly as it would in a run.
##
## play() answers "" when it worked, or why it couldn't.

## Name -> what it does, for `fx` with no name and the hotkey legend.
const CATALOG: Dictionary[String, String] = {
	"overkill": "kill the targeted ship with an overkill hit",
	"kill": "kill the targeted ship with an exact hit",
	"hit": "hit the player for [n] (default 5)",
	"shield_break": "the player gains shields, then a hit breaks them",
	"critical": "hit the player down to critical hull",
	"hazard": "the region's hazard strikes now (needs a hazard sky, in a fight)",
	"jump": "jump one place forward on the map",
	"death": "the player is destroyed (god mode off)",
	"red_alert": "pulse the red alert for [seconds] (default 2)",
	"glitch": "burst the glitch overlay for [ms] (default 400)",
	"shake": "a large camera shake",
	"reroll": "reroll the hand, die by die",
	"boss_card": "replay the boss intro card (boss scenarios only)",
}

## What `critical` leaves the hull at, as a share of max: inside HullAlarm's
## band.
const _CRITICAL_SHARE: float = 0.2
const _SHIELD_BREAK_SHIELDS: int = 4


static func play(effect: String, arg: String = "") -> String:
	if not is_instance_valid(Globals.player) or not Globals.player.is_inside_tree():
		return "no game running"
	match effect:
		"overkill":
			return _kill_target(true)
		"kill":
			return _kill_target(false)
		"hit":
			return _hit_player(int(arg) if arg.is_valid_int() else 5)
		"shield_break":
			return _shield_break()
		"critical":
			var health: Health = Globals.player.health
			var floor_hull: int = maxi(1, floori(health.max_health * _CRITICAL_SHARE))
			if health.health <= floor_hull:
				return "hull is already at or below %d" % floor_hull
			return _hit_player(health.shields + health.health - floor_hull)
		"hazard":
			var hazards: HazardManager = Globals.player.get_tree().get_first_node_in_group(HazardManager.GROUP) as HazardManager
			if hazards == null or not hazards.fire_now():
				return "no hazard to fire: give the shot a hazard sky, and be in a fight"
			return ""
		"jump":
			return _jump()
		"death":
			# For good: the run ends here.
			Globals.player.health.invulnerable = false
			return _hit_player(Globals.player.health.shields + Globals.player.health.health + 1)
		"red_alert":
			Events.red_alert.emit(float(arg) if arg.is_valid_float() else 2.0)
			return ""
		"glitch":
			Events.glitch_burst.emit(int(arg) if arg.is_valid_int() else 400)
			return ""
		"shake":
			Events.camera_shake_large.emit(false)
			return ""
		"reroll":
			Globals.player.reroll_dice()
			return ""
		"boss_card":
			return _boss_card()
	return "no effect '%s' (try: %s)" % [effect, ", ".join(PackedStringArray(CATALOG.keys()))]


## The ship the targeting computer is on, or the first one alive.
static func target() -> Enemy:
	if Globals.targeting_computer and is_instance_valid(Globals.targeting_computer.targeted_enemy) \
	and not Globals.targeting_computer.targeted_enemy.health.is_dead:
		return Globals.targeting_computer.targeted_enemy
	if is_instance_valid(Globals.enemy_manager):
		for ship: Enemy in Globals.enemy_manager.get_alive_enemies():
			return ship
	return null


static func _kill_target(overkill: bool) -> String:
	var engine: ScenarioEngine = ScenarioEngine.current()
	var ship: Enemy = target()
	if engine == null or ship == null:
		return "no ship to kill"
	var left: int = ship.health.shields + ship.health.health
	var damage: DamageEvent = DamageEvent.new()
	damage.actor = Globals.player
	damage.effect_source = _firing_tile()
	damage.targets = [ship]
	damage.amount = DamageEvent.overkill_threshold(ship.health.shields, ship.health.health) if overkill else left
	engine.queue_event(damage)
	return ""


## A hit with no attacker, so nothing aboard answers it as an attack. It
## lands through a shot's god mode: a staged hit is the point.
static func _hit_player(amount: int) -> String:
	var engine: ScenarioEngine = ScenarioEngine.current()
	if engine == null:
		return "no scenario running"
	var damage: DamageEvent = _StagedHit.new()
	damage.targets = [Globals.player]
	damage.amount = amount
	engine.queue_event(damage)
	return ""


static func _shield_break() -> String:
	var engine: ScenarioEngine = ScenarioEngine.current()
	if engine == null:
		return "no scenario running"
	var health: Health = Globals.player.health
	var shields: int = health.shields
	if shields == 0:
		var gain: ShieldEvent = ShieldEvent.new()
		gain.targets = [Globals.player]
		gain.amount = _SHIELD_BREAK_SHIELDS
		engine.queue_event(gain)
		shields = _SHIELD_BREAK_SHIELDS
	# Exactly the shields: the break, without a hull hit muddying it.
	return _hit_player(shields)


static func _jump() -> String:
	if not is_instance_valid(Globals.map):
		return "no map to jump on"
	var to: int = Globals.map.current_scenario_index + 1
	var at_gate: bool = Globals.map.current_scenario_index == len(Globals.map.scenario_list) - 1
	if at_gate and not (Globals.jump_gate and Globals.jump_gate.is_open()):
		return "the gate is locked (charge the engine first)"
	if not at_gate and not Globals.map.is_valid_destination(to):
		return "can't jump forward from here"
	var jump: JumpEvent = JumpEvent.new()
	jump.jump_delta = 1
	jump.resolve(ScenarioEngine.current())
	return ""


static func _boss_card() -> String:
	var scenario: ScenarioResource = Globals.scenario_manager.current_scenario \
		if is_instance_valid(Globals.scenario_manager) else null
	if scenario == null or scenario.boss_title.is_empty():
		return "this scenario has no boss card"
	var card: Node = Globals.player.get_tree().root.find_child("BossIntroCard", true, false)
	if card == null:
		return "no boss card in this scene"
	card.call(&"play", scenario)
	return ""


## A DamageEvent that god mode doesn't stop: invulnerability is lifted for
## the length of the hit and put back. Resolved by the engine like any hit,
## so the shields, hull, popups and alarms all answer it as usual.
class _StagedHit extends DamageEvent:
	func resolve(engine: ScenarioEngine) -> void:
		var was_invulnerable: Dictionary[Node, bool] = {}
		for target: Node in targets:
			if is_instance_valid(target):
				was_invulnerable[target] = target.health.invulnerable
				target.health.invulnerable = false
		super.resolve(engine)
		for target: Node in was_invulnerable:
			if is_instance_valid(target):
				target.health.invulnerable = was_invulnerable[target]


## Where a trailer's kill shot comes from: a tile, so the hit particles fly
## the right way.
static func _firing_tile() -> Node2D:
	if is_instance_valid(Globals.tile_grid) and not Globals.tile_grid.tile_locations.is_empty():
		return Globals.tile_grid.tile_locations.values()[0]
	return Globals.player
