extends Control

@onready var line_edit := $PanelContainer/VBoxContainer/LineEdit
@onready var command_history := $PanelContainer/VBoxContainer/RichTextLabel

var _history_list: Array[String] = []
var _history_index: int = -1


func _ready() -> void:
	line_edit.gui_input.connect(_on_line_edit_gui_input)


func _test(_command_args: Array[String] = []) -> void:
	if Globals.scenario_manager.engine:
		var tile: Tile = Globals.tile_grid.tile_locations[Vector2i(0,0)]
		
		Globals.scenario_manager.engine.add_modifier(LockoutModifier.new(tile))


func _on_line_edit_gui_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	match event.keycode:
		KEY_UP:
			_navigate_history(1)
			get_viewport().set_input_as_handled()
		KEY_DOWN:
			_navigate_history(-1)
			get_viewport().set_input_as_handled()


func _navigate_history(direction: int) -> void:
	if _history_list.is_empty():
		return
	var new_index := _history_index + direction
	if new_index < 0:
		_history_index = -1
		line_edit.text = ''
		line_edit.caret_column = 0
		return
	_history_index = mini(new_index, _history_list.size() - 1)
	line_edit.text = _history_list[_history_index]
	line_edit.caret_column = line_edit.text.length()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed('DevConsole'):
		_toggle_dev_console()


func _toggle_dev_console() -> void:
	visible = !visible

	if visible:
		line_edit.grab_focus()
		line_edit.text = ''


func _on_line_edit_text_submitted(console_command: String) -> void:
	if console_command.strip_edges().is_empty():
		line_edit.text = ''
		line_edit.edit.call_deferred()
		return

	if _history_list.is_empty() or _history_list[0] != console_command:
		_history_list.push_front(console_command)
	_history_index = -1

	command_history.append_text('\n' + console_command)

	var command: PackedStringArray = console_command.split(' ')
	match command[0]:
		'activate_tile':
			_activate_tile(command.slice(1))

		'add_money':
			_add_money(command.slice(1))

		'charge_engines':
			_charge_engines(command.slice(1))

		'clear':
			_clear()

		'clear_grid':
			_clear_grid()

		'd':
			_play_comparison_test_sound()

		'damage':
			_damage(command.slice(1))

		'damage_enemies':
			_damage_enemies(command.slice(1))

		'fps':
			_toggle_fps_display()

		'give_tile':
			_give_tile(command.slice(1))

		'god':
			_god()

		'heal':
			_heal(command.slice(1))

		'help':
			_help()

		'kill_enemies':
			_kill_enemies()

		'load_grid':
			_load_grid(command.slice(1))
			
		'lock_tiles':
			_lock_tiles()

		'reroll':
			_reroll(command.slice(1))

		's':
			_play_test_sound()

		'save_grid':
			_save_grid(command.slice(1))

		'set_dice':
			_set_dice(command.slice(1))

		'set_health':
			_set_health(command.slice(1))

		'set_money':
			_set_money(command.slice(1))

		'shield':
			_shield(command.slice(1))

		'shield_enemies':
			_shield_enemies(command.slice(1))

		'spawn_dice':
			_spawn_dice(command.slice(1))

		'spawn_enemy':
			_spawn_enemy(command.slice(1))
			
		'unlock_tiles':
			_unlock_tiles()

		'test':
			_test(command.slice(1))

		_:
			command_history.append_text('\t\tInvalid command. Type [b]help[/b] for a list.')

	line_edit.text = ''
	line_edit.edit.call_deferred()


func _on_line_edit_text_changed(current_text: String) -> void:
	if current_text.contains('`'):
		current_text.replace('`', '')
		visible = !visible


# ── Tile / Grid ──────────────────────────────────────────────────────────────

func _activate_tile(command_args: Array[String] = []) -> void:
	if command_args.size() < 2 or not command_args[0].is_valid_int() or not command_args[1].is_valid_int():
		command_history.append_text('\n\t\tUsage: activate_tile <x> <y>  (x: 0-4, y: 0-2, combat only)')
		return

	var grid_pos := Vector2i(int(command_args[0]), int(command_args[1]))

	if not Globals.tile_grid.is_grid_pos_valid(grid_pos):
		command_history.append_text('\n\t\tInvalid grid position (x: 0-4, y: 0-2).')
		return

	if Globals.tile_grid.is_grid_pos_open(grid_pos):
		command_history.append_text('\n\t\tNo tile at (' + str(grid_pos.x) + ', ' + str(grid_pos.y) + ').')
		return

	var tile: Tile = Globals.tile_grid.tile_locations[grid_pos]

	if not tile.scenario_engine:
		command_history.append_text('\n\t\tactivate_tile only works during combat.')
		return

	var event := TileActivationEvent.new()
	event.tile = tile
	event.activator_die = null
	tile.scenario_engine.queue_event(event)

	command_history.append_text('\n[center]Activated tile at (' + str(grid_pos.x) + ', ' + str(grid_pos.y) + ').[/center]')


