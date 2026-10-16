class_name CockpitDamage
extends Node2D
## Shows the player's hull on the cockpit itself: the canopy cracks and the
## frame splits open as hull drops, and mends as it comes back.
##
## Each child CockpitDamageSite is one break. They open in child order, evenly
## spread over the hull bar, so the first chip of damage cracks the glass and
## the cockpit is coming apart by the last few points. The same ordering runs
## backwards when healing, so a repair closes the most recent damage first.

## A hull hit at least this big (as a fraction of max hull) billows smoke out
## of the open breaks. Anything smaller just chips.
@export_range(0.0, 1.0) var big_hit_fraction: float = 0.15
## Gap between breaks popping open (or shut) when one change crosses several
## thresholds, so a big swing reads as a cascade rather than a jump cut.
@export var stagger: float = 0.07

var _sites: Array[CockpitDamageSite] = []
var _health: Health = null
var _last_health: int = -1
## Set by a hit or a heal, read by the deferred sync it triggers. A change
## with neither (a save loading, a new run) snaps the cockpit to match.
var _animate_next_sync: bool = false
var _sync_queued: bool = false
var _sync_generation: int = 0


func _ready() -> void:
	for child: Node in get_children():
		if child is CockpitDamageSite:
			_sites.append(child)
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
## Site i of n opens once hull falls to (n - i) / (n + 1) of max, so a full
## hull shows nothing and only zero shows everything.
static func sites_open_at(health: int, max_health: int, site_count: int) -> int:
	if max_health <= 0 or health >= max_health:
		return 0
	if health <= 0:
		return site_count
	var lost: float = 1.0 - float(health) / max_health
	return clampi(floori(lost * (site_count + 1)), 0, site_count)


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

	var want: int = sites_open_at(health, _health.max_health, _sites.size())
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
		_billow(opening)
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
func _billow(newly_opened: Array[CockpitDamageSite]) -> void:
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
			site.billow()
		else:
			_billow_when_open(site)


func _billow_when_open(site: CockpitDamageSite) -> void:
	for _i: int in 30:
		await get_tree().process_frame
		if site.is_open:
			site.billow()
			return


## Every break on the cockpit, open or not, for the destruction to burst out of.
func get_sites() -> Array[CockpitDamageSite]:
	return _sites
