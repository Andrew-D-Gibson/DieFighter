class_name HealthBarController
extends Node2D

@export_category('Behavior')
## How long the white "damage taken" bar holds before it catches up to the hull.
@export var damage_update_time: float = 0.75

@export var text_shake_time: float = 0.25
@export var text_shake_level: int = 8

var _health_white_tween: Tween
var _health_shake_tween: Tween
var _shields_shake_tween: Tween


@export_category('Components')
@export var health_component: Health


func _ready() -> void:
	_set_shields()
	_set_health()
	
	# Connect health signals
	health_component.health_set.connect(_set_health)
	health_component.health_damaged.connect(func() -> void:
		_set_health()
		_start_health_text_shake()
	)
	health_component.health_healed.connect(func() -> void:
		_set_health()
		_play_health_gained_feedback()
	)
	
	# Connect shield signals
	health_component.shields_set.connect(_set_shields)
	health_component.shields_damaged.connect(func() -> void:
		_set_shields()
		_start_shield_text_shake()
	)
	health_component.shields_reinforced.connect(func() -> void:
		_set_shields()
		_play_shields_gained_feedback()
	)
	
	
func _get_health_string() -> String:
	return str(health_component.health)

func _get_shield_string() -> String:
	return str(health_component.shields)
	
	
func _set_health() -> void:
	var tween_time: float = 0.1
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(%HealthBar, 'value', float(health_component.health) / health_component.max_health, tween_time).from_current().set_trans(Tween.TRANS_QUAD)
	
	# The white bar trails the hit, so the player can see how much it took.
	if _health_white_tween:
		_health_white_tween.kill()
	_health_white_tween = create_tween()
	_health_white_tween.tween_property(%HealthUpdateBar, 'value', float(health_component.health) / health_component.max_health, 0.5)\
		.set_delay(damage_update_time).set_trans(Tween.TRANS_QUAD)

	%HealthLabel.text = _get_health_string()
	


func _start_health_text_shake() -> void:
	%HealthLabel.text = '[shake rate=75, level=' + str(text_shake_level) + ']' + _get_health_string() + '[/shake]'
	_health_shake_tween = _restore_label_after_shake(_health_shake_tween, %HealthLabel, _get_health_string)
	

func _set_shields() -> void:
	%ShieldsLabel.text = _get_shield_string()
	
	if health_component.shields <= 0:
		%Shields.visible = false
		return
	
	%Shields.visible = true


func _start_shield_text_shake() -> void:
	%ShieldsLabel.text = '[shake rate=75, level=' + str(text_shake_level + 2) + ']' + _get_shield_string() + '[/shake]'
	_shields_shake_tween = _restore_label_after_shake(_shields_shake_tween, %ShieldsLabel, _get_shield_string)


## Puts the plain readout back once the shake has played. A hit landing mid-
## shake replaces the pending restore, so the shake runs its full length again.
func _restore_label_after_shake(previous: Tween, label: RichTextLabel, text: Callable) -> Tween:
	if previous:
		previous.kill()
	var tween: Tween = create_tween()
	tween.tween_interval(text_shake_time)
	tween.tween_callback(func() -> void: label.text = text.call())
	return tween


## Losses shake the readout; gains should feel just as physical, or the
## defensive half of the game reads as a spreadsheet next to the attacks.
func _play_shields_gained_feedback() -> void:
	Juice.bump(%Shields, 0.35, 0.3)
	Juice.sparkle(self, %Shields.global_position, Globals.blue, 8, 30.0, true)
	_flash_bright(%ShieldsLabel)


func _play_health_gained_feedback() -> void:
	var bar: Control = %HealthBar
	Juice.sparkle(self, bar.get_global_rect().get_center(), Globals.green, 10, 30.0, true)
	_flash_bright(bar)
	_flash_bright(%HealthLabel)


## Over-brightens `item` and lets it settle. self_modulate, so it doesn't
## fight anything driving the node's own modulate.
func _flash_bright(item: CanvasItem) -> void:
	var tween: Tween = item.create_tween()
	tween.tween_property(item, "self_modulate", Color.WHITE, 0.3) \
		.from(Color(2.0, 2.0, 2.0)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
