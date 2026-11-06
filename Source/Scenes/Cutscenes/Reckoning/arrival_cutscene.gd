class_name ArrivalCutscene
extends ReckoningCutsceneSegment
## The arrival (RECKONING_ENDINGS.md §6.2-6.4, §7): what's waiting on the far
## side of the jump out of the Reckoning. Every way out arrives in the same
## place, the sky with no Fate in it; only who's there changes.
##
## | Mode     | Who's there                                     | Credits             |
## |----------|-------------------------------------------------|---------------------|
## | ALONE    | the player's ship, crossing and leaving         | silent, "You made it." |
## | CONVOY   | a formation, with the player in it (perfect: at its front) | beside the convoy, "Flew with you" |
## | LAST_DIE | a formation with a gap at the front (shot 2)    | beside it, "In memory of the ..." |
##
## Built like the first ending (EndingCutscene): everything that is art lives
## in the PixelWorld SubViewport, 320x180 blown up 6x; the stars sit behind
## it at 1080p so they glide. The shot list is a timeline built here rather
## than keyed in an AnimationPlayer, because who arrives, how many gaps there
## are and how long the credits roll all come from the ReckoningEnding. Each
## shot is a cue at an absolute time on one tween, so a skip kills it whole.
##
## Camera rules, from the spec: Alone never pushes in; the Convoy stays wide
## except for the perfect version's one push in; the Last Die stays wide.

@export var star_pixel_scene: PackedScene
@export var star_twinkle_scene: PackedScene

@export_category('Shot')
## How far the shot is pushed in on the 320x180 frame; 1 shows all of it.
## Held on multiples of 1/6, as in the opening.
@export var view_zoom: float = 1.0
## The point of the frame, in art pixels, the shot centres on.
@export var view_center: Vector2 = Vector2(160, 90)

const _ART_SCALE: float = 6.0
const _GOLD: Color = EngineCharger.DRIVE_COLOR
## The warm theme the convoy comes back to, borrowed: the first ending's.
const _CONVOY_TRACK: StringName = &"game_start_theme"
## The arrival chime rises a step each time a ship comes in: a major scale.
const _CHIME_STEPS: PackedFloat32Array = [0, 2, 4, 5, 7, 9, 11, 12, 14, 16, 17, 19]

# Borrowed sounds: see the hand-off notes for the ones this wants made.
const _CHIME_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/glass_tinkle.tres")
const _FLARE_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/shop_stock_pop.tres")
const _DIALOGUE_SCENE: PackedScene = preload("res://Source/Systems/Game/EnemyDialogueManager/enemy_dialogue_manager.tscn")

const _OPEN_SECONDS: float = 1.4
const _CLOSE_SECONDS: float = 1.4
## Credits roll at this many art pixels a second: short, so not slow.
const _CREDITS_SPEED: float = 20.0
const _TYPE_SPEED: float = 14.0

## The convoy's chatter (§9), by who says it; anyone can say the first.
const _CHATTER_ANYONE: String = "ENDING_ARRIVAL_CHATTER_OUT"
const _CHATTER_BY_FACTION: Dictionary[StringName, String] = {
	&"rearguard": "ENDING_ARRIVAL_CHATTER_NO_HOLE",
	&"caravan": "ENDING_ARRIVAL_CHATTER_DRINKS",
}

var _timeline: Tween
var _jump_fx: JumpFx
var _starfield: ArrivalStarfield
var _formation: ArrivalFormation
## Null in the Last Die: the player isn't there.
var _player: ArrivalShip
## The ships that got out, by their slot, front first.
var _arrivals: Array[ArrivalShip] = []
var _hum: ArrivalHum
var _credits: ArrivalCredits
var _closing: bool = false
var _hidden_cursor_layer: CanvasLayer

