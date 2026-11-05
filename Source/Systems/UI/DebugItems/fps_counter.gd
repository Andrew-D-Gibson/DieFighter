extends RichTextLabel


func _ready() -> void:
	Events.toggle_fps_display.connect(_toggle_display)
	
	
func _process(_delta: float) -> void:
	# Hidden by alpha rather than visible, which is the player's toggle.
	modulate.a = 0.0 if TrailerView.clean_hud else 1.0
	if self.visible:
		text = "FPS: " + str(int(Engine.get_frames_per_second()))
	
	
func _toggle_display() -> void:
	self.visible = not self.visible
