class_name ScreenFrame
## The game's picture: a 1920x1080 canvas (Globals.SCREEN_SIZE through the 6x
## camera). Normally it fills the viewport. Pixel-perfect fullscreen
## (PixelPerfectScaler) shows a little more canvas than that around it and
## blacks the extra out, so anything that keeps itself "on screen" should
## measure against this frame rather than the viewport.

## Canvas units per art pixel: the cameras' zoom.
const ART_PIXEL_SCALE: float = 6.0
const SIZE: Vector2 = Globals.SCREEN_SIZE * ART_PIXEL_SCALE


## The frame in [param viewport]'s own (screen-layer) coordinates.
static func rect_in_viewport(viewport: Viewport) -> Rect2:
	var visible: Rect2 = viewport.get_visible_rect()
	return Rect2(visible.position + (visible.size - SIZE) / 2.0, SIZE)


## The frame in [param item]'s canvas coordinates: what of its canvas the
## player can actually see.
static func canvas_rect(item: CanvasItem) -> Rect2:
	return item.get_canvas_transform().affine_inverse() * rect_in_viewport(item.get_viewport())
