extends Control

@onready var line_edit := $PanelContainer/VBoxContainer/LineEdit
@onready var command_history := $PanelContainer/VBoxContainer/RichTextLabel


func _test(_command_args: Array[String] = []) -> void:
	print('Test called!')
	

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed('DevConsole'):
		_toggle_dev_console()
	
	
func _toggle_dev_console() -> void:
	visible = !visible
	
	if visible:
		line_edit.grab_focus()
		line_edit.text = ''


func _on_line_edit_text_submitted(console_command: String) -> void:
	# Add to the history
	command_history.append_text('\n' + console_command)
	
	# Handle commands
	var command = console_command.split(' ')
	match command[0]:
		'add_money':
			_add_money(command.slice(1))
			
		'charge_engines':
			_charge_engines(command.slice(1))
			
		'clear':
			_clear()
			
		'damage':
			_damage(command.slice(1))
			
		'heal':
			_heal(command.slice(1))
			
		'kill_enemies':
			_kill_enemies()
			
		'reroll':
			_reroll(command.slice(1))
			
		'shield':
			_shield(command.slice(1))
			
		'shield_enemies':
			_shield_enemies(command.slice(1))
			
		#'player_invulnerable':
			#_player_invulnerable()
					#
		#'enemies_invulnerable':
			#_enemies_invulnerable()
			
		#'game_state':
			#_game_state(command.slice(1))
			
		'test':
			_test(command.slice(1))
			
		_:
			command_history.append_text('\t\tInvalid command.')
			
	# Clear the line edit for further commands and re-enter the edit mode
	line_edit.text = ''
	line_edit.edit.call_deferred()


func _on_line_edit_text_changed(current_text: String) -> void:
	if current_text.contains('`'):
		current_text.replace('`', '')
		visible = !visible



func _add_money(command_args: Array[String] = []) -> void:
	var amount: int = 0
	if len(command_args) == 1 and command_args[0].is_valid_int():
		amount = int(command_args[0])
	
	Globals.player.money += amount
	command_history.append_text('\n[center]Gave money to player[/center]')
	
	
func _charge_engines(command_args: Array[String] = []) -> void:
	var amount: int = Globals.player.max_engine_charge
	if len(command_args) == 1 and command_args[0].is_valid_int():
		amount = int(command_args[0])
		
	Globals.player.engine_charge += amount
	command_history.append_text("\n[center]Charged player's engines![/center]")
	
	
func _clear() -> void:
	command_history.text = ''
	

func _damage(command_args: Array[String] = []) -> void:
	var amount: int = 0
	if len(command_args) == 1 and command_args[0].is_valid_int():
		amount = int(command_args[0])
	
	Globals.player.health.take_damage(amount)	
	command_history.append_text('\n[center]Damaged player![/center]')
	

func _heal(command_args: Array[String] = []) -> void:
	var amount: int = Globals.player.health.max_health
	if len(command_args) == 1 and command_args[0].is_valid_int():
		amount = int(command_args[0])
	
	Globals.player.health.change_health(amount)	
	command_history.append_text('\n[center]Healed player![/center]')
	
	
func _reroll(command_args: Array[String] = []) -> void:
	if len(command_args) == 1 and command_args[0].is_valid_int():
		var amount: int = int(command_args[0])
		amount = clampi(amount, 1, 6)
		for die in Globals.player.dice_manager.queue:
			die.value = amount
		
	else:
		Globals.player.reroll_dice()
	
	
func _shield(command_args: Array[String] = []) -> void:
	var amount: int = Globals.player.health.max_health
	if len(command_args) == 1 and command_args[0].is_valid_int():
		amount = int(command_args[0])
	
	Globals.player.health.change_shields(amount)	
	command_history.append_text('\n[center]Shielded player![/center]')
	

func _shield_enemies(command_args: Array[String] = []) -> void:
	var amount: int = 10
	if len(command_args) == 1 and command_args[0].is_valid_int():
		amount = int(command_args[0])
	
	Globals.enemy_manager.shield_all_enemies(amount)
	command_history.append_text('\n[center]Shielded enemies![/center]')

#func _player_invulnerable(command_args: Array[String] = []) -> void:
	#Globals.player.hp_and_def.invulnerable = !Globals.player.hp_and_def.invulnerable
	#if Globals.player.hp_and_def.invulnerable:
		#command_history.append_text('\n[center]Made player invulnerable![/center]')
	#else:
		#command_history.append_text('\n[center]Returned player to vulnerable.[/center]')
#
#
#func _enemies_invulnerable(command_args: Array[String] = []) -> void:
	#var invulnerable: bool = false
	#var enemies = get_tree().get_nodes_in_group('enemies')
	#if len(enemies) > 0:
		#invulnerable = !enemies[0].hp_and_def.invulnerable
		#
		#for enemy in enemies:
			#enemy.hp_and_def.invulnerable = invulnerable
			#
		#if invulnerable:
			#command_history.append_text('\n[center]Made enemies invulnerable![/center]')
		#else:
			#command_history.append_text('\n[center]Returned all enemies to vulnerable.[/center]')
	#else:
		#command_history.append_text('\n[center]No enemies alive.[/center]')


func _kill_enemies() -> void:
	Globals.enemy_manager.kill_all_enemies()
	command_history.append_text('\n[center]Killed all enemies![/center]')


#func _game_state(command_args: Array[String] = []) -> void:
	#if len(command_args) > 0 and command_args[0].is_valid_int():
		#Events.load_game_state.emit(int(command_args[0]))
		#command_history.append_text('\n[center]Attempting to load game state...[/center]')
		#return
	#
	#command_history.append_text('\t\tInvalid command.')
