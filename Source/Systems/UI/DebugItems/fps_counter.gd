extends RichTextLabel


func _ready() -> void:
	Events.toggle_fps_display.connect(_toggle_display)
	
	
func _process(_delta: float) -> void:
	if self.visible:
		text = "FPS: " + str(int(Engine.get_frames_per_second()))
	
	
func _toggle_display() -> void:
	self.visible = not self.visible
