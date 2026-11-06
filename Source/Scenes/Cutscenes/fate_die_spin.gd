class_name FateDieSpin
extends SubViewport
## Fate's Die as a real cube, turning in a little 3D world of its own: the
## one solid, rotating thing in a game drawn flat. The ending cutscene shows
## it blank, then carves its faces one at a time as they come round.
##
## Rendered at art-pixel size (one texel to about one art pixel at the face's
## widest), so whatever shows it should draw this viewport's texture with
## nearest filtering and palette_snap.gdshader, which puts the lit, shaded
## render back on the approved palette and outlines it.
##
## The faces are composed here from the faces' 7x7 glyphs at three times
## their size, rather than from FateDieArt's 11x11 dice: those carry a 2D
## bevel and clear corners, which a lit cube would show as holes.

## A face carved: [param face] went onto cube side [param side].
signal carved(side: int, face: FateDie.Face)

## A face texture's width and height: a pixel of outline round a 45x45 slab.
const TEXELS: int = 47
const _GLYPH_SCALE: int = 5
## The viewport's size, and how much of the 3D world it sees (in cube widths,
## top to bottom). Together: about TEXELS screen pixels to a face.
const _SIZE: int = 120
const _VIEW_HEIGHT: float = 2.55

## Each side of the cube: the way it faces, and which way is up on it, so its
## glyph reads the right way up when it comes round to the front.
const _SIDES: Array[Array] = [
	[Vector3.BACK, Vector3.UP],
	[Vector3.RIGHT, Vector3.UP],
	[Vector3.FORWARD, Vector3.UP],
	[Vector3.LEFT, Vector3.UP],
	[Vector3.UP, Vector3.FORWARD],
	[Vector3.DOWN, Vector3.BACK],
]

## How fast it turns about its own axis, in radians per second, and how far
## and how fast that axis wobbles, so every side comes round in turn.
@export var spin_speed: float = 1.25
@export var tilt: float = 0.5
@export var wobble: float = 0.32
## Texels to a glyph pixel on each face: 5 for the cutscene's big die, 1 for
## one the size of the canopy's bone die (FateDieArt.SIZE). The viewport is
## sized to match. Set before the viewport enters the tree.
var glyph_scale: int = _GLYPH_SCALE
## Off, the die stops turning itself, so whoever shows it can steer it
## through set_orientation() (the die above "You" turns toward a face).
var turning: bool = true

var _pivot: Node3D
var _materials: Array[StandardMaterial3D] = []
var _faces: Array[FateDie.Face] = []
## Per side: how hot its carving still glows (1 just carved, fading to 0).
var _glow: PackedFloat32Array = PackedFloat32Array()
var _glow_colors: PackedColorArray = PackedColorArray()
var _age: float = 0.0


func _init() -> void:
	size = Vector2i(_SIZE, _SIZE)
	transparent_bg = true
	own_world_3d = true
	msaa_3d = Viewport.MSAA_DISABLED
	render_target_update_mode = SubViewport.UPDATE_ALWAYS


func _ready() -> void:
	size = Vector2i.ONE * roundi(face_size(glyph_scale) * _VIEW_HEIGHT)
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.42
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world_environment: WorldEnvironment = WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = _VIEW_HEIGHT
	camera.position = Vector3(0, 0, 5)
	add_child(camera)

	# From high on the left and in front: the top and left sides catch it,
	# the right and bottom fall into shade.
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation = Vector3(deg_to_rad(-38.0), deg_to_rad(-32.0), 0.0)
	light.light_energy = 0.62
	add_child(light)

	_pivot = Node3D.new()
	add_child(_pivot)
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.mesh = _build_cube()
	_pivot.add_child(mesh_instance)
	for side: int in _SIDES.size():
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		material.roughness = 1.0
		material.emission_enabled = true
		material.emission = Color.BLACK
		mesh_instance.set_surface_override_material(side, material)
		_materials.append(material)
		_faces.append(FateDie.Face.BLANK)
		_glow.append(0.0)
		_glow_colors.append(Color.WHITE)
		_set_face(side, FateDie.Face.BLANK)
	_turn(0.0)


func _process(delta: float) -> void:
	if turning:
		_turn(delta)
	for side: int in _glow.size():
		if _glow[side] <= 0.0:
			continue
		_glow[side] = maxf(0.0, _glow[side] - delta * 1.4)
		_materials[side].emission = _glow_colors[side] * (_glow[side] * _glow[side])