@onready var _star_layer: CanvasLayer = $StarLayer
@onready var _pixel_layer: CanvasLayer = $PixelLayer
@onready var _pixel_screen: SubViewportContainer = $PixelLayer/PixelScreen
@onready var _curtain: ColorRect = $CurtainLayer/Curtain
@onready var _convoy: Node2D = %Convoy
@onready var _effects: Node2D = %Effects
@onready var _words: Node2D = %Words


func _ready() -> void:
	if ending == null:
		# Run on its own (F6): a made-up ending for whichever mode it's set to.
		ending = ReckoningEnding.preview(_kind_for(mode), mode == Mode.CONVOY)
	var skip: CutsceneSkipPrompt = CutsceneSkipPrompt.new(96)
	skip.confirmed.connect(_skip)
	add_child(skip)
	_hide_cursor(true)
	_jump_fx = JumpFx.new(_effects, true)
	_build_sky()
	# Whatever the fight was playing is gone: Alone has no music at all, and
	# the others bring theirs in on cue.
	MusicDirector.stop(1.0)

	_curtain.color.a = 1.0
	_timeline = create_tween().set_parallel(true)
	_ease(0.0, _curtain, "color:a", 0.0, _OPEN_SECONDS, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	match mode:
		Mode.CONVOY:
			_shoot_convoy()
		Mode.LAST_DIE:
			_shoot_last_die()
		_:
			_shoot_alone()


func _process(_delta: float) -> void:
	_frame_shot()


# --- Alone ------------------------------------------------------------------

## Freedom, and nobody there (§6.2). Wide the whole way: it never pushes in.
func _shoot_alone() -> void:
	_hum = ArrivalHum.new()
	add_child(_hum)
	_ease(0.3, _hum, "hum_level", 0.5, 2.5)

	# The empty sky holds for a beat before anything moves.
	var enter: float = 3.0
	var crossing: float = 17.0
	_player = _make_player()
	_player.position = Vector2(-12, 98)
	_player.engine_power = 0.6
	_cue(enter, _player.show)
	_timeline.tween_property(_player, "position:x", Globals.SCREEN_SIZE.x + 12.0, crossing).set_delay(enter)

	# Too wide and too long. A star or two twinkles; the engines dim a step.
	_cue(enter + 4.0, _twinkle)
	_cue(enter + 6.5, func() -> void: _player.engine_power = 0.35)
	_ease(enter + 6.5, _hum, "pitch", 0.94, 0.6)
	_ease(enter + 6.5, _hum, "hum_level", 0.4, 0.6)
	_cue(enter + 11.0, _twinkle)
	if not ending.left_behind.is_empty():
		_comms_crackle(enter + crossing * 0.48)

	# The ship leaves; the sky holds; the hum fades under the silent credits.
	var gone: float = enter + crossing
	_ease(gone, _hum, "hum_level", 0.12, 2.0)
	var roll: float = gone + 2.5
	var rolled: float = _roll_credits(roll, Globals.SCREEN_SIZE.x / 2.0, 200.0, [])
	# The hum cuts out, and in that silence: "You made it."
	_ease(rolled + 0.6, _hum, "hum_level", 0.0, 0.05)
	var made_it: Label = _line(tr(&"ENDING_ARRIVAL_ALONE_LAST"), Color("#cef0f1"), 84.0)
	made_it.modulate.a = 0.0
	_ease(rolled + 1.8, made_it, "modulate:a", 1.0, 1.2)
	_close(rolled + 6.8)


## "Pilot? ...Pilot?" from someone left behind, out past the left of the
## frame, and the static cuts out mid-word. The ship doesn't slow.
func _comms_crackle(at: float) -> void:
	var from: Node2D = Node2D.new()
	from.position = Vector2(-2, 46)
	_effects.add_child(from)
	var bubble: EnemyDialogueManager = _DIALOGUE_SCENE.instantiate() as EnemyDialogueManager
	bubble.z_index = 30
	# Silent until it speaks: the box would otherwise show its placeholder.
	bubble.hide()
	from.add_child(bubble)
	var line: String = tr(&"ENDING_ARRIVAL_ALONE_COMMS")
	# Cut a fifth short: the end of the second word never comes.
	var heard: String = line.left(maxi(1, line.length() - ceili(line.length() * 0.2)))
	var reveal: float = bubble.character_reveal_time * heard.length()
	_ease(at, _hum, "static_level", 0.7, 0.15)
	_cue(at + 0.35, bubble.show_dialogue.bind(heard, ScenarioManager.Faction.CIVILIAN, false))
	_cue(at + 0.35 + reveal + 0.05, func() -> void:
		_hum.static_level = 0.0
		bubble.hide())


func _twinkle() -> void:
	var at: Vector2 = _starfield.bright_star_point(_player.position)
	var glint: JuiceGlint = JuiceGlint.new()
	glint.color = Color("#cef0f1")
	glint.reach = 2.0
	glint.duration = 0.6
	_effects.add_child(glint)
	glint.position = at


# --- The Convoy -------------------------------------------------------------

## Joy, and who is missing (§6.3). Wide, until the perfect version's one push
## in on the front of the formation.
func _shoot_convoy() -> void:
	_build_formation()
	_cue(0.6, MusicDirector.play_track.bind(_CONVOY_TRACK, 4.0, true))

	# The player jumps in from the left, gold, and slows to a stop among them.
	_player = _make_player()
	var post: Vector2 = _formation.rear()
	_player.position = post - Vector2(46, 0)
	_cue(1.4, _player.arrive.bind(_jump_fx, _GOLD))
	_ease(1.4, _player, "position", post, 1.8, Tween.TRANS_QUART, Tween.EASE_OUT)

	var after_arrivals: float = _schedule_arrivals(3.6, 0.85)
	var joy: float = _schedule_gaps(after_arrivals + 0.6)
	var ships: Array[ArrivalShip] = _arrivals.duplicate()
	ships.append(_player)
	# Flares go up staggered, never all at once; the chatter overlaps them.
	for i: int in ships.size():
		var ship: ArrivalShip = ships[i]
		var color: Color = _GOLD if ship == _player else ship.art.color
		_cue(joy + i * 0.38 + _randf(0.0, 0.2), _fire_flare.bind(ship, color, 1.0))
	_schedule_chatter(joy + 0.5)

	var set_off: float = joy + 5.5
	if ending.perfect:
		set_off = _schedule_perfect(joy + 5.0)
	var last_card: Array[Dictionary] = [{"style": ReckoningCredits.Style.HEADING,
		"text": "CREDITS_FLEW_WITH_YOU", "color": Color("#cef0f1")}]
	for ship: ArrivalShip in _arrivals:
		last_card.append({"style": ReckoningCredits.Style.NAME, "text": ship.art.display_name, "color": ship.art.color})
	_set_off(set_off, last_card)


## Nobody left behind, anywhere: the formation closes, the player slides
## through it to the front, every flare goes up at once with the gold, and
## the line. Returns when the convoy sets off.
func _schedule_perfect(at: float) -> float:
	# 4a. The formation draws in; the player takes the point. The one push in.
	_formation.spacing = (_formation.spacing * 0.85).round().max(Vector2(20, 12))
	for i: int in _arrivals.size():
		var ship: ArrivalShip = _arrivals[i]
		_ease(at, ship, "position", _formation.position_of(_slot_of(ship)), 2.0)
	_ease(at + 0.3, _player, "position", _formation.apex, 3.0)
	_cue(at + 0.3, func() -> void: _player.engine_power = 1.5)
	_ease(at, self, "view_zoom", 1.5, 3.0)
	_ease(at, self, "view_center", _formation.apex - Vector2(30, 0), 3.0)

	# 4b. Every flare at once: the biggest burst in the game, the gold in it.
	var burst: float = at + 3.4
	_cue(burst, func() -> void:
		Events.play_sound.emit(_FLARE_SFX)
		for ship: ArrivalShip in _arrivals:
			for i: int in 2:
				_fire_flare(ship, ship.art.color, 1.0, false)
		for i: int in 5:
			_fire_flare(_player, _GOLD, 1.0, false)
		_jump_fx.ring(_player.global_position, _GOLD, 4.0, 30.0, 0.6))

	# 4c. "No one is behind you." types over the formation.
	var words: Label = _line(tr(&"ENDING_ARRIVAL_PERFECT"), _GOLD, 34.0)
	words.visible_characters = 0
	var typed: float = at + 4.4
	var letters: int = words.text.length()
	_timeline.tween_property(words, "visible_characters", letters, letters / _TYPE_SPEED).set_delay(typed)
	var set_off: float = typed + letters / _TYPE_SPEED + 3.0
	_ease(set_off, words, "modulate:a", 0.0, 1.0)
	_ease(set_off, self, "view_zoom", 1.0, 2.5)
	_ease(set_off, self, "view_center", Vector2(160, 90), 2.5)
	return set_off


## Up to three overlapping lines in speech bubbles, each ship saying its own
## faction's line, front ships first.
func _schedule_chatter(at: float) -> void:
	var lines: Array[String] = [_CHATTER_ANYONE]
	lines.append_array(_CHATTER_BY_FACTION.values())
	var speaker: int = 0
	for ship: ArrivalShip in _arrivals:
		if lines.is_empty():
			break
		var line: String = _CHATTER_BY_FACTION.get(ship.art.faction_id, _CHATTER_ANYONE)
		if not lines.has(line):
			line = lines[0]
		lines.erase(line)
		_cue(at + speaker * 0.8, ship.say.bind(line))
		speaker += 1


# --- The Last Die, shot 2 ---------------------------------------------------

## Those you saved (§6.4): the formation with the gap at its front where the
## player would be, a slow gold salute, and the die the last ship carries.
func _shoot_last_die() -> void:
	_build_formation()
	var after_arrivals: float = _schedule_arrivals(2.2, 1.15)
	var settled: float = _schedule_gaps(after_arrivals + 0.6)

	# The oldest debt speaks.
	var speaker: ArrivalShip = _ship_for(ending.first_saved)
	if speaker == null and not _arrivals.is_empty():
		speaker = _arrivals[0]
	if speaker:
		_cue(settled + 0.4, speaker.say.bind("ENDING_ARRIVAL_LEAVE_FRONT"))
	# And they do: the formation eases back and the front pair parts a
	# little, so the empty point is the shape everyone is flying around.
	for ship: ArrivalShip in _arrivals:
		var slot: int = _slot_of(ship)
		var part: float = (4.0 if slot < 2 else 1.0) * (-1.0 if slot % 2 == 0 else 1.0)
		_ease(settled + 2.4, ship, "position", ship.position + Vector2(-4.0, part), 2.5)

	# A gold salute, a ship at a time, slowly: the Convoy's flares, mourning.
	var salute: float = settled + 3.6
	_cue(salute, MusicDirector.play_track.bind(_CONVOY_TRACK, 6.0, true))
	for i: int in _arrivals.size():
		_cue(salute + i * 1.3, _fire_flare.bind(_arrivals[i], _GOLD, 0.45, true, 44.0))

	# The last ship to leave holds the die you gave it; it catches the light once.
	var holder: ArrivalShip = _ship_for(ending.last_die_holder)
	var glint: float = salute + _arrivals.size() * 1.3 + 1.2
	if holder:
		_cue(glint, func() -> void:
			var star: JuiceGlint = JuiceGlint.new()
			star.color = _GOLD
			star.reach = 5.0
			star.duration = 0.5
			_effects.add_child(star)
			star.global_position = holder.die_glint_point())

	var flown: ShipResource = _player_ship()
	var ship_name: String = flown.display_name if flown else ""
	var last_card: Array[Dictionary] = [{"style": ReckoningCredits.Style.NAME,
		"text": tr(&"CREDITS_IN_MEMORY").format({"ship": ship_name}), "color": _GOLD}]
	_set_off(glint + 2.4, last_card)


# --- Shared shots -----------------------------------------------------------

## The ships that got out jump in one by one, in the order they left the
## fight, each a step higher in the chime. Returns when the last has.
func _schedule_arrivals(at: float, interval: float) -> float:
	for i: int in _arrivals.size():
		var ship: ArrivalShip = _arrivals[i]
		var when: float = at + i * interval
		_cue(when, ship.arrive.bind(_jump_fx, ship.art.color))
		_cue(when, _chime.bind(i))
	return at + maxi(_arrivals.size() - 1, 0) * interval + 0.4


## Each ship left behind tries to follow and never arrives; the missed slots
## stay empty. Returns when the sky has settled.
func _schedule_gaps(at: float) -> float:
	var behind: Array[ArrivalFormation.Slot] = _formation.slots_of(ArrivalFormation.Kind.LEFT_BEHIND)
	if behind.is_empty():
		return at
	for i: int in behind.size():
		var slot: ArrivalFormation.Slot = behind[i]
		var art: ArrivalShipArt.Art = ArrivalShipArt.for_enemy(slot.enemy_id)
		var color: Color = art.color if art else JumpFx.BLUE
		_cue(at + i * 1.6, _failed_jump.bind(_formation.position_of(slot.index), color))
	return at + (behind.size() - 1) * 1.6 + ArrivalFailedJump.GATHER_SECONDS + ArrivalFailedJump.STUTTER_SECONDS + 1.0


## The convoy sets off right, the credits rolling beside it, and flies out of
## the frame while their last card holds. Ends on black.
func _set_off(at: float, last_card: Array[Dictionary]) -> void:
	var front: float = Globals.SCREEN_SIZE.x - 16.0
	var shift: float = front - _formation.apex.x
	_ease(at, _convoy, "position:x", shift, 4.5)
	_ease(at, _starfield, "speed", 26.0, 4.0, Tween.TRANS_QUAD, Tween.EASE_IN)
	_cue(at, func() -> void:
		for ship: ArrivalShip in _all_ships():
			ship.engine_power = maxf(ship.engine_power, 1.3))
	# The credits take the sky the convoy leaves behind it. The player at the
	# rear, if they never took the point, is the convoy's tail.
	var span: float = _formation.depth()
	if _player and not ending.perfect:
		span = (_formation.apex - _formation.rear()).x
	var tail: float = front - span - 18.0
	var rolled: float = _roll_credits(at + 2.0, roundf(tail / 2.0), minf(tail - 8.0, 200.0), last_card)
	_ease(rolled + 1.2, _convoy, "position:x", shift + Globals.SCREEN_SIZE.x, 3.2, Tween.TRANS_QUAD, Tween.EASE_IN)
	_close(rolled + 5.4)


## Rolls the credits from [param at]; returns when they've come to rest.
func _roll_credits(at: float, center_x: float, width: float, last_card: Array[Dictionary]) -> float:
	_credits = ArrivalCredits.new()
	_words.add_child(_credits)
	_credits.build(center_x, width, last_card)
	var distance: float = _credits.rest_scroll()
	var seconds: float = distance / _CREDITS_SPEED
	_timeline.tween_property(_credits, "scroll", distance, seconds).set_delay(at)
	return at + seconds


func _fire_flare(ship: ArrivalShip, color: Color, pace: float, sounded: bool = true, height: float = 0.0) -> void:
	var flare: ArrivalFlare = ArrivalFlare.new()
	flare.color = color
	flare.pace = pace
	flare.height = height if height > 0.0 else _randf(26.0, 38.0)
	flare.lean = _randf(-0.35, 0.35)
	_effects.add_child(flare)
	flare.global_position = ship.global_position + Vector2(0, -3)
	if sounded:
		var pop: SoundEffectResource = _FLARE_SFX.duplicate()
		pop.pitch_scale = 1.6 * pace
		pop.volume = -18.0
		# Timed to the burst at the top of the climb, not the launch.
		flare.create_tween().tween_callback(Events.play_sound.emit.bind(pop)).set_delay(0.7 / pace)


func _failed_jump(at: Vector2, color: Color) -> void:
	var attempt: ArrivalFailedJump = ArrivalFailedJump.new()
	attempt.color = color
	_effects.add_child(attempt)
	attempt.global_position = _convoy.to_global(at)


func _chime(step: int) -> void:
	var chime: SoundEffectResource = _CHIME_SFX.duplicate()
	chime.pitch_scale = pow(2.0, _CHIME_STEPS[mini(step, _CHIME_STEPS.size() - 1)] / 12.0)
	chime.pitch_randomness = 0.0
	chime.volume = -12.0
	Events.play_sound.emit(chime)


func _close(at: float) -> void:
	_ease(at, _curtain, "color:a", 1.0, _CLOSE_SECONDS, Tween.TRANS_SINE, Tween.EASE_IN)
	_cue(at + _CLOSE_SECONDS, _end.bind(false))


# --- Building ---------------------------------------------------------------

## The sky with no Fate in it: black, a thin scatter of stars, two faint
## washes of colour the run's skies never had.
func _build_sky() -> void:
	_starfield = ArrivalStarfield.new()
	_starfield.star_pixel_scene = star_pixel_scene
	_starfield.star_twinkle_scene = star_twinkle_scene
	%Stars.add_child(_starfield)
	for nebula: Sprite2D in [%NebulaGreen, %NebulaAmber]:
		# The scene's own materials, kept apart so each holds its colour.
		nebula.material = nebula.material.duplicate() as Material
		nebula.set(&"speed", -0.002)


## The formation the ending calls for, centred in the frame, and a hidden
## ship in every slot a ship got out to.
func _build_formation() -> void:
	_formation = ArrivalFormation.plan(ending)
	# Centred on the frame, the player's place at the rear counted in when
	# the player is there to fly it.
	var span: float = (_formation.apex - _formation.rear()).x if mode == Mode.CONVOY else _formation.depth()
	_formation.apex = Vector2(roundf((Globals.SCREEN_SIZE.x + span) / 2.0), 90.0)
	for slot: ArrivalFormation.Slot in _formation.slots:
		if slot.kind != ArrivalFormation.Kind.OUT:
			continue
		var art: ArrivalShipArt.Art = ArrivalShipArt.for_enemy(slot.enemy_id)
		if art == null:
			push_warning("ArrivalCutscene: no ship to draw for '%s'; its slot stays empty." % slot.enemy_id)
			continue
		var ship: ArrivalShip = ArrivalShip.create(art, false)
		ship.visible = false
		ship.set_meta(&"slot", slot.index)
		ship.set_meta(&"enemy_id", slot.enemy_id)
		_convoy.add_child(ship)
		ship.position = _formation.position_of(slot.index)
		_arrivals.append(ship)
	var holder: ArrivalShip = _ship_for(ending.last_die_holder)
	if holder and mode == Mode.LAST_DIE:
		holder.carry_die()


func _make_player() -> ArrivalShip:
	var ship: ArrivalShip = ArrivalShip.create(ArrivalShipArt.for_player(_player_ship()), true)
	ship.visible = false
	_convoy.add_child(ship)
	return ship


func _player_ship() -> ShipResource:
	if ending.ship_id != &"":
		return ShipCatalog.find(ending.ship_id)
	return Globals.current_ship()


## The ship that got out as [param enemy_id], or null. The first such ship if
## several of a kind did.
func _ship_for(enemy_id: String) -> ArrivalShip:
	for ship: ArrivalShip in _arrivals:
		if str(ship.get_meta(&"enemy_id", "")) == enemy_id:
			return ship
	return null


func _slot_of(ship: ArrivalShip) -> int:
	return int(ship.get_meta(&"slot", 0))


func _all_ships() -> Array[ArrivalShip]:
	var ships: Array[ArrivalShip] = _arrivals.duplicate()
	if _player:
		ships.append(_player)
	return ships


## A line of the film's own words across the frame, centred at
## [param top]: in the art's pixels, outlined like the first ending's.
func _line(text: String, color: Color, top: float) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.theme_type_variation = FontRoles.slot(FontRoles.BODY)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", FateDieArt.OUTLINE)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = Vector2(0, top)
	label.size = Vector2(Globals.SCREEN_SIZE.x, 0)
	_words.add_child(label)
	return label


# --- Timeline ---------------------------------------------------------------

## Calls [param action] [param at] seconds into the film.
func _cue(at: float, action: Callable) -> void:
	_timeline.tween_callback(action).set_delay(at)


## Eases [param property] of [param target] to [param value], starting
## [param at] seconds into the film.
func _ease(at: float, target: Object, property: NodePath, value: Variant, seconds: float,
		trans: Tween.TransitionType = Tween.TRANS_SINE, easing: Tween.EaseType = Tween.EASE_IN_OUT) -> void:
	_timeline.tween_property(target, property, value, seconds).set_delay(at) \
		.set_trans(trans).set_ease(easing)


# --- Shot -------------------------------------------------------------------

## As the first ending frames its shot: the finished 320x180 picture and the
## starfield are scaled together, so nothing inside the art grid zooms.
func _frame_shot() -> void:
	var art_scale: float = float(_pixel_screen.stretch_shrink)
	var zoom: float = maxf(view_zoom, 1.0)
	var half_view: Vector2 = Globals.SCREEN_SIZE / (2.0 * zoom)
	var centre: Vector2 = view_center.clamp(half_view, Globals.SCREEN_SIZE - half_view)
	var screen: Vector2 = Globals.SCREEN_SIZE * _ART_SCALE
	_star_layer.scale = Vector2.ONE * art_scale * zoom
	_star_layer.offset = screen / 2.0 - centre * art_scale * zoom
	_pixel_layer.scale = Vector2.ONE * zoom
	# Whole screen pixels, so the art grid never lands between them.
	_pixel_layer.offset = (screen / 2.0 - centre * art_scale * zoom).round()


# --- Hand-over --------------------------------------------------------------

## A second press of anything: straight to black, and the whole ending is
## skipped.
func _skip() -> void:
	if _closing:
		return
	_closing = true
	_timeline.kill()
	var close: Tween = create_tween()
	close.tween_property(_curtain, "color:a", 1.0, 0.25)
	close.tween_callback(_end.bind(true))


## On black: hands back to ReckoningEndingPlayer.
func _end(skipped: bool) -> void:
	_closing = true
	_curtain.color.a = 1.0
	_pixel_layer.visible = false
	_star_layer.visible = false
	if _hum:
		_hum.stop()
	_hide_cursor(false)
	finish(skipped)


## The game's pointer would float over the film; it comes back for the end
## screen's buttons.
func _hide_cursor(hide_it: bool) -> void:
	var scene: Node = get_tree().current_scene
	if hide_it:
		_hidden_cursor_layer = scene.get_node_or_null(^"CursorLayer") as CanvasLayer if scene else null
		if _hidden_cursor_layer and _hidden_cursor_layer.visible:
			_hidden_cursor_layer.visible = false
		else:
			_hidden_cursor_layer = null
	elif is_instance_valid(_hidden_cursor_layer):
		_hidden_cursor_layer.visible = true


static func _kind_for(segment_mode: Mode) -> ReckoningEnding.Kind:
	match segment_mode:
		Mode.CONVOY:
			return ReckoningEnding.Kind.CONVOY
		Mode.LAST_DIE:
			return ReckoningEnding.Kind.LAST_DIE
		_:
			return ReckoningEnding.Kind.ALONE


func _randf(from: float, to: float) -> float:
	return RNGManager.randf_range(RNGManager.Bucket.COSMETIC, from, to)
