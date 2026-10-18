class_name RandomBackgroundResource
extends Resource

@export_category('Random Background Pool')
@export var eligible_backgrounds: Array[BackgroundResource] = []


func get_random_background(rng: RandomNumberGenerator) -> BackgroundResource:
	if eligible_backgrounds.size() == 0:
		push_error("RandomBackgroundResource: No eligible backgrounds defined!")
		return null

	return eligible_backgrounds[rng.randi() % eligible_backgrounds.size()]
