class_name ReckoningHud
extends Node2D
## What the Reckoning shows the player that the cockpit doesn't already: each
## round, the face Fate threw and what it does (FateFaceResource.
## reckoning_text). The escape itself is the engine charger, dressed gold for
## the fight (RECKONING_ENDINGS.md §1), so it has no meter of its own here.
##
## Shows only while a ReckoningDirector is running.

const _BANNER_SECONDS: float = 2.0

var _banner: Control
var _banner_die: TextureRect
var _banner_name: Label
var _banner_text: RichTextLabel
var _banner_tween: Tween


func _ready() -> void:
	z_index = 30
	_build_banner()
	Events.fate_die_rolled.connect(_show_roll)
	hide()


func _process(_delta: float) -> void:
	visible = ReckoningDirector.active() != null


# ── The banner: what Fate threw ─────────────────────────────────────────────

func _build_banner() -> void:
	_banner = Control.new()
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.position = Vector2(60, 26)
	_banner.size = Vector2(200, 50)
	_banner.modulate.a = 0.0
	add_child(_banner)
	_banner_die = TextureRect.new()
	_banner_die.position = Vector2(0, 2)
	_banner_die.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(_banner_die)
	_banner_name = Label.new()
	_banner_name.theme_type_variation = FontRoles.slot(FontRoles.SMALL, 2.0)
	_banner_name.position = Vector2(38, 0)
	_banner_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(_banner_name)
	_banner_text = RichTextLabel.new()
	_banner_text.bbcode_enabled = true
	_banner_text.fit_content = true
	_banner_text.scroll_active = false
	_banner_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner_text.position = Vector2(38, 18)
	_banner_text.custom_minimum_size = Vector2(160, 0)
	_banner_text.size = Vector2(160, 20)
	_banner_text.add_theme_color_override("default_color", Globals.white)
	_banner_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(_banner_text)


func _show_roll(_slot: int, face: int) -> void:
	var res: FateFaceResource = FateFaceCatalog.get_face(face as FateDie.Face)
	if res == null:
		return
	_banner_die.texture = FateDieArt.face_texture(face as FateDie.Face, 3)
	_banner_name.text = tr("RECKONING_FATE_ROLLS").format({"face": res.display_face_name().to_upper()})
	_banner_name.add_theme_color_override("font_color", res.color)
	_banner_text.text = Utils.format_text(res.display_reckoning_text(Globals.fate_ledger), true)
	if _banner_tween:
		_banner_tween.kill()
	_banner.scale = Vector2.ONE * 1.3
	_banner.pivot_offset = _banner.size / 2.0
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.15)
	_banner_tween.parallel().tween_property(_banner, "scale", Vector2.ONE, 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_interval(_BANNER_SECONDS)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.4)
