class_name ShieldInfoArt
extends RefCounted
## The shield info panel's picture with the shields as they stand: the real
## count in the small bubble, in place of one fixed picture reading 10. Drawn
## in HullInfoArt's digit glyphs, recoloured the shield's blue, so the two
## panels' counts read alike.

const _BASE: Texture2D = preload("res://Assets/Textures/Player/PlayerHealthBar/shield_info_base.png")
const _COUNT_COLOUR: Color = Color("#43a6fc")

## The count's row, and the small bubble's middle doubled (so it can fall
## between two pixels), where the original "10" sat.
const _COUNT_TOP: int = 40
const _COUNT_CENTRE_X2: int = 31


## The picture for [param shields].
static func texture_for(shields: int) -> Texture2D:
	return ImageTexture.create_from_image(compose(shields))


static func compose(shields: int) -> Image:
	# A texture can hand back the image it keeps, so draw on a copy.
	var image: Image = _BASE.get_image().duplicate()
	image.convert(Image.FORMAT_RGBA8)
	var text: String = str(maxi(shields, 0))
	var left: int = ceili((_COUNT_CENTRE_X2 - HullInfoArt.text_width(text)) / 2.0)
	HullInfoArt.draw_glyphs(image, text, Vector2i(left, _COUNT_TOP), _COUNT_COLOUR)
	return image
