class_name BackgroundManager
extends Sprite2D

@export var starting_background: RandomBackgroundResource
@export var jump_animation_time: float = 5

@export_category("Parallax System")
@export var global_speed: float = 16
@export var parallax_levels: Array[float] = [0.1, 0.2, 0.3, 0.7, 1.0]  # Speed multipliers for each parallax level

@export_category("Star Parallax")
## Art pixels per second a nearest star streams, per unit of cruise speed (see
## _star_stream_speed()). Each star moves at this times its depth, so near
## stars outrun far ones, as in the opening cutscene's jump.
@export var star_parallax_rate: float = 0.375
## The spread of star depths, far to near. Far stars are dimmer too.
@export var star_depth_range: Vector2 = Vector2(0.3, 1.0)
## Every this many art pixels per second, a moving star smears one pixel
## longer, up to star_max_streak.
@export var star_streak_speed: float = 90.0
@export var star_max_streak: int = 5

@export_category("Managed Scenes")
@export var nebula_scene: PackedScene
@export var star_pixel_scene: PackedScene
@export var star_twinkle_scene: PackedScene
@export var scrolling_object_scene: PackedScene


var stars: Array[Node2D]
var scrolling_objects: Array[Node2D]
var static_objects: Array[Node2D]
var nebula: Node2D

## Current background name for modifier system
var current_background_name: String = ""

## The concrete background currently on screen, after any random pool has been
## resolved. BackgroundModifierManager reads this to find the rule in force.
var current_background: BackgroundResource = null

## Which of the background's set-piece arrangements is on screen, if it has any.
var current_composition: SetPieceComposition = null

## The cruise speed the ship idles at between jumps: global_speed as authored.
var _rest_speed: float = 16.0
## True when nothing anchors the view (see BackgroundResource.anchors_the_view):
## the stars then drift even at rest. Otherwise they hold until a jump.
var _stars_drift: bool = false


func _ready() -> void:
	Globals.background_manager = self
	_rest_speed = global_speed
	_clear_children()

	if starting_background:
		_set_background(starting_background)

	Events.load_scenario.connect(func(scenario: ScenarioResource) -> void:
		_set_background(scenario.background_resource, _arrival_is_rule_free())
	)
	
	
func _process(delta: float) -> void:
	_move_stars(delta)
	_update_objects_motion(scrolling_objects, delta, 1.0, 2, 0, _wrap_scrolling_object_position, _get_scrolling_object_base_speed)
	_update_objects_motion(static_objects, delta, 2.0, 0, 50, _wrap_static_object_position, null, true)
	_update_nebula_speed()


## Generic motion update for objects with parallax
func _update_objects_motion(
	objects: Array[Node2D], 
	delta: float, 
	speed_multiplier: float, 
	default_parallax: int,
	wrap_offset: float,
	wrap_callback: Callable,
	base_speed_callback: Variant = null,
	skip_if_zero: bool = false
) -> void:
	for obj: Node2D in objects:
		var parallax_level: int = obj.get_meta("parallax_level", default_parallax)
		
		if skip_if_zero and parallax_level == 0:
			continue
		
		var base_speed: float = base_speed_callback.call(obj) if base_speed_callback is Callable else 0.0
		var speed: float = (global_speed * get_parallax_speed(parallax_level) * speed_multiplier) + base_speed
		obj.global_position.y += delta * speed
		
		if obj.global_position.y > Globals.SCREEN_SIZE.y + wrap_offset:
			wrap_callback.call(obj)


## How fast a star of depth 1 streams down the screen, in art pixels per
## second.
##
## The rule: stars only move against an empty sky. Where anything anchors the
## view (a planet, a star, a pulsar, a black hole, or a field of debris doing
## the drifting), the ship is holding station and the stars hold with it. They
## only stream once a jump pushes the speed above the resting cruise, and settle
## again as it comes back down. Open space has nothing to contradict the
## motion, so there the stars drift at cruise speed all the time.
func _star_stream_speed() -> float:
	var cruise: float = global_speed if _stars_drift else maxf(global_speed - _rest_speed, 0.0)
	return cruise * star_parallax_rate