func _clear_grid() -> void:
	for tile: Tile in Globals.tile_grid.tile_locations.values():
		tile.queue_free()
	Globals.tile_grid.tile_locations.clear()
	command_history.append_text('\n[center]Cleared all tiles.[/center]')


func _give_tile(command_args: Array[String] = []) -> void:
	if command_args.is_empty():
		command_history.append_text('\n\t\tUsage: give_tile <name>')
		return

	var available_pos: Vector2i = Globals.tile_grid.find_available_grid_pos()
	if not Globals.tile_grid.is_grid_pos_valid(available_pos):
		command_history.append_text('\n\t\tNo space in the grid.')
		return

	var search_name: String = ' '.join(command_args).strip_edges().to_lower()
	var found_resource: TileResource = null

	var search_dirs: Array[String] = [
		"res://Source/Content/Tiles/TileResources/",
		"res://Source/Content/Tiles/ComplicatedTileResources/",
	]
	for dir_location: String in search_dirs:
		var dir: DirAccess = DirAccess.open(dir_location)
		if not dir:
			continue
		for file_name: String in dir.get_files():
			if not file_name.ends_with(".tres"):
				continue
			var res := ResourceLoader.load(dir_location + file_name)
			if res is TileResource and res.tile_name.to_lower().contains(search_name):
				found_resource = res
				break
		if found_resource:
			break

	if not found_resource:
		command_history.append_text('\n\t\tNo tile found matching: "' + search_name + '"')
		return

	var tile: Tile = Globals.tile_grid.create_tile(found_resource)
	add_child(tile)
	tile.global_position = Globals.tile_grid.grid_to_global_pos(available_pos)
	Globals.tile_grid.receive_tile(tile, tile.global_position)

	command_history.append_text('\n[center]Added: ' + found_resource.tile_name + '[/center]')


func _save_grid(command_args: Array[String] = []) -> void:
	var slot: String = command_args[0].to_lower() if command_args.size() == 1 else ''
	if not slot in ['a', 'b', 'c']:
		command_history.append_text('\n\t\tUsage: save_grid <a|b|c>')
		return

	var data: Dictionary = {}
	for pos: Vector2i in Globals.tile_grid.tile_locations.keys():
		var tile: Tile = Globals.tile_grid.tile_locations[pos]
		data[str(pos)] = tile.tile_resource.resource_path

	var file := FileAccess.open("user://dev_grid_" + slot + ".json", FileAccess.WRITE)
	if not file:
		command_history.append_text('\n\t\tFailed to write save file.')
		return
	file.store_string(JSON.stringify(data))
	command_history.append_text('\n[center]Grid saved to slot ' + slot.to_upper() + '.[/center]')


func _load_grid(command_args: Array[String] = []) -> void:
	var slot: String = command_args[0].to_lower() if command_args.size() == 1 else ''
	if not slot in ['a', 'b', 'c']:
		command_history.append_text('\n\t\tUsage: load_grid <a|b|c>')
		return

	var file := FileAccess.open("user://dev_grid_" + slot + ".json", FileAccess.READ)
	if not file:
		command_history.append_text('\n\t\tNo save in slot ' + slot.to_upper() + '.')
		return

	var data = JSON.parse_string(file.get_as_text())
	if not data is Dictionary:
		command_history.append_text('\n\t\tCorrupt save in slot ' + slot.to_upper() + '.')
		return

	for tile: Tile in Globals.tile_grid.tile_locations.values():
		tile.queue_free()
	Globals.tile_grid.tile_locations.clear()

	for key: String in data.keys():
		var trimmed := key.trim_prefix("(").trim_suffix(")")
		var parts := trimmed.split(", ")
		if parts.size() != 2:
			continue
		var pos := Vector2i(int(parts[0]), int(parts[1]))
		if not Globals.tile_grid.is_grid_pos_valid(pos):
			continue
		var resource := ResourceLoader.load(data[key])
		if not resource is TileResource:
			continue
		var tile: Tile = Globals.tile_grid.create_tile(resource)
		add_child(tile)
		tile.global_position = Globals.tile_grid.grid_to_global_pos(pos)
		Globals.tile_grid.receive_tile(tile, tile.global_position)

	command_history.append_text('\n[center]Loaded grid from slot ' + slot.to_upper() + '.[/center]')


