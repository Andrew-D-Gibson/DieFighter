class_name DebugLogFormat
extends RefCounted
## Turns game objects and resolved engine events into one-line text for
## DebugLogger.
##
## Kept apart from the logger so the wording lives in one place and can be
## read (or tested) without the signal wiring around it. Everything here is
## read-only: a log line must never change what it's describing.

## Event folders whose events are pure presentation (tweens, shakes, sounds).
## Matching on the folder rather than listing classes means a new juice event
## stays out of the log without anyone remembering to add it here.
const _SKIPPED_EVENT_FOLDERS: Array[String] = ["/AudioVisual/", "/Debug/"]

## Bookkeeping events that resolve after every activation and carry nothing a
## reader of the log needs.
const _SKIPPED_EVENT_CLASSES: Array[StringName] = [&"TileActivationCompleteEvent"]

static var _bbcode_tag: RegEx = RegEx.create_from_string("\\[/?[^\\]]*\\]")


## A short, stable name for anything that shows up as an actor, source or
## target.
static func label(node: Node) -> String:
	if not is_instance_valid(node):
		return "-"
	if node is Player:
		return "Player"
	if node is Enemy:
		var enemy: Enemy = node as Enemy
		var enemy_name: String = enemy.enemy_resource.enemy_name if enemy.enemy_resource else String(enemy.name)
		# Two Raiders in one fight are otherwise indistinguishable.
		return "%s#%d" % [enemy_name, enemy.spawn_index] if enemy.spawn_index >= 0 else enemy_name
	if node is Tile:
		var tile: Tile = node as Tile
		# Tile names carry BBCode colour tags for the info panel.
		var tile_name: String = _bbcode_tag.sub(tile.tile_resource.tile_name, "", true) if tile.tile_resource else String(tile.name)
		return "[%s]" % tile_name
	if node is Dice:
		return die(node as Dice)
	return String(node.name)


static func die(dice: Dice) -> String:
	if not is_instance_valid(dice):
		return "d?"
	return "%sd%d" % ["holo-" if dice.holographic else "", dice.value]


static func dice_values(dice: Array[Dice]) -> String:
	var parts: PackedStringArray = []
	for d: Dice in dice:
		if is_instance_valid(d):
			parts.append(str(d.value) + ("h" if d.holographic else ""))
	return "[%s]" % ", ".join(parts)


static func labels(nodes: Array[Node]) -> String:
	var parts: PackedStringArray = []
	for node: Node in nodes:
		parts.append(label(node))
	return ", ".join(parts)


## Hull and shields, plus anything else that ship is carrying.
static func vitals(node: Node) -> String:
	if not is_instance_valid(node) or not "health" in node or node.health == null:
		return ""
	var health: Health = node.health
	var text: String = "hull %d/%d, shields %d" % [health.health, health.max_health, health.shields]
	if health.invulnerable:
		text += ", invulnerable"
	return text


static func player_summary(player: Player) -> String:
	if not is_instance_valid(player):
		return "Player: -"
	return "Player: %s, charge %d/%d, money %d" % [
		vitals(player), player.engine_charge, player.max_engine_charge, player.money
	]


static func statuses(host: Node, engine: ScenarioEngine) -> String:
	if engine == null:
		return ""
	var parts: PackedStringArray = []
	for status: StatusModifier in engine.statuses_on(host):
		parts.append("%s x%d" % [status.display_name, status.stacks])
	return ", ".join(parts)


static func modifier(mod: Modifier) -> String:
	if mod == null:
		return "-"
	var mod_name: String = mod.modifier_name
	if mod is StatusModifier:
		mod_name = "%s x%d" % [(mod as StatusModifier).display_name, (mod as StatusModifier).stacks]
	elif mod_name == "Unnamed Modifier":
		mod_name = _class_name(mod)
	if is_instance_valid(mod.affected_node):
		mod_name += " on %s" % label(mod.affected_node)
	if is_instance_valid(mod.source) and mod.source != mod.affected_node:
		mod_name += " from %s" % label(mod.source)
	return mod_name


## An enemy action's display name. Do Nothing is authored without one on
## purpose (the targeting computer reads a blank name as "no intent here").
static func action_name(action: EnemyActionResource) -> String:
	if action == null:
		return "(none)"
	if action.name != "":
		return action.name
	return "(%s)" % action.resource_path.get_file().get_basename() if action.resource_path != "" else "(no action)"


## The six-face intent table, e.g. "1:Dice Cannon(3) 2:Shield Burst(2) ...".
static func intent_table(enemy: Enemy) -> String:
	var parts: PackedStringArray = []
	for i: int in enemy.turn_actions.size():
		var action: EnemyActionResource = enemy.turn_actions[i]
		var text: String = "%d:%s" % [i + 1, action_name(action)]
		if action:
			if action.intent_amount != 0:
				text += "(%d)" % action.intent_amount
			if is_instance_valid(action.bound_target):
				text += "->%s" % label(action.bound_target)
		parts.append(text)
	return " ".join(parts)


