class_name EchoLook
extends RefCounted
## What an echo of the Reckoning's Tally looks like (RECKONING_ENDINGS.md §2):
## a ship the player destroyed, half its own hull and half Fate's, and
## spaghettified while it's still coming out of the black hole. All of it is
## echo_ship.gdshader; this dresses a ship in it and drives its `emerge`.
##
## The shader replaces the ship's material and carries over every uniform the
## enemy shader has, so the graphics manager's hit flashes, fades and cloaks
## keep working on it unchanged (they only ever name those uniforms on
## ship_graphics.material). It isn't layered on top: a canvas item has one
## material, and the flash has to be applied inside the same pass.

const _SHADER: Shader = preload("res://Source/Systems/Graphics/FateSelf/echo_ship.gdshader")

## What the enemy shader holds, carried over to the echo's material.
const _CARRIED: Array[StringName] = [&"alpha", &"flash_color", &"flash_amount", &"cloak_amount",
	&"cloak_key_color", &"cloak_main_color", &"cloak_bg_color", &"cloak_tolerance"]

## How fast the stretch lets go on the way out. Under 1, so the ship is still
## visibly drawn out well into the trip and is whole only as it lands.
const _SETTLE_CURVE: float = 0.6


## Dresses [param ship] as an echo that Fate holds [param corruption] of (0 to
## 1, half by default). [param seed_value] keeps a wave's echoes from glitching
## together. False, and nothing changed, for a hull this can't dress (not a
## plain sprite).
static func dress(ship: Enemy, seed_value: float, corruption: float) -> bool:
	var hull: Sprite2D = _hull_of(ship)
	if hull == null or hull.texture == null or hull.region_enabled or hull.hframes * hull.vframes > 1:
		return false
	var previous: ShaderMaterial = hull.material as ShaderMaterial
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = _SHADER
	if previous:
		for parameter: StringName in _CARRIED:
			var value: Variant = previous.get_shader_parameter(parameter)
			if value != null:
				material.set_shader_parameter(parameter, value)
	var rect: Rect2 = hull.get_rect()
	material.set_shader_parameter(&"rect_origin", rect.position)
	material.set_shader_parameter(&"rect_size", rect.size)
	material.set_shader_parameter(&"flip", Vector2(float(hull.flip_h), float(hull.flip_v)))
	material.set_shader_parameter(&"seed", seed_value)
	material.set_shader_parameter(&"progress", corruption)
	material.set_shader_parameter(&"emerge", 0.0)
	hull.material = material
	return true


## Whether the ship is wearing this look.
static func is_dressed(ship: Enemy) -> bool:
	var hull: Sprite2D = _hull_of(ship)
	return hull != null and hull.material is ShaderMaterial \
		and (hull.material as ShaderMaterial).shader == _SHADER


## How far out of the hole a ship is after [param progress] of its trip, 1 to
## 0, for [method emerge].
static func emerge_for(progress: float) -> float:
	return pow(clampf(1.0 - progress, 0.0, 1.0), _SETTLE_CURVE)


## Sets how drawn out the ship is: [param amount] 1 at the hole to 0 settled,
## stretched along [param travel] (the way it's going, in screen terms, with
## the hole behind it).
static func emerge(ship: Enemy, amount: float, travel: Vector2) -> void:
	var hull: Sprite2D = _hull_of(ship)
	if hull == null or not is_dressed(ship):
		return
	var material: ShaderMaterial = hull.material as ShaderMaterial
	material.set_shader_parameter(&"emerge", amount)
	if travel.is_zero_approx():
		return
	# The shader works in the sprite's own axes.
	var local: Vector2 = hull.global_transform.affine_inverse().basis_xform(travel).normalized()
	material.set_shader_parameter(&"emerge_dir", local)


static func _hull_of(ship: Enemy) -> Sprite2D:
	if not is_instance_valid(ship) or not ship.graphics_manager:
		return null
	return ship.graphics_manager.ship_graphics as Sprite2D
