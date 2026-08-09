extends Node2D

@export_category('Background Components')
@export var num_of_stars: int = 100
@export var num_of_twinkling_stars: int = 25
@export var background_color: Color = Globals.purple
@export var star_pixel_scene: PackedScene
@export var star_twinkle_scene: PackedScene

var hit_particles: PackedScene = preload("uid://doi43icsr46q0")
var explosion_particles: PackedScene = preload("uid://566ykra4buin")

const _DICE_CANNON_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/dice_cannon.tres")
const _PLAYER_HEALTH_HIT_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/player_health_hit.tres")

var stars: Array[Node2D] = []
@export var star_speed: float = 25
var screen_size: Vector2 = Vector2(320, 180)

var entering_cockpit_scene: String = "uid://2htmp8viygbt"


func _ready() -> void:
	_set_stars()
	star_speed = 25
	
	ResourceLoader.load_threaded_request(entering_cockpit_scene)


func _process(delta: float) -> void:
	for star in stars:
		star.global_position.x -= delta * star_speed
		
		if star.global_position.x < 0:
			star.global_position.x = screen_size.x + 5
			star.global_position.y = RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 0, screen_size.y)
			
			
func _set_stars() -> void:
	for i in range(num_of_stars):
		var star: Node2D = star_pixel_scene.instantiate()
		add_child(star)
		star.global_position = Vector2(
			RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 0, screen_size.x),
			RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 0, screen_size.y)
		)

		# Randomize the opacity of the star to simulate distance
		star.modulate = Color(1, 1, 1, RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 0.25, 0.75))

		stars.append(star)


	for i in range(num_of_twinkling_stars):
		var star: Node2D = star_twinkle_scene.instantiate()
		add_child(star)
		star.global_position = Vector2(
			RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 0, screen_size.x),
			RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 0, screen_size.y)
		)

		# Randomize the opacity of the star to simulate distance
		star.modulate = Color(1, 1, 1, RNGManager.randf_range(RNGManager.Bucket.COSMETIC, 0.25, 0.75))

		stars.append(star)


func _play_dice_cannon_fire_sound() -> void:
	Events.play_sound.emit(_DICE_CANNON_SFX)


func _player_ship_hit() -> void:
	Events.play_sound.emit(_PLAYER_HEALTH_HIT_SFX)
	Events.camera_shake_large.emit(true)
	
	var hit_flash_time: float = 1.5
	$PlayerShip.material.set_shader_parameter('color', Globals.red)
	var tween: Tween = get_tree().create_tween()
	tween.tween_property($PlayerShip, "material:shader_parameter/flash_amount", 1, hit_flash_time * 0.05).from(0).set_trans(Tween.TRANS_QUAD)
	tween.tween_property($PlayerShip, "material:shader_parameter/flash_amount", 0, hit_flash_time * 0.95).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Create hit particles
	var particles: CPUParticles2D = hit_particles.instantiate()
	particles.color = Globals.red
		
	particles.amount = 30
	particles.rotation = PI
	$PlayerShip.add_child(particles)
	
	# Create explosion particles
	var explosion: CPUParticles2D = explosion_particles.instantiate()
	explosion.color = Globals.red
	explosion.amount = 20
	$PlayerShip.add_child(explosion)
	
	
func _switch_to_next_scene() -> void:
	var status := ResourceLoader.load_threaded_get_status(entering_cockpit_scene)
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var resource := ResourceLoader.load_threaded_get(entering_cockpit_scene)
		if resource is PackedScene:
			get_tree().change_scene_to_packed(resource)

	elif status == ResourceLoader.THREAD_LOAD_FAILED:
		push_error("Failed to load entering cockpit cutscene")


func _input(event: InputEvent) -> void:
	# Handle skipping the cutscene
	if event is InputEventMouseButton and \
	event.button_index == MOUSE_BUTTON_LEFT and \
	event.pressed:
		_switch_to_next_scene()