func _move_stars(delta: float) -> void:
	var speed: float = _star_stream_speed()
	for star: Node2D in stars:
		var star_speed: float = speed * float(star.get_meta("depth", 1.0))
		star.scale.y = _streak_length(star_speed)
		if star_speed <= 0.0:
			continue
		star.global_position.y += star_speed * delta
		if star.global_position.y > Globals.SCREEN_SIZE.y + 5:
			_wrap_star_position(star)


## Whole pixels, so a smeared star stays on the art grid.
func _streak_length(star_speed: float) -> float:
	return float(clampi(1 + int(star_speed / star_streak_speed), 1, star_max_streak))


func _wrap_star_position(star: Node2D) -> void:
	star.global_position.y = -5 - star.scale.y
	star.global_position.x = RNGManager.randf_range(RNGManager.Bucket.BACKGROUND, 0, Globals.SCREEN_SIZE.x)


func _wrap_scrolling_object_position(piece: ScrollingObject) -> void:
	piece.reroll()
	# Just clear of the top edge, so the new piece slides in rather than pops.
	piece.global_position.y = -5 - piece.bounds.end.y
	piece.global_position.x = RNGManager.randf_range(RNGManager.Bucket.BACKGROUND, 0, Globals.SCREEN_SIZE.x)


func _wrap_static_object_position(obj: Node2D) -> void:
	obj.global_position.y = -50
	obj.global_position.x = RNGManager.randf_range(RNGManager.Bucket.BACKGROUND, 0, Globals.SCREEN_SIZE.x)


func _get_scrolling_object_base_speed(piece: ScrollingObject) -> float:
	return 2.0 + piece.velocity_delta


func _update_nebula_speed() -> void:
	if not nebula or not nebula.material:
		return
	
	var parallax_level: int = nebula.get_meta("parallax_level", 1)
	var speed_multiplier: float = global_speed * get_parallax_speed(parallax_level)
	var base_speed: float = -0.005
	nebula.speed = base_speed * speed_multiplier


## Get the speed multiplier for a given parallax level
func get_parallax_speed(level: int) -> float:
	if level < 0 or level >= parallax_levels.size():
		return 1.0
	return parallax_levels[level]


## Set the global speed and update all objects
func set_global_speed(new_speed: float) -> void:
	global_speed = new_speed
	_update_nebula_speed()
	if nebula and nebula.material:
		var parallax_level: int = nebula.get_meta("parallax_level", 1)
		var speed_multiplier: float = global_speed * get_parallax_speed(parallax_level)
		var base_speed: Vector2 = Vector2(0, -0.01)
		nebula.material.set_shader_parameter("speed", base_speed * speed_multiplier)
	
	
func _clear_children() -> void:
	stars = []
	scrolling_objects = []
	static_objects = []
	nebula = null
	current_composition = null
	
	var children: Array[Node] = get_children()
	for i: int in range(len(children)-1, -1, -1):
		if children[i] is not Control:
			children[i].queue_free()
	
	
## A run's first stops never land under a rule; see
## GameStateManager.is_rule_free_slot(). Globals.map already points at the
## destination when load_scenario fires.
func _arrival_is_rule_free() -> bool:
	return Globals.state_manager != null and is_instance_valid(Globals.map) \
		and Globals.state_manager.is_rule_free_slot(Globals.map.current_scenario_index)


