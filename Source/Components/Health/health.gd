class_name Health
extends Node2D

signal health_damaged()
signal health_healed()
signal shields_damaged()
signal shields_reinforced()
signal death() 

@export var invulnerable: bool = false

@export_category("Health")
@export var max_health: int
@export var starting_health: int
@onready var health: int = starting_health

@export_category("Shields")
@export var starting_shields: int
@onready var shields: int = starting_shields
	

func take_damage(amount: int) -> void:
	if invulnerable:
		return
		
	if shields >= amount:
		change_shields(-amount)
	else:
		if shields > 0:
			amount -= shields	# Decrease the damage by the shields
			
			shields = 0 # Deplete shields from attack
			shields_damaged.emit()
			
		change_health(-amount)


func change_health(amount: int) -> void:
	health += amount
	health = clampi(health, 0, max_health)
	
	if health <= 0:
		death.emit()
	if amount > 0:
		health_healed.emit()
	else:
		health_damaged.emit()
	
	
func change_shields(amount: int) -> void:
	shields += amount
	shields = clampi(shields, 0, shields)
	
	if amount > 0:
		shields_reinforced.emit()
	else:
		shields_damaged.emit()
