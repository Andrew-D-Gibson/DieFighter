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


func get_random_background(rng: RandomNumberGenerator) -> BackgroundResource:
	var pool: Array[BackgroundResource] = get_backgrounds()
	if pool.size() == 0:
		push_error("RandomBackgroundResource: No eligible backgrounds defined!")
		return null

	return pool[rng.randi() % pool.size()]


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