## [param rule_free]: draw from a random pool's backgrounds without a rule.
func _set_background(background_resource: Resource, rule_free: bool = false) -> void:
	_clear_children()

	if background_resource.has_method("get_random_background"):
		var selected_bg: Resource = background_resource.get_random_background(
			RNGManager.get_rng(RNGManager.Bucket.BACKGROUND), rule_free
		)
		if selected_bg:
			_set_background(selected_bg)
		return
	
	if not background_resource is BackgroundResource:
		push_error("BackgroundManager: Invalid background resource type!")
		return
	
	var bg_resource: BackgroundResource = background_resource as BackgroundResource
	current_background = bg_resource
	current_background_name = _determine_background_name(bg_resource)
	self.self_modulate = bg_resource.background_color

	# The layout gets its own stream, seeded by one BACKGROUND draw, so a
	# scenario's seed always gives the same arrangement however many stars or
	# pieces get drawn for before or after it.
	var layout_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	layout_rng.seed = RNGManager.randi(RNGManager.Bucket.BACKGROUND)
	current_composition = SetPieceComposition.pick(bg_resource.set_piece_compositions, layout_rng)
	_stars_drift = not bg_resource.anchors_the_view(current_composition)

	if bg_resource.nebula:
		_set_nebula(bg_resource.nebula_color, bg_resource.nebula_material)
	if bg_resource.stars:
		_set_stars(bg_resource.num_of_stars, bg_resource.num_of_twinkling_stars)
	if bg_resource.scrolling_objects:
		_set_scrolling_objects(bg_resource)
	if current_composition:
		_set_set_pieces(current_composition.place(layout_rng, Globals.SCREEN_SIZE.x))
	if bg_resource.static_objects.size() > 0:
		_set_static_objects(bg_resource.static_objects)

	Events.background_changed.emit(bg_resource)


func _set_nebula(nebula_color: Color, custom_material: ShaderMaterial = null) -> void:
	nebula = nebula_scene.instantiate()
	if custom_material:
		# A copy, since the nebula writes its scroll offset into the material
		# every frame.
		nebula.material = custom_material.duplicate()
	nebula.material.set_shader_parameter('nebula_color', Vector4(nebula_color.r, nebula_color.g, nebula_color.b, nebula_color.a))
	nebula.set_meta("parallax_level", 1)
	add_child(nebula)


func _set_stars(num_of_stars: int, num_of_twinkling_stars: int) -> void:
	_create_stars(star_pixel_scene, num_of_stars)
	_create_stars(star_twinkle_scene, num_of_twinkling_stars)


func _create_stars(star_scene: PackedScene, count: int) -> void:
	for i: int in range(count):
		var star: Node2D = star_scene.instantiate()
		add_child(star)
		star.global_position = _random_screen_position()
		var depth: float = RNGManager.randf_range(
			RNGManager.Bucket.BACKGROUND, star_depth_range.x, star_depth_range.y
		)
		# Far stars are dimmer as well as slower.
		var nearness: float = inverse_lerp(star_depth_range.x, star_depth_range.y, depth)
		star.modulate = Color(1, 1, 1, lerpf(0.25, 0.8, nearness))
		star.set_meta("depth", depth)
		stars.append(star)


func _random_screen_position() -> Vector2:
	return Vector2(
		RNGManager.randf_range(RNGManager.Bucket.BACKGROUND, 0, Globals.SCREEN_SIZE.x),
		RNGManager.randf_range(RNGManager.Bucket.BACKGROUND, 0, Globals.SCREEN_SIZE.y)
	)
		

func _set_scrolling_objects(bg_resource: BackgroundResource) -> void:
	var num_of_med_pieces: int = bg_resource.num_of_med_pieces
	for i: int in range(num_of_med_pieces + bg_resource.num_of_large_pieces):
		var piece: ScrollingObject = scrolling_object_scene.instantiate()
		piece.setup(bg_resource.scrolling_objects, i < num_of_med_pieces, bg_resource.background_color)
		piece.set_meta("parallax_level", 2 if piece.is_medium else 1)
		add_child(piece)
		# Same ordering trap as the static objects below; scrolling objects only
		# hide it by self-correcting the first time they wrap.
		piece.global_position = Vector2(
			RNGManager.randf_range(RNGManager.Bucket.BACKGROUND, 0, Globals.SCREEN_SIZE.x),
			RNGManager.randf_range(RNGManager.Bucket.BACKGROUND, -50, Globals.SCREEN_SIZE.y)
		)
		scrolling_objects.append(piece)


func _set_static_objects(static_object_data: Array[StaticBackgroundObjectResource]) -> void:
	for object_data: StaticBackgroundObjectResource in static_object_data:
		if object_data.scene:
			_add_static_object(object_data.scene.instantiate(), object_data, object_data.position)


