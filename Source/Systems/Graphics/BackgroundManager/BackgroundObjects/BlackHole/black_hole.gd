@tool
extends Node2D

var time = 1000.0
var override_time = false
var original_colors
@export var relative_scale : float = 1.0
@export var gui_zoom : float = 1.0

func _ready():
	original_colors = get_colors()

func _process(delta):
	time += delta	
	if !override_time:
		update_time(time)
		
func set_pixels(amount):
	$BlackHole.material.set_shader_parameter("pixels", amount)
	 # times 3 here because in this case ring is 3 times larger than planet
	$Disk.material.set_shader_parameter("pixels", amount*3.0)
	
	$BlackHole.size = Vector2(amount, amount)
	$Disk.position = Vector2(-amount, -amount)
	$Disk.size = Vector2(amount, amount)*3.0

func set_light(_pos):
	pass

func set_seed(sd):
	var converted_seed = sd%1000/100.0
	$Disk.material.set_shader_parameter("seed", converted_seed)

func set_rotates(r):
	$Disk.material.set_shader_parameter("rotation", r+0.7)

func update_time(t):
	$Disk.material.set_shader_parameter("time", t * 314.15 * 0.004 )

func set_custom_time(t):
	$Disk.material.set_shader_parameter("time", t * 314.15 * $Disk.material.get_shader_parameter("time_speed") * 0.5)

func set_dither(d):
	$Disk.material.set_shader_parameter("should_dither", d)

func get_dither():
	return $Disk.material.get_shader_parameter("should_dither")

func get_colors_from_shader(mat, uniform_name = "colors"):
	return mat.get_shader_parameter(uniform_name)

func set_colors_on_shader(mat, colors, uniform_name = "colors"):
	mat.set_shader_parameter(uniform_name, colors)

func get_colors():
	return get_colors_from_shader($BlackHole.material) + get_colors_from_shader($Disk.material)

func set_colors(colors):
	var cols1 = colors.slice(0, 3)
	var cols2 = colors.slice(3, 8)
	set_colors_on_shader($BlackHole.material, cols1)
	set_colors_on_shader($Disk.material, cols2)

func _generate_new_colorscheme(n_colors, hue_diff = 0.9, saturation = 0.5):
#	var a = Vector3(rand_range(0.0, 0.5), rand_range(0.0, 0.5), rand_range(0.0, 0.5))
	var a = Vector3(0.5,0.5,0.5)
#	var b = Vector3(rand_range(0.1, 0.6), rand_range(0.1, 0.6), rand_range(0.1, 0.6))
	var b = Vector3(0.5,0.5,0.5) * saturation
	var c = Vector3(
		RNGManager.randf_range(RNGManager.Bucket.BACKGROUND, 0.5, 1.5),
		RNGManager.randf_range(RNGManager.Bucket.BACKGROUND, 0.5, 1.5),
		RNGManager.randf_range(RNGManager.Bucket.BACKGROUND, 0.5, 1.5)
	) * hue_diff
	var d = Vector3(
		RNGManager.randf_range(RNGManager.Bucket.BACKGROUND, 0.0, 1.0),
		RNGManager.randf_range(RNGManager.Bucket.BACKGROUND, 0.0, 1.0),
		RNGManager.randf_range(RNGManager.Bucket.BACKGROUND, 0.0, 1.0)
	) * RNGManager.randf_range(RNGManager.Bucket.BACKGROUND, 1.0, 3.0)

	var cols = PackedColorArray()
	var n = float(n_colors - 1.0)
	n = max(1, n)
	for i in range(0, n_colors, 1):
		var vec3 = Vector3()
		vec3.x = (a.x + b.x *cos(6.28318 * (c.x*float(i/n) + d.x)))
		vec3.y = (a.y + b.y *cos(6.28318 * (c.y*float(i/n) + d.y)))
		vec3.z = (a.z + b.z *cos(6.28318 * (c.z*float(i/n) + d.z)))

		cols.append(Color(vec3.x, vec3.y, vec3.z))
	
	return cols


func randomize_colors():
	var seed_colors = _generate_new_colorscheme(
		5 + RNGManager.randi(RNGManager.Bucket.BACKGROUND) % 2,
		RNGManager.randf_range(RNGManager.Bucket.BACKGROUND, 0.3, 0.5),
		2.0
	)
	var cols= []
	for i in 5:
		var new_col = seed_colors[i].darkened((i/5.0) * 0.7)
		new_col = new_col.lightened((1.0 - (i/5.0)) * 0.9)

		cols.append(new_col)

	set_colors([Color("272736")] + [cols[0], cols[3]] + cols)
