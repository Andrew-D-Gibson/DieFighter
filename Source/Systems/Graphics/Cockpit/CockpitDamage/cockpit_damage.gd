class_name CockpitDamage
extends Node2D
## Shows the player's hull on the cockpit itself: the canopy cracks and the
## frame splits open as hull drops, and mends as it comes back.
##
## Each child CockpitDamageSite is one break. They open in child order, evenly
## spread over the hull below [member intact_from], so the first real dent
## below a fresh run's hull cracks the glass and the cockpit is coming apart
## by the last few points. The same ordering runs
## backwards when healing, so a repair closes the most recent damage first.

## Gap between breaks popping open (or shut) when one change crosses several
## thresholds, so a big swing reads as a cascade rather than a jump cut.
@export var stagger: float = 0.07

## Hull (fraction of max) at and above which the cockpit shows no damage. A
## run starts short of max hull (run_start.tres), and opening on a cracked,
## smoking canopy reads as already losing; keep this at or below that start.
@export_range(0.0, 1.0) var intact_from: float = 0.75

@export_group("Smoke")
## A hull hit at least this big (as a fraction of max hull) billows smoke out
## of the open breaks. Anything smaller just chips.
@export_range(0.0, 1.0) var big_hit_fraction: float = 0.1
## A hit this big (fraction of max hull) or bigger billows as hard as a hit can.
@export_range(0.0, 1.0) var huge_hit_fraction: float = 0.25
## How much of a plume's size comes from the hit itself; the rest comes from
## how little hull is left, so the same hit plumes harder near the end.
@export_range(0.0, 1.0) var hit_share: float = 0.4
## Hull lost (fraction of max) where the dire part of the smoke starts
## building. Above it, only the size of the hit matters.
@export_range(0.0, 1.0) var dire_from: float = 0.5

@export_group("Cracks")
## Seconds a new crack stays at full strength before it starts to fade.
@export var crack_hold_time: float = 2.0
## Seconds it takes to fade from full strength to its ghost.
@export var crack_fade_time: float = 6.0
## What's left of a faded crack: the canopy remembers every hit.
@export_range(0.0, 1.0) var crack_ghost_alpha: float = 0.1

var _sites: Array[CockpitDamageSite] = []
var _health: Health = null
var _last_health: int = -1
## Set by a hit or a heal, read by the deferred sync it triggers. A change
## with neither (a save loading, a new run) snaps the cockpit to match.
var _animate_next_sync: bool = false
var _sync_queued: bool = false
var _sync_generation: int = 0

@onready var glass_shards: CockpitGlassShards = $GlassShards


func _ready() -> void:
	for child: Node in get_children():
		if child is CockpitDamageSite:
			_sites.append(child)
	glass_shards.set_walls(get_walls())
	# The player is spawned under Systems, after Graphics, so its Health isn't
	# ready yet.
	_bind_to_player.call_deferred()


func _bind_to_player() -> void:
	if not Globals.player or not Globals.player.health:
		return
	_health = Globals.player.health
	_last_health = _health.health
	_health.health_set.connect(_queue_sync)
	_health.health_damaged.connect(_on_hull_changed)
	_health.health_healed.connect(_on_hull_changed)
	_sync(false)


## Breaks that should be showing at [param health] out of [param max_health].
## Site i of n opens once hull falls to (n - i) / (n + 1) of the
## [param intact] line, so hull on or above it shows nothing and only zero
## shows everything.
static func sites_open_at(health: int, max_health: int, site_count: int, intact: float = 1.0) -> int:
	if max_health <= 0 or intact <= 0.0 or float(health) >= max_health * intact:
		return 0
	if health <= 0:
		return site_count
	var worn: float = 1.0 - float(health) / (max_health * intact)
	return clampi(floori(worn * (site_count + 1)), 0, site_count)


## How hard a hit of [param lost] hull billows, 0 to 1, given [param health]
## left of [param max_health]. Grows smoothly with the size of the hit, and
## gets an extra push as the hull runs out.
func billow_intensity(lost: int, health: int, max_health: int) -> float:
	if max_health <= 0:
		return 1.0
	var hit: float = inverse_lerp(big_hit_fraction, huge_hit_fraction, float(lost) / max_health)
	return clampf(clampf(hit, 0.0, 1.0) * hit_share
			+ dire_at(health, max_health) * (1.0 - hit_share), 0.0, 1.0)


