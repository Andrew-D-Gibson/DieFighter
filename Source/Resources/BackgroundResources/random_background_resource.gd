class_name RandomBackgroundResource
extends Resource

@export_category('Random Background Pool')
@export var eligible_backgrounds: Array[BackgroundResource] = []

## Another pool whose backgrounds are eligible here too. Lets a variant ("every
## basic background but the ones that make no sense at a repair dock") pick up
## backgrounds added to the base pool later, instead of drifting from it.
@export var includes_pool: RandomBackgroundResource

## Never drawn from this pool, even when eligible or brought in by
## includes_pool.
@export var excluded_backgrounds: Array[BackgroundResource] = []


## [param rule_free] leaves out every background with a rule of its own, a
## permanent one (BackgroundModifierResource) or a timed hazard, for a run's
## first stops. A pool with nothing else to offer (an encounter built around
## its hazard) draws as usual. Either way it's one draw, so the stream after it
## is the same.
func get_random_background(rng: RandomNumberGenerator, rule_free: bool = false) -> BackgroundResource:
	var pool: Array[BackgroundResource] = get_backgrounds()
	if pool.size() == 0:
		push_error("RandomBackgroundResource: No eligible backgrounds defined!")
		return null
	if rule_free:
		var calm: Array[BackgroundResource] = without_rules(pool)
		if not calm.is_empty():
			pool = calm

	return pool[rng.randi() % pool.size()]


## [param backgrounds] minus the ones that carry a rule or a hazard.
static func without_rules(backgrounds: Array[BackgroundResource]) -> Array[BackgroundResource]:
	var calm: Array[BackgroundResource] = []
	for background: BackgroundResource in backgrounds:
		if background.global_modifier == null and background.hazard == null:
			calm.append(background)
	return calm


## Every background this pool can draw, in a stable order so a seed always
## picks the same one.
func get_backgrounds() -> Array[BackgroundResource]:
	var candidates: Array[BackgroundResource] = []
	if includes_pool:
		candidates.append_array(includes_pool.get_backgrounds())
	candidates.append_array(eligible_backgrounds)

	var pool: Array[BackgroundResource] = []
	for background: BackgroundResource in candidates:
		if background not in pool and background not in excluded_backgrounds:
			pool.append(background)
	return pool