## Carves [param face] onto whichever blank side is turned most toward the
## viewer, so the carving is seen. Returns that side, or -1 if none is blank.
func carve_facing(face: FateDie.Face) -> int:
	var best: int = -1
	var best_facing: float = -INF
	for side: int in _SIDES.size():
		if _faces[side] != FateDie.Face.BLANK:
			continue
		var facing: float = (_pivot.global_basis * (_SIDES[side][0] as Vector3)).z
		if facing > best_facing:
			best_facing = facing
			best = side
	if best < 0:
		return -1
	_set_face(best, face)
	var res: FateFaceResource = FateFaceCatalog.get_face(face)
	_glow[best] = 1.0
	_glow_colors[best] = res.color if res else Color.WHITE
	carved.emit(best, face)
	return best


## Puts [param faces] on the cube, one per side, side i taking faces[i]
## (a FateDie's slots, in order).
func show_faces(faces: Array[FateDie.Face]) -> void:
	for side: int in mini(faces.size(), _SIDES.size()):
		_set_face(side, faces[side])


## Lights side [param side] up in [param color], fading, as a carving does.
func flare(side: int, color: Color) -> void:
	if side < 0 or side >= _glow.size():
		return
	_glow[side] = 1.0
	_glow_colors[side] = color


## The cube's turn, for a die steered from outside (turning off).
func get_orientation() -> Quaternion:
	return _pivot.basis.get_rotation_quaternion() if _pivot else Quaternion.IDENTITY


func set_orientation(orientation: Quaternion) -> void:
	if _pivot:
		_pivot.basis = Basis(orientation.normalized())


## The turn that shows side [param side] square to the camera, its glyph
## the right way up.
static func facing(side: int) -> Quaternion:
	var normal: Vector3 = _SIDES[side][0]
	var up: Vector3 = _SIDES[side][1]
	return Basis(up.cross(normal), up, normal).transposed().get_rotation_quaternion()


## A face texture's width and height at [param scale] texels to a glyph
## pixel: the 7x7 glyph, a glyph pixel's worth of bone round it, and a texel
## of outline.
static func face_size(scale: int) -> int:
	return 9 * scale + 2


## How many sides are still blank.
func blank_count() -> int:
	return _faces.count(FateDie.Face.BLANK)


func _turn(delta: float) -> void:
	_age += delta
	_pivot.basis = Basis.from_euler(Vector3(
		tilt + wobble * sin(_age * 0.9),
		_age * spin_speed,
		wobble * sin(_age * 0.6 + 1.0)
	))


func _set_face(side: int, face: FateDie.Face) -> void:
	_faces[side] = face
	_materials[side].albedo_texture = face_texture(face, glyph_scale)


## One side of the cube showing [param face]: bone, outlined, with its glyph
## cut in at [param scale] times size (or a chisel mark, blank).
static func face_texture(face: FateDie.Face, scale: int = _GLYPH_SCALE) -> ImageTexture:
	var texels: int = face_size(scale)
	var image: Image = Image.create_empty(texels, texels, false, Image.FORMAT_RGBA8)
	image.fill(FateDieArt.BONE)
	for i: int in texels:
		image.set_pixel(i, 0, FateDieArt.OUTLINE)
		image.set_pixel(i, texels - 1, FateDieArt.OUTLINE)
		image.set_pixel(0, i, FateDieArt.OUTLINE)
		image.set_pixel(texels - 1, i, FateDieArt.OUTLINE)
	var res: FateFaceResource = FateFaceCatalog.get_face(face)
	if face != FateDie.Face.BLANK and res and res.glyph:
		var glyph: Image = res.glyph.get_image()
		glyph.decompress()
		glyph.convert(Image.FORMAT_RGBA8)
		glyph.resize(glyph.get_width() * scale, glyph.get_height() * scale, Image.INTERPOLATE_NEAREST)
		var at: Vector2i = (Vector2i(texels, texels) - glyph.get_size()) / 2
		image.blend_rect(glyph, Rect2i(Vector2i.ZERO, glyph.get_size()), at)
	else:
		var middle: int = texels / 2
		image.fill_rect(Rect2i(middle - scale / 2, middle - scale / 2, scale, scale), FateDieArt.BONE_DEEP)
	return ImageTexture.create_from_image(image)


## A unit cube, one surface per side so each can take its own face.
func _build_cube() -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	for side: Array in _SIDES:
		var normal: Vector3 = side[0]
		var up: Vector3 = side[1]
		var right: Vector3 = up.cross(normal)
		var centre: Vector3 = normal * 0.5
		var top_left: Vector3 = centre - right * 0.5 + up * 0.5
		var top_right: Vector3 = centre + right * 0.5 + up * 0.5
		var bottom_right: Vector3 = centre + right * 0.5 - up * 0.5
		var bottom_left: Vector3 = centre - right * 0.5 - up * 0.5
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		# Clockwise seen from outside: Godot's front faces.
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([top_left, top_right, bottom_right, top_left, bottom_right, bottom_left])
		arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([normal, normal, normal, normal, normal, normal])
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
			Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1),
		])
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