## How dire the hull is, 0 to 1: nothing until [member dire_from] of it is
## gone, then building to 1 at zero.
func dire_at(health: int, max_health: int) -> float:
	if max_health <= 0:
		return 1.0
	return smoothstep(dire_from, 1.0, 1.0 - float(health) / max_health)


func _on_hull_changed() -> void:
	_animate_next_sync = true
	_queue_sync()


## Health emits health_set before it says why (damaged or healed), so the
## sync waits a frame to know whether to animate.
func _queue_sync() -> void:
	if _sync_queued:
		return
	_sync_queued = true
	_sync.call_deferred(true)


func _sync(from_queue: bool) -> void:
	if from_queue:
		_sync_queued = false
	if not is_instance_valid(_health):
		return
	var animate: bool = _animate_next_sync
	_animate_next_sync = false

	var health: int = _health.health
	var lost: int = _last_health - health
	_last_health = health

	var dire: float = dire_at(health, _health.max_health)
	for site: CockpitDamageSite in _sites:
		site.set_linger_intensity(dire)

	var want: int = sites_open_at(health, _health.max_health, _sites.size(), intact_from)
	var opening: Array[CockpitDamageSite] = []
	var closing: Array[CockpitDamageSite] = []
	for i: int in _sites.size():
		var site: CockpitDamageSite = _sites[i]
		if i < want and not site.is_open:
			opening.append(site)
		elif i >= want and site.is_open:
			closing.append(site)
	closing.reverse()

	_sync_generation += 1
	if not animate:
		for site: CockpitDamageSite in opening:
			site.open(false)
		for site: CockpitDamageSite in closing:
			site.close(false)
		return

	if lost >= maxi(2, ceili(_health.max_health * big_hit_fraction)):
		_billow(opening, billow_intensity(lost, health, _health.max_health))
	# The killing blow's cracks are held back as ghosts: the destruction brings
	# every crack back one at a time as the cockpit gives way.
	if health <= 0:
		for site: CockpitDamageSite in opening.duplicate():
			if site.kind == CockpitDamageSite.Kind.GLASS:
				site.open(false)
				opening.erase(site)
	_cascade(opening, true, _sync_generation)
	_cascade(closing, false, _sync_generation)


## Opens or closes [param sites] one after another. A newer sync supersedes an
## older cascade still in progress, so a hit landing mid-repair can't have the
## two fight over the same break.
func _cascade(sites: Array[CockpitDamageSite], open: bool, generation: int) -> void:
	for i: int in sites.size():
		if i > 0:
			await get_tree().create_timer(stagger).timeout
			if generation != _sync_generation:
				return
		if open:
			sites[i].open(true)
		else:
			sites[i].close(true)


## The new breaks plume first; failing those (a hit that opened nothing new),
## whatever's already torn open.
func _billow(newly_opened: Array[CockpitDamageSite], intensity: float) -> void:
	var sources: Array[CockpitDamageSite] = []
	for site: CockpitDamageSite in newly_opened:
		if site.kind == CockpitDamageSite.Kind.FRAME:
			sources.append(site)
	if sources.is_empty():
		for site: CockpitDamageSite in _sites:
			if site.is_open and site.kind == CockpitDamageSite.Kind.FRAME:
				sources.append(site)
	sources.shuffle()
	for site: CockpitDamageSite in sources.slice(0, 2):
		# Opening sites aren't open yet; they plume as the cascade reaches them.
		if site.is_open:
			site.billow(intensity)
		else:
			_billow_when_open(site, intensity)


func _billow_when_open(site: CockpitDamageSite, intensity: float) -> void:
	for _i: int in 30:
		await get_tree().process_frame
		if site.is_open:
			site.billow(intensity)
			return


## Every break on the cockpit, open or not, for the destruction to burst out of.
func get_sites() -> Array[CockpitDamageSite]:
	return _sites


## The cockpit shell sprite, a sibling of the ambience in the Graphics layer:
## what glass lands on, and what the destruction breaks apart.
func get_walls() -> Sprite2D:
	var ambience: Node = get_parent()
	if not ambience or not ambience.get_parent():
		return null
	return ambience.get_parent().get_node_or_null("Cockpit Walls") as Sprite2D
