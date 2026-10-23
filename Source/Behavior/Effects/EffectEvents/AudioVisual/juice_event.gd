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
## EffectData.juice_flags: a bitmask of Flag.
var flags: int = 0

## The bits of EffectData.juice_flags, in the order its inspector lists them.
enum Flag {
	RISE = 1,    ## SPARK_BURST: sparks drift upward, for gains rather than hits
	OUTWARD = 2, ## STREAM: flow out of the source rather than into it
	ENGINE = 4,  ## STREAM and CALLOUT: the player's end is their engine charge
	## STREAM: the player's health bar stands in for the effect source, so
	## a drain lands in the hull it heals (Leeching Shot) rather than the tile.
	HULL_HUB = 8,
	## STREAM: the player's engine charge stands in for the effect source,
	## for charge that's spent at a target (Overdraw Coil).
	ENGINE_HUB = 16,
}

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
						40.0 * multiplier, _has(Flag.RISE))
		EffectEnums.AudioVisualSubtype.CALLOUT:
			for node: Node2D in anchors:
				Juice.callout_at(node, _anchor_for(node), text, color)
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
		EffectEnums.AudioVisualSubtype.LASER:
			await _shoot(anchors, JuiceProjectile.Style.LASER)
		EffectEnums.AudioVisualSubtype.MISSILE:
			await _shoot(anchors, JuiceProjectile.Style.MISSILE)


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


## A shot from the source at each target that isn't a die: the source keeps
## its die, or passes it on. Held until it lands, for the same reason as the
## bolt.
func _shoot(anchors: Array[Node2D], style: JuiceProjectile.Style) -> void:
	var from: Node2D = effect_source as Node2D
	if not is_instance_valid(from):
		return
	var seconds: float = 0.0
	for node: Node2D in anchors:
		if node != from:
			seconds = maxf(seconds, Juice.projectile(from, Juice.anchor_of(from),
					Juice.anchor_of(node), color, style, amount / 1000.0, node))
	if seconds > 0.0:
		await from.get_tree().create_timer(seconds).timeout


## Motes flow from each target into the hub (a drain), or out of it with
## OUTWARD. The hub is the effect source, unless HULL_HUB or ENGINE_HUB put
## it on the player. With ENGINE, a player target's end is their engine
## charge rather than their health bar. Held until they arrive, for the same
## reason as the bolt.
func _stream(anchors: Array[Node2D]) -> void:
	var source: Node2D = effect_source as Node2D
	if not is_instance_valid(source):
		return
	var hub_end: Vector2 = _hub_end(source)
	var count: int = amount if amount > 0 else _DEFAULT_STREAM_MOTES
	var seconds: float = 0.0
	for node: Node2D in anchors:
		var start: Vector2 = _anchor_for(node)
		var end: Vector2 = hub_end
		# A target that is the hub has nowhere to flow to.
		if start.is_equal_approx(end):
			continue
		if _has(Flag.OUTWARD):
			var swap: Vector2 = start
			start = end
			end = swap
		seconds = maxf(seconds, Juice.stream(source, start, end, color, count))
	if seconds > 0.0:
		await source.get_tree().create_timer(seconds).timeout


func _hub_end(source: Node2D) -> Vector2:
	var player: Node2D = Globals.player as Node2D
	if is_instance_valid(player):
		if _has(Flag.ENGINE_HUB):
			return Juice.engine_anchor(player)
		if _has(Flag.HULL_HUB):
			return Juice.anchor_of(player)
	return _anchor_for(source)


## Where on [param node] a stream or callout lands: its usual anchor, or the
## engine gauge for the player when ENGINE is set.
func _anchor_for(node: Node2D) -> Vector2:
	if node is Player and _has(Flag.ENGINE):
		return Juice.engine_anchor(node)
	return Juice.anchor_of(node)


func _has(flag: Flag) -> bool:
	return (flags & flag) != 0


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