# ── Player ───────────────────────────────────────────────────────────────────

func _add_money(command_args: Array[String] = []) -> void:
	var amount: int = 0
	if command_args.size() == 1 and command_args[0].is_valid_int():
		amount = int(command_args[0])

	Globals.player.money += amount
	command_history.append_text('\n[center]Gave ' + str(amount) + ' money.[/center]')


func _charge_engines(command_args: Array[String] = []) -> void:
	var amount: int = Globals.player.max_engine_charge
	if command_args.size() == 1 and command_args[0].is_valid_int():
		amount = int(command_args[0])

	Globals.player.engine_charge += amount
	command_history.append_text("\n[center]Charged player's engines.[/center]")


func _damage(command_args: Array[String] = []) -> void:
	var amount: int = 0
	if command_args.size() == 1 and command_args[0].is_valid_int():
		amount = int(command_args[0])

	Globals.player.health.take_damage(amount)
	command_history.append_text('\n[center]Damaged player.[/center]')


func _god() -> void:
	Globals.player.health.invulnerable = !Globals.player.health.invulnerable
	if Globals.player.health.invulnerable:
		command_history.append_text('\n[center]God mode ON.[/center]')
	else:
		command_history.append_text('\n[center]God mode OFF.[/center]')


func _heal(command_args: Array[String] = []) -> void:
	var amount: int = Globals.player.health.max_health
	if command_args.size() == 1 and command_args[0].is_valid_int():
		amount = int(command_args[0])

	Globals.player.health.change_health(amount)
	command_history.append_text('\n[center]Healed player.[/center]')
	
	
func _lock_tiles() -> void:
	for tile: Tile in Globals.tile_grid.tile_locations.values():
		tile.draggable.dragging_allowed = false


func _reroll(command_args: Array[String] = []) -> void:
	if command_args.size() == 1 and command_args[0].is_valid_int():
		var amount: int = clampi(int(command_args[0]), 1, 6)
		for die in Globals.player.dice_manager.queue:
			die.value = amount
	else:
		Globals.player.reroll_dice()


func _set_dice(command_args: Array[String] = []) -> void:
	if command_args.is_empty():
		command_history.append_text('\n\t\tUsage: set_dice <v1> [v2] ...')
		return
	var dice := Globals.player.dice_manager.queue
	if dice.is_empty():
		command_history.append_text('\n\t\tNo dice in queue.')
		return
	for i in range(mini(command_args.size(), dice.size())):
		if command_args[i].is_valid_int():
			dice[i].value = clampi(int(command_args[i]), 1, 6)
	command_history.append_text('\n[center]Set dice values.[/center]')


func _set_health(command_args: Array[String] = []) -> void:
	if command_args.size() != 1 or not command_args[0].is_valid_int():
		command_history.append_text('\n\t\tUsage: set_health <amount>')
		return
	var amount: int = clampi(int(command_args[0]), 1, Globals.player.health.max_health)
	Globals.player.health.health = amount
	command_history.append_text('\n[center]Set health to ' + str(amount) + '.[/center]')


func _set_money(command_args: Array[String] = []) -> void:
	if command_args.size() != 1 or not command_args[0].is_valid_int():
		command_history.append_text('\n\t\tUsage: set_money <amount>')
		return
	Globals.player.money = maxi(0, int(command_args[0]))
	command_history.append_text('\n[center]Set money to ' + str(Globals.player.money) + '.[/center]')


func _shield(command_args: Array[String] = []) -> void:
	var amount: int = Globals.player.health.max_health
	if command_args.size() == 1 and command_args[0].is_valid_int():
		amount = int(command_args[0])

	Globals.player.health.change_shields(amount)
	command_history.append_text('\n[center]Shielded player.[/center]')


func _spawn_dice(command_args: Array[String] = []) -> void:
	var amount: int = 1
	if command_args.size() == 1 and command_args[0].is_valid_int():
		amount = int(command_args[0])

	Globals.player.spawn_dice(amount)
	command_history.append_text('\n[center]Spawned ' + str(amount) + ' dice.[/center]')