func _set_set_pieces(placements: Array[SetPieceComposition.Placement]) -> void:
	for placement: SetPieceComposition.Placement in placements:
		var object_data: StaticBackgroundObjectResource = placement.object
		if not object_data or not object_data.scene:
			continue
		var piece: Node2D = object_data.scene.instantiate()
		var body: CelestialBody = piece as CelestialBody
		if body:
			body.face = placement.face
			body.size_scale = placement.size_scale
			body.light_tilt = placement.light_tilt
		_add_static_object(piece, object_data, placement.position, placement.mirrored)


func _add_static_object(
	static_object: Node2D,
	object_data: StaticBackgroundObjectResource,
	at: Vector2,
	mirrored: bool = false
) -> void:
	static_object.scale = object_data.scale
	if mirrored:
		# Flipping the node flips its shading too, so the light swaps sides
		# with the layout.
		static_object.scale.x = -static_object.scale.x
	static_object.rotation = object_data.rotation
	static_object.modulate = object_data.modulate
	# Stars sit at z 1; anything level with or under them shows the
	# starfield through it, as if see-through.
	static_object.z_index = maxi(static_object.z_index, 1)
	static_object.set_meta("parallax_level", object_data.get_parallax_level())
	add_child(static_object)

	# Must come after add_child: on a node outside the tree global_position
	# just writes the local one, which this manager's own transform then
	# shifts again, landing the object a screen away from where it was
	# authored. Objects that never wrap (parallax 0) stay lost there.
	static_object.global_position = at
	static_objects.append(static_object)
			
			
## How long play_jump_intro() builds before hyperspace punches in.
const JUMP_RAMP_UP_TIME: float = 4.0


func play_jump_intro() -> void:
	var speed_ramp_up_time: float = JUMP_RAMP_UP_TIME

	# Speed up the background object speed by half
	await tween_speed(320, speed_ramp_up_time/2)
	
	# Start fading in particles
	%JumpTransition.set_background_transparency(0)
	%JumpTransition.set_particles_transparency(0)
	%JumpTransition.show()
	%JumpTransition.tween_particles(1.0, speed_ramp_up_time/2)
	
	# Finish speeding up background objects
	await tween_speed(960, speed_ramp_up_time/2)
	
	# Punch in the jump background
	%JumpTransition.tween_background(1.0, 0.5)
	
	# Shake the camera
	Events.camera_shake_large.emit(false)
	
	
## Drops straight into hyperspace with no run-up, for a jump that already had
## its own (a jump gate's passage, cut on a white flash). play_jump_outro()
## brings it back down as usual.
func cut_to_hyperspace() -> void:
	set_global_speed(960)
	%JumpTransition.show()
	%JumpTransition.set_particles_transparency(1.0)
	%JumpTransition.set_background_transparency(1.0)


## Recolours hyperspace until reset_jump_tint(). See JumpTransition.set_tint().
func set_jump_tint(background: Color, particles: Color) -> void:
	%JumpTransition.set_tint(background, particles)


func reset_jump_tint() -> void:
	%JumpTransition.reset_tint()


func play_jump_outro() -> void:
	var speed_ramp_down_time: float = 1
	
	# Drop the jump background
	%JumpTransition.set_background_transparency(0)
	
	# Quickly slow down and fade the particles
	%JumpTransition.tween_particles(0, speed_ramp_down_time)
	await tween_speed(_rest_speed, speed_ramp_down_time)
	%JumpTransition.hide()


## Determine background name based on background resource properties
func _determine_background_name(bg_resource: BackgroundResource) -> String:
	# Simple heuristic to determine background type
	if bg_resource.nebula:
		return "nebula"
	elif bg_resource.stars and bg_resource.num_of_stars > 10:
		return "starfield"
	elif bg_resource.scrolling_objects and bg_resource.num_of_large_pieces > 5:
		return "debris_field"
	elif bg_resource.static_objects.size() > 0 or bg_resource.set_piece_compositions.size() > 0:
		return "complex"
	else:
		return "empty_space"
	
	
func tween_speed(final_speed: float, time: float) -> void:
	var speed_tween: Tween = get_tree().create_tween()
	speed_tween.tween_property(
		self,
		"global_speed",
		final_speed,
		time
	)
	await speed_tween.finished
