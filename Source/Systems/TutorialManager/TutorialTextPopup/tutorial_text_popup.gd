class_name TutorialTextPopup
extends Node2D

@export var fade_in_duration: float = 0.3
@export var fade_out_duration: float = 0.2
@export var auto_close_delay: float = 0.0 # 0 means don't auto-close

var background: ColorRect
var label: Label
var close_button: Button
var tween: Tween

func _ready() -> void:
	# Create UI elements
	_setup_ui()
	
	# Start fade in
	_fade_in()

func _setup_ui() -> void:
	# Create background
	background = ColorRect.new()
	background.color = Color(0, 0, 0, 0.8)
	background.size = Vector2(400, 100)
	background.position = Vector2(-200, -50)
	add_child(background)
	
	# Create label
	label = Label.new()
	label.text = ""
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(380, 80)
	label.position = Vector2(-190, -40)
	label.add_theme_font_size_override("font_size", 16)
	add_child(label)
	
	# Create close button
	close_button = Button.new()
	close_button.text = "×"
	close_button.size = Vector2(30, 30)
	close_button.position = Vector2(170, -50)
	close_button.pressed.connect(_on_close_button_pressed)
	add_child(close_button)

func setup(text: String, global_pos: Vector2) -> void:
	label.text = text
	global_position = global_pos
	
	# Auto-close if delay is set
	if auto_close_delay > 0:
		await get_tree().create_timer(auto_close_delay).timeout
		close()

func _fade_in() -> void:
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)
	
	tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, fade_in_duration)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), fade_in_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _fade_out() -> void:
	if tween:
		tween.kill()
	
	tween = create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, fade_out_duration)
	tween.tween_property(self, "scale", Vector2(0.8, 0.8), fade_out_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	await tween.finished
	queue_free()

func close() -> void:
	_fade_out()

func _on_close_button_pressed() -> void:
	close()

func _input(event: InputEvent) -> void:
	# Close on any input if desired
	if event is InputEventKey and event.pressed:
		close()
	elif event is InputEventMouseButton and event.pressed:
		close()
