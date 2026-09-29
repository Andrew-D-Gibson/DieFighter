extends "res://test/helpers/die_fighter_test.gd"
## Health: shields absorb first, hull clamps, and the signals that drive
## feedback (shields_broken, fatal_damage, death) fire on the right beats.

var health: Health


func before_each() -> void:
	super()
	health = Health.new()
	health.max_health = 10
	health.starting_health = 10
	health.starting_shields = 3
	add_child_autofree(health)
	watch_signals(health)


func test_starts_from_the_starting_values() -> void:
	assert_eq(health.health, 10)
	assert_eq(health.shields, 3)


func test_shields_absorb_damage_they_can_cover() -> void:
	health.take_damage(2)
	assert_eq(health.shields, 1)
	assert_eq(health.health, 10)
	assert_signal_not_emitted(health, "health_damaged")


func test_overflow_damage_breaks_shields_then_hits_hull() -> void:
	health.take_damage(5)
	assert_eq(health.shields, 0)
	assert_eq(health.health, 8)
	assert_signal_emit_count(health, "shields_broken", 1)
	assert_signal_emitted(health, "health_damaged")


func test_shields_break_only_on_the_transition_to_zero() -> void:
	health.take_damage(3)
	health.take_damage(2)
	assert_signal_emit_count(health, "shields_broken", 1)


func test_invulnerable_ignores_damage() -> void:
	health.invulnerable = true
	health.take_damage(50)
	assert_eq(health.health, 10)
	assert_eq(health.shields, 3)


func test_healing_clamps_at_max() -> void:
	health.change_health(-4)
	health.change_health(99)
	assert_eq(health.health, 10)
	assert_signal_emitted(health, "health_healed")


func test_hull_never_goes_below_zero_and_death_fires_once() -> void:
	health.take_damage(99)
	assert_eq(health.health, 0)
	assert_signal_emit_count(health, "fatal_damage", 1)
	assert_signal_emit_count(health, "death", 1)


func test_a_fatal_damage_listener_can_prevent_death() -> void:
	# The engine death-save pattern relies on this: fatal_damage fires first,
	# and death is only declared if hull is still at zero afterwards.
	health.fatal_damage.connect(func() -> void: health.health = 1)
	health.take_damage(99)
	assert_eq(health.health, 1)
	assert_signal_not_emitted(health, "death")
