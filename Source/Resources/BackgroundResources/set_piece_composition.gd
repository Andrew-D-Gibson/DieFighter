class_name SetPieceComposition
extends Resource
## One way to arrange a background's planets and stars. A background lists a
## few of these; BackgroundManager picks one on arrival and nudges it, so a
## region met twice doesn't show the same world in the same spot.
##
## Positions are authored for one side of the screen. A mirrorable
## composition may also appear flipped left to right, lighting and all, which
## is why each piece's light comes from its own scale rather than the screen.

## Relative chance against the background's other compositions.
@export var weight: float = 1.0
## The pieces, positioned as for the unmirrored layout. Empty is allowed: open
## space, where the stars drift (see BackgroundManager's star rule).
@export var objects: Array[StaticBackgroundObjectResource] = []
## How far the whole group may slide, each way. Moves every piece together, so
## a moon keeps its place beside its planet.
@export var offset_jitter: Vector2 = Vector2(6, 5)
## Whether the layout may also appear mirrored left to right.
@export var mirrorable: bool = true
## How far the shared sun may rise or sink (see CelestialBody.light_tilt), so
## the terminators don't always sit at the same angle.
@export_range(0.0, 0.5, 0.01) var light_tilt_jitter: float = 0.2


## Where one piece ends up, before it is instanced.
class Placement:
	var object: StaticBackgroundObjectResource
	var position: Vector2
	## Flips the piece left to right on top of its authored scale.
	var mirrored: bool = false
	## Multiplies a CelestialBody's diameter.
	var size_scale: float = 1.0
	## See CelestialBody.light_tilt.
	var light_tilt: float = 0.0
	## The face a CelestialBody turns to, in radians.
	var face: float = 0.0


## Picks one composition by weight. Null for an empty list.
static func pick(
	compositions: Array[SetPieceComposition], rng: RandomNumberGenerator
) -> SetPieceComposition:
	var total: float = 0.0
	for composition: SetPieceComposition in compositions:
		total += maxf(composition.weight, 0.0)
	if total <= 0.0:
		return null
	var roll: float = rng.randf() * total
	for composition: SetPieceComposition in compositions:
		roll -= maxf(composition.weight, 0.0)
		if roll < 0.0:
			return composition
	return compositions[-1]


## Rolls this layout's variation and returns where each piece goes. Draws a
## fixed number of values per piece, so the same rng state always lays it out
## the same way.
func place(rng: RandomNumberGenerator, screen_width: float) -> Array[Placement]:
	var mirrored: bool = mirrorable and rng.randf() < 0.5
	var offset: Vector2 = Vector2(
		rng.randf_range(-offset_jitter.x, offset_jitter.x),
		rng.randf_range(-offset_jitter.y, offset_jitter.y)
	)
	var tilt: float = rng.randf_range(-light_tilt_jitter, light_tilt_jitter)

	var placements: Array[Placement] = []
	for object: StaticBackgroundObjectResource in objects:
		var placement: Placement = Placement.new()
		placement.object = object
		var own: Vector2 = Vector2(
			rng.randf_range(-object.position_jitter.x, object.position_jitter.x),
			rng.randf_range(-object.position_jitter.y, object.position_jitter.y)
		)
		var position: Vector2 = (object.position + offset + own).round()
		if mirrored:
			position.x = screen_width - position.x
		placement.position = position
		placement.mirrored = mirrored
		placement.size_scale = 1.0 + rng.randf_range(-object.size_jitter, object.size_jitter)
		placement.light_tilt = tilt
		placement.face = rng.randf() * TAU
		placements.append(placement)
	return placements