# ── Enemies ──────────────────────────────────────────────────────────────────

func _damage_enemies(command_args: Array[String] = []) -> void:
	var amount: int = 0
	if command_args.size() == 1 and command_args[0].is_valid_int():
		amount = int(command_args[0])

	Globals.enemy_manager.damage_all_enemies(amount)
	command_history.append_text('\n[center]Damaged all enemies.[/center]')


func _kill_enemies() -> void:
	Globals.enemy_manager.kill_all_enemies()
	command_history.append_text('\n[center]Killed all enemies.[/center]')


func _shield_enemies(command_args: Array[String] = []) -> void:
	var amount: int = 10
	if command_args.size() == 1 and command_args[0].is_valid_int():
		amount = int(command_args[0])

	Globals.enemy_manager.shield_all_enemies(amount)
	command_history.append_text('\n[center]Shielded all enemies.[/center]')


func _spawn_enemy(_command_args: Array[String] = []) -> void:
	command_history.append_text('\n\t\tspawn_enemy is not yet implemented.')
	

func _unlock_tiles() -> void:
	for tile: Tile in Globals.tile_grid.tile_locations.values():
		tile.draggable.dragging_allowed = true


# ── Misc ─────────────────────────────────────────────────────────────────────

func _clear() -> void:
	command_history.text = ''


func _toggle_fps_display() -> void:
	Events.toggle_fps_display.emit()


const _TEST_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/dice_cannon.tres")
const _TEST_COMPARISON_SFX: SoundEffectResource = preload("res://Source/Resources/SoundEffectResources/SoundEffects/enemy_health_hit.tres")

func _play_test_sound() -> void:
	print('Playing test sound: dice_cannon')
	Events.play_sound.emit(_TEST_SFX)


func _play_comparison_test_sound() -> void:
	print('Playing test sound: enemy_health_hit')
	Events.play_sound.emit(_TEST_COMPARISON_SFX)


func _help() -> void:
	command_history.append_text('\n[center]━━━ COMMANDS ━━━[/center]')
	command_history.append_text('\n[b]activate_tile[/b] <x> <y>         activate tile at grid pos (combat only, no die)')
	command_history.append_text('\n[b]add_money[/b] <amount>            add money')
	command_history.append_text('\n[b]charge_engines[/b] [amount]       charge player engines')
	command_history.append_text('\n[b]clear[/b]                         clear this console')
	command_history.append_text('\n[b]clear_grid[/b]                    remove all tiles from grid')
	command_history.append_text('\n[b]damage[/b] <amount>               damage player')
	command_history.append_text('\n[b]damage_enemies[/b] <amount>       damage all enemies')
	command_history.append_text('\n[b]fps[/b]                           toggle FPS display')
	command_history.append_text('\n[b]give_tile[/b] <name>              add a tile by name to first open slot')
	command_history.append_text('\n[b]god[/b]                           toggle player invulnerability')
	command_history.append_text('\n[b]heal[/b] [amount]                 heal player (default: full)')
	command_history.append_text('\n[b]kill_enemies[/b]                  kill all enemies')
	command_history.append_text('\n[b]load_grid[/b] <a|b|c>             load saved grid layout from file')
	command_history.append_text('\n[b]lock_tiles[/b] <a|b|c>            stop tiles from being moved')
	command_history.append_text('\n[b]reroll[/b] [value]                reroll dice, or set all to value')
	command_history.append_text('\n[b]save_grid[/b] <a|b|c>             save grid layout to file (persists across runs)')
	command_history.append_text('\n[b]set_dice[/b] <v1> [v2] ...        set die values (1-6, left to right)')
	command_history.append_text('\n[b]set_health[/b] <amount>           set player health to exact value')
	command_history.append_text('\n[b]set_money[/b] <amount>            set money to exact amount')
	command_history.append_text('\n[b]shield[/b] [amount]               add shields to player')
	command_history.append_text('\n[b]shield_enemies[/b] [amount]       add shields to all enemies')
	command_history.append_text('\n[b]spawn_dice[/b] [amount]           spawn extra dice')
	command_history.append_text('\n[b]spawn_enemy[/b] <type>            (not yet implemented)')
	command_history.append_text('\n[b]unlock_tiles[/b] <a|b|c>          allow tiles to be moved')
	command_history.append_text('\n[color=gray]Up/Down arrows cycle command history.[/color]')