static func enemy_summary(enemy: Enemy, engine: ScenarioEngine) -> String:
	var text: String = "%s: %s" % [label(enemy), vitals(enemy)]
	if enemy.scenario_state:
		text += ", %s" % ScenarioManager.Faction.keys()[enemy.scenario_state.faction]
	var status_text: String = statuses(enemy, engine)
	if status_text != "":
		text += ", statuses: %s" % status_text
	if enemy.overload_threshold > 0:
		text += ", heat %d/%d" % [enemy.held_heat(), enemy.overload_threshold]
	return text


static func should_log(event: EffectEvent) -> bool:
	var script: Script = event.get_script()
	if script == null:
		return false
	if script.get_global_name() in _SKIPPED_EVENT_CLASSES:
		return false
	for folder: String in _SKIPPED_EVENT_FOLDERS:
		if script.resource_path.contains(folder):
			return false
	return true


## One line for a resolved event. Read after it resolved, so vitals show the
## result of a hit rather than the state before it.
static func event_line(e: EffectEvent) -> String:
	if e is TileActivationEvent:
		var activation: TileActivationEvent = e as TileActivationEvent
		return "%s activated by d%d%s%s" % [
			label(activation.tile), activation.die_value,
			_repetitions(activation.activation_repetitions),
			_uses(activation.tile),
		]
	if e is EnemyActionEvent:
		var action_event: EnemyActionEvent = e as EnemyActionEvent
		var action: EnemyActionResource = action_event.action
		var text: String = "%s spends d%d -> %s" % [
			label(action_event.enemy), action_event.die_value, action_name(action)
		]
		if action and action.intent_amount != 0:
			text += " (intent %d)" % action.intent_amount
		if action and is_instance_valid(action.bound_target):
			text += " bound to %s" % label(action.bound_target)
		return text + _repetitions(action_event.activation_repetitions)
	if e is DamageEvent:
		return "  DAMAGE %d %s -> %s" % [e.amount, _origin(e), _targets_with_vitals(e.targets)]
	if e is ShieldEvent:
		return "  SHIELD +%d %s -> %s" % [e.amount, _origin(e), _targets_with_vitals(e.targets)]
	if e is HealEvent:
		return "  HEAL +%d %s -> %s" % [e.amount, _origin(e), _targets_with_vitals(e.targets)]
	if e is ApplyStatusEvent:
		return "  STATUS +%d %s %s -> %s" % [
			e.amount, (e as ApplyStatusEvent).status_id, _origin(e), labels(e.targets)
		]
	if e is ClearStatusEvent:
		return "  STATUS cleared %s %s -> %s" % [
			(e as ClearStatusEvent).status_id, _origin(e), labels(e.targets)
		]
	if e is ChangeEngineChargeEvent or e is SpendEngineChargeEvent:
		var charge: int = Globals.player.engine_charge if is_instance_valid(Globals.player) else 0
		return "  CHARGE %+d %s (now %d)" % [
			e.amount if e is ChangeEngineChargeEvent else -e.amount, _origin(e), charge
		]
	if e is HazardEvent:
		return "  Hazard chain resolves"
	return "  %s%s" % [_short_class_name(e), _generic_details(e)]


static func _origin(e: EffectEvent) -> String:
	var source: String = label(e.effect_source)
	var actor: String = label(e.actor)
	if source == actor or not is_instance_valid(e.effect_source):
		return "by %s" % actor
	return "from %s (%s)" % [source, actor]


static func _targets_with_vitals(targets: Array[Node]) -> String:
	var parts: PackedStringArray = []
	for target: Node in targets:
		var vitals_text: String = vitals(target)
		parts.append("%s [%s]" % [label(target), vitals_text] if vitals_text != "" else label(target))
	return ", ".join(parts) if not parts.is_empty() else "(no targets)"


static func _repetitions(count: int) -> String:
	return " x%d" % count if count > 1 else ""


static func _uses(tile: Tile) -> String:
	if not is_instance_valid(tile) or tile.uses_remaining < 0:
		return ""
	return ", %d use(s) left" % tile.uses_remaining


## Whatever an event happens to carry, for the many events that don't need a
## bespoke line. New events get logged usefully without touching this file.
static func _generic_details(e: EffectEvent) -> String:
	var parts: PackedStringArray = []
	if e.amount != 0:
		parts.append("amount %d" % e.amount)
	if is_instance_valid(e.activator_die):
		var now: int = (e.activator_die as Dice).value
		parts.append("d%d" % e.die_value if now == e.die_value or e.die_value == 0 else "d%d->d%d" % [e.die_value, now])
	if is_instance_valid(e.actor):
		parts.append(_origin(e))
	if not e.targets.is_empty():
		parts.append("-> %s" % labels(e.targets))
	return (" " + " ".join(parts)) if not parts.is_empty() else ""


static func _class_name(object: Object) -> String:
	var script: Script = object.get_script()
	if script and script.get_global_name() != &"":
		return String(script.get_global_name())
	return object.get_class()


static func _short_class_name(e: EffectEvent) -> String:
	return _class_name(e).trim_suffix("Event")
