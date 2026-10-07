class_name JuiceEvent
extends EffectEvent
## Draws one authored flourish. See EffectEnums.AudioVisualSubtype from
## SHOCKWAVE onwards for what each kind does, and JuiceHandler for where the
## parameters come from.
##
## Plays at every target, or at the effect source when there are none, so a
## flourish authored before any targeting lands on the tile or ship itself.

## An EffectEnums.AudioVisualSubtype value.
var kind: int
var multiplier: float = 1.0
var color: Color = Color.WHITE
var text: String = ""

const _DEFAULT_SHOCKWAVE_RADIUS: int = 20
const _DEFAULT_SPARK_COUNT: int = 10
const _DEFAULT_ZAP_MSEC: int = 140
const _DEFAULT_RIPPLE_STEP_MSEC: int = 60
const _DEFAULT_STREAM_MOTES: int = 10
const _BUMP_STRENGTH: float = 0.25


## Sizes, counts and durations, not outputs: an Amplifier leaves them alone.
func is_amplifiable() -> bool:
	return false


func resolve(_engine: ScenarioEngine) -> void:
	var anchors: Array[Node2D] = _anchors()
	if anchors.is_empty():
		return

	match kind:
		EffectEnums.AudioVisualSubtype.SHOCKWAVE:
			var radius: int = amount if amount != 0 else _DEFAULT_SHOCKWAVE_RADIUS
			for node: Node2D in anchors:
				if radius > 0:
					Juice.ring(node, Juice.anchor_of(node), color, radius, 0.4, 3.0)
				else:
					Juice.ring(node, Juice.anchor_of(node), color, 3.0, 0.35, -radius)
		EffectEnums.AudioVisualSubtype.SPARK_BURST:
			var count: int = amount if amount > 0 else _DEFAULT_SPARK_COUNT
			for node: Node2D in anchors:
				Juice.sparkle(node, Juice.anchor_of(node), color, count,
						40.0 * multiplier, text == "rise")
		EffectEnums.AudioVisualSubtype.CALLOUT:
			for node: Node2D in anchors:
				Juice.callout_at(node, Juice.anchor_of(node), text, color)
		EffectEnums.AudioVisualSubtype.BUMP:
			for node: Node2D in anchors:
				Juice.bump(Juice.body_of(node), _BUMP_STRENGTH * multiplier, 0.3)
		EffectEnums.AudioVisualSubtype.ZAP:
			await _zap(anchors)
		EffectEnums.AudioVisualSubtype.GRID_RIPPLE:
			Juice.grid_ripple(_origin_tile(anchors), color,
					amount if amount > 0 else _DEFAULT_RIPPLE_STEP_MSEC)
		EffectEnums.AudioVisualSubtype.SCREEN_RIPPLE:
			Juice.screen_ripple(anchors[0], Juice.anchor_of(anchors[0]), multiplier)
		EffectEnums.AudioVisualSubtype.STREAM:
			await _stream(anchors)
		EffectEnums.AudioVisualSubtype.DIE_FLARE:
			if is_instance_valid(activator_die) and activator_die is Dice:
				Juice.die_flare(activator_die as Dice, color)


## The bolt holds the chain for its length, so whatever comes next (the
## damage, the Feed) lands as it strikes.
func _zap(anchors: Array[Node2D]) -> void:
	var from: Node2D = effect_source as Node2D
	if not is_instance_valid(from):
		return
	var msec: int = amount if amount > 0 else _DEFAULT_ZAP_MSEC
	for node: Node2D in anchors:
		if node != from:
			Juice.zap(from, Juice.anchor_of(from), Juice.anchor_of(node), color, msec)
	await from.get_tree().create_timer(msec / 1000.0).timeout


## Motes flow from each target into the source (a drain), or out of it when
## text contains "out". With "engine" in it, the player's end is their engine
## charge rather than their health bar. Held until they arrive, for the same
## reason as the bolt.
func _stream(anchors: Array[Node2D]) -> void:
	var hub: Node2D = effect_source as Node2D
	if not is_instance_valid(hub):
		return
	var count: int = amount if amount > 0 else _DEFAULT_STREAM_MOTES
	var seconds: float = 0.0
	for node: Node2D in anchors:
		if node == hub:
			continue
		var start: Vector2 = _stream_end(node)
		var end: Vector2 = _stream_end(hub)
		if text.contains("out"):
			var swap: Vector2 = start
			start = end
			end = swap
		seconds = maxf(seconds, Juice.stream(hub, start, end, color, count))
	if seconds > 0.0:
		await hub.get_tree().create_timer(seconds).timeout


func _stream_end(node: Node2D) -> Vector2:
	if node is Player and text.contains("engine"):
		return Juice.engine_anchor(node)
	return Juice.anchor_of(node)


func _anchors() -> Array[Node2D]:
	var result: Array[Node2D] = []
	for target: Node in targets:
		if is_instance_valid(target) and target is Node2D and target.is_inside_tree():
			result.append(target as Node2D)
	if result.is_empty() and is_instance_valid(effect_source) \
			and effect_source is Node2D and effect_source.is_inside_tree():
		result.append(effect_source as Node2D)
	return result


## Where a grid ripple starts: the first tile among the anchors, else the
## source tile, else nowhere (Juice.grid_ripple then starts from the middle).
func _origin_tile(anchors: Array[Node2D]) -> Tile:
	for node: Node2D in anchors:
		if node is Tile:
			return node as Tile
	return effect_source as Tile if effect_source is Tile else null
