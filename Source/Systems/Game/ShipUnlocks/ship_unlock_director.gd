class_name ShipUnlockDirector
extends Node
## Earns the ships a run's Fate's Die earns (ShipResource.unlock_face: the
## Carousel, for two Mercy faces), when the run ends, won or lost, and shows
## each one's unlock card over the end screen. Until then, each carving of
## such a face is called out under the die ("THE CARAVAN NOTICED"), so the
## player learns that it counts.
##
## Lives in the game scene. The card goes on a layer of its own above the UI
## layer the end screen is on, following the camera so the card's world-space
## art lines up as it does mid-run. Runs while the tree is paused.

## After the end screen comes up, before the card does: long enough to read
## that the run is over.
const _END_DELAY_SECONDS: float = 1.4
## After a carving, past the die's own carve call-out.
const _NOTICE_DELAY_SECONDS: float = 1.7
## Below the die's carve call-out, which floats from 20 px under the die.
const _NOTICE_OFFSET: Vector2 = Vector2(-26, 30)
## Above the UI layer (1) the end screen is on, below the pause menu (100).
const _CARD_LAYER: int = 90
const _SHIP_UNLOCK_POPUP: PackedScene = preload("res://Source/Systems/UI/ShipUnlockPopup/ship_unlock_popup.tscn")

var _run_ended: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.game_over.connect(_on_run_ended)
	Events.victory.connect(_on_run_ended)
	Events.fate_face_carved.connect(_on_face_carved)


## Earned in the player's own runs; shown there only when newly earned. A run
## that isn't recorded (the Scenario Lab) shows the card without earning, so
## it can be checked.
func _on_run_ended() -> void:
	if _run_ended:
		return
	_run_ended = true
	var ledger: FateLedger = Globals.fate_ledger
	if ledger == null or not ledger.has_die:
		return
	var to_show: Array[ShipResource] = []
	for ship: ShipResource in ShipUnlocks.earned_by_die(ledger.die):
		if ShipUnlocks.unlock(ship.id) or not CollectionManager.is_recording():
			to_show.append(ship)
	if to_show.is_empty() or (is_instance_valid(AutoPilot) and AutoPilot.is_playing()):
		return
	await get_tree().create_timer(_END_DELAY_SECONDS, true).timeout
	for ship: ShipResource in to_show:
		await _show_card(ship, ledger.die)


func _show_card(ship: ShipResource, die: FateDie) -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = _CARD_LAYER
	layer.follow_viewport_enabled = true
	add_child(layer)
	var popup: ShipUnlockPopup = _SHIP_UNLOCK_POPUP.instantiate()
	layer.add_child(popup)
	popup.open(ship, die)
	await popup.closed
	layer.queue_free()


func _on_face_carved(_slot: int, face: int, _old_face: int) -> void:
	var counted: Array[ShipResource] = ShipUnlocks.counted_by_face(face as FateDie.Face)
	if counted.is_empty():
		return
	await get_tree().create_timer(_NOTICE_DELAY_SECONDS).timeout
	var display: FateDieDisplay = _die_display()
	if display == null:
		return
	var color: Color = FateFaceCatalog.color_of(face as FateDie.Face)
	for ship: ShipResource in counted:
		if not ship.unlock_carve_hint.is_empty():
			Juice.callout_at(display, display.die_position() + _NOTICE_OFFSET, tr(ship.unlock_carve_hint), color)


func _die_display() -> FateDieDisplay:
	var found: Array[Node] = get_tree().current_scene.find_children("*", "FateDieDisplay", true, false)
	return found[0] as FateDieDisplay if not found.is_empty() else null
