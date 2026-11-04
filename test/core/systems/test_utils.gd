extends "res://test/helpers/die_fighter_test.gd"
## Utils: array helpers, dice ordering and the tutorial text tag parsers.


func test_array_while_excluding() -> void:
	assert_eq(Utils.array_while_excluding([1, 2, 3, 4], [2, 4]), [1, 3])


func test_dice_sort_left_to_right_then_top_to_bottom() -> void:
	var a: Node2D = autofree(Node2D.new())
	a.global_position = Vector2(10, 5)
	var b: Node2D = autofree(Node2D.new())
	b.global_position = Vector2(0, 0)
	var c: Node2D = autofree(Node2D.new())
	c.global_position = Vector2(10, 1)
	assert_eq(Utils.sort_dice_by_position([a, b, c]), [b, c, a] as Array[Node])


func test_dice_sort_can_pin_a_die_to_the_front() -> void:
	var a: Node2D = autofree(Node2D.new())
	a.global_position = Vector2(0, 0)
	var b: Node2D = autofree(Node2D.new())
	b.global_position = Vector2(10, 0)
	assert_eq(Utils.sort_dice_by_position([a, b], b), [b, a] as Array[Node])


func test_delay_tags_are_removed_and_timed_by_visible_character() -> void:
	var formatted: Dictionary = Utils.format_with_delays("Hi(delay=0.5) there(delay=2)")
	assert_eq(formatted["text"], "Hi there")
	assert_eq(formatted["length"], 8)
	assert_eq(formatted["delays"], {2: 0.5, 8: 2.0} as Dictionary[int, float])


func test_delay_positions_skip_bbcode() -> void:
	# The pause lands after "Ready.", not after the colour tag's characters.
	var formatted: Dictionary = Utils.format_with_delays("[color=#ff0000]Ready.[/color](delay=0.3) Go")
	assert_eq(formatted["delays"], {6: 0.3} as Dictionary[int, float])
	assert_eq(formatted["length"], 9)


func test_strip_bbcode_removes_tags_and_inline_images() -> void:
	var text := "[b]Deal[/b] [img={8}x{8}]res://icon.png[/img]3 [color=#ff0000]damage[/color]"
	assert_eq(Utils.strip_bbcode_tags(text), "Deal 3 damage")
