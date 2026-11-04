extends Control
## A resolution-independent diagram shared by the info panel and codex.

var term: String = ""
var unit_scale: float = 1.0


static func supports(keyword_id: String) -> bool:
	return keyword_id in ["adjacent", "surrounding"]


static func configure(popup: PanelContainer, label: RichTextLabel, keyword_id: String, ui_scale: float) -> void:
	var diagram: Control = popup.find_child("KeywordDiagram", true, false) as Control
	if diagram == null:
		var column: VBoxContainer = VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		popup.add_child(column)
		diagram = load("res://Source/Systems/UI/InfoShower/keyword_diagram.gd").new() as Control
		diagram.name = "KeywordDiagram"
		diagram.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(diagram)
		label.reparent(column)
	diagram.set("term", keyword_id)
	diagram.set("unit_scale", ui_scale)
	diagram.custom_minimum_size = Vector2(54, 54) * ui_scale
	diagram.visible = supports(keyword_id)
	diagram.queue_redraw()


func _draw() -> void:
	if not supports(term):
		return
	var center: Vector2 = Vector2(size.x / 2.0, 27.0 * unit_scale)
	var accent: Color = Globals.orange
	for x: int in range(-1, 2):
		for y: int in range(-1, 2):
			var offset: Vector2 = Vector2(x, y)
			var selected: bool = offset != Vector2.ZERO and (term == "surrounding" or absi(x) + absi(y) == 1)
			var cell: Rect2 = Rect2(center + (offset * 17.0 - Vector2(7, 7)) * unit_scale, Vector2(14, 14) * unit_scale)
			var fill: Color = Color("29343b")
			if selected:
				fill = accent.darkened(0.65)
			elif offset == Vector2.ZERO:
				fill = Globals.purple.darkened(0.35)
			draw_rect(cell, fill)
			draw_rect(cell, accent if selected else Color("59676b"), false, unit_scale)
			if selected:
				var direction: Vector2 = offset.normalized()
				var tip: Vector2 = center + offset * 17.0 * unit_scale
				var start: Vector2 = center + direction * 6.0 * unit_scale
				var wing: Vector2 = direction.orthogonal() * 2.5 * unit_scale
				var neck: Vector2 = tip - direction * 4.0 * unit_scale
				draw_line(start, tip, accent, unit_scale)
				draw_line(tip, neck + wing, accent, unit_scale)
				draw_line(tip, neck - wing, accent, unit_scale)
