class_name Reward
extends Node2D

@export var dice_scene: PackedScene
@export var money_pickup_scene: PackedScene
@export var grid_slot_scene: PackedScene
@export var money_particle_scene: PackedScene
@export var bounding_box: CollisionShape2D

var rewards: Array[Node2D]

## What this offer holds, as save data: one entry per choice, left to right —
## {"tile": id}, {"dice": true}, {"slot": true} or {"money": amount}. Set the moment the offer
## is decided, not when it appears, so a checkpoint taken during the reveal
## delay still records it.
var items: Array = []

## Optional: force specific rewards (used by tutorial)
static var forced_rewards: Array[TileResource] = []

## Horizontal distance between the choices on offer.
const _REWARD_SPACING: int = 26

## Extra room either side of the offer that the ships leave clear.
const _FORMATION_PADDING: float = 4.0

## Gap between each choice left over popping once one is taken, left to
## right, so the offer reads as going out rather than vanishing in one frame.
const _DISMISS_STAGGER: float = 0.06

## One choice's whole pop: squash, stretch, gone.
const _DISMISS_POP_TIME: float = 0.28

## How long an offer the player jumps away from takes to shrink into the
## distance and fade, while it falls behind with the departing ships. Long
## enough to see it go: the drive spools up slowly, so for the first second
## or two everything is still close by.
const _LEFT_BEHIND_TIME: float = 2.6
## How small it has got by the time it's gone, as a share of its size.
const _LEFT_BEHIND_SCALE: float = 0.45
## The background layer an offer left behind falls with, the same one the
## departing ships match (EnemyManager._update_jumping_enemies), so the
## wreckage, its salvage and the ships all drop away together.
const _LEFT_BEHIND_PARALLAX: int = 1
## Fall speed, in pixels a second, when there's no background to match.
const _LEFT_BEHIND_FALLBACK_SPEED: float = 60.0

## Set once the offer is going: a choice was taken, or the player jumped away
## with it still up. The choices can no longer be taken.
var _dismissing: bool = false
## Set while an offer left behind by a jump is falling away.
var _falling_behind: bool = false


func _ready() -> void:
	hide()
	set_process(false)
	
	Events.jump.connect(_dismiss)


func _process(delta: float) -> void:
	if _falling_behind:
		global_position.y += delta * _left_behind_speed()


func _exit_tree() -> void:
	# Leaving with the whole scene (back to the menu) there's no formation left
	# to hand the space back to.
	if is_instance_valid(Globals.enemy_manager) and Globals.enemy_manager.is_inside_tree():
		Globals.enemy_manager.clear_formation_space(_formation_key())
	

## Whether the player can take a choice from this offer right now: it's on
## show and not being dismissed by a jump.
func can_take() -> bool:
	return is_visible_in_tree() and not _dismissing and not is_queued_for_deletion()


## Whether this offer has been decided but isn't on show yet: the pause
## between a ship paying out and its choices appearing.
func is_on_its_way() -> bool:
	return not visible and not _dismissing and not items.is_empty() and not is_queued_for_deletion()


func give_reward(reward_resource: RewardResource) -> void:
	#Globals.player.money += money
	var money: int = RNGManager.randi_range(
		RNGManager.Bucket.REWARDS, reward_resource.min_money, reward_resource.max_money
	)
	_spawn_money_particles(money)

	# Roll the offer now rather than after the pause, so it exists (and is
	# saveable) from the moment the ship pays out.
	var offered: Array[Node2D] = _build_offered_rewards(reward_resource)
	if offered.is_empty():
		queue_free()
		return

	_claim_formation_space(offered.size())
	await get_tree().create_timer(2).timeout
	_present(offered)


## Puts back an offer captured in a save. No payout: the money it came with was
## banked by the checkpoint that recorded it.
func restore_offer(saved_items: Array) -> void:
	var offered: Array[Node2D] = []
	for entry: Variant in saved_items:
		var node: Node2D = _node_for_item(entry)
		if node:
			offered.append(node)
	if offered.is_empty():
		queue_free()
		return
	_claim_formation_space(offered.size())
	_present(offered)


func _node_for_item(entry: Dictionary) -> Node2D:
	if entry.has("tile"):
		var path: String = ContentRegistry.get_tile_path(str(entry["tile"]))
		if path == "":
			return null
		var tile: Tile = Globals.tile_grid.create_tile(ResourceLoader.load(path))
		tile.on_offer = true
		items.append(entry)
		return tile
	if entry.has("dice"):
		items.append(entry)
		return dice_scene.instantiate()
	if entry.has("slot"):
		items.append(entry)
		return grid_slot_scene.instantiate()
	if entry.has("money") and money_pickup_scene:
		var pickup: MoneyPickup = money_pickup_scene.instantiate()
		pickup.amount = int(entry["money"])
		items.append(entry)
		return pickup
	return null


func _present(offered: Array[Node2D]) -> void:
	# Fade in
	show()
	var tween_time: float = 0.5
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(
		self, 
		"modulate:a", 
		1.0, 
		tween_time
	).from(0.0)
	
	bounding_box.shape.size.x = _REWARD_SPACING * offered.size()
	
	var total_length := _REWARD_SPACING * (offered.size() - 1)
	var start_offset := -total_length / 2

	for i in range(offered.size()):
		var reward: Node2D = offered[i]
		
		add_child(reward)
		
		reward.draggable.drag_started.connect(Events.show_systems.emit)
		reward.draggable.drag_ended.connect(_end_reward)
		reward.global_position = global_position + Vector2(start_offset,0) + Vector2(i * _REWARD_SPACING, 0)
		reward.draggable.home_position = reward.global_position
		reward.draggable.floating_enabled = true
		
		rewards.append(reward)
		

## Builds (but does not parent) everything this offer puts in front of the
## player, left to right: the tile/dice choices, then the money pickup if the
## resource authored one.
##
## Kept separate from the layout loop above so "what is on offer" is decided
## before any of it is on screen — the caller needs the final count to size
## the bounding box, and an empty result means there is no offer to show.
func _build_offered_rewards(reward_resource: RewardResource) -> Array[Node2D]:
	var offered: Array[Node2D] = []
	var possible_tile_rewards: Array[TileResource] = RewardManager.filter_by_minimum_rarity(
		Globals.reward_manager.get_possible_tile_rewards(),
		reward_resource.minimum_rarity
	)

	var offers_slot: bool = rolls_grid_slot(reward_resource)
	for i in range(reward_resource.num_of_rewards):
		if offers_slot and i == reward_resource.num_of_rewards - 1:
			offered.append(grid_slot_scene.instantiate())
			items.append({"slot": true})
			continue

		# Give the player a dice instead of a tile if we can't fit another tile, 
		# we can't give the player a tile they don't already have,
		# or randomly otherwise
		if Globals.tile_grid.find_available_grid_pos() == Vector2i(-1,-1)\
		or len(possible_tile_rewards) == 0\
		or RNGManager.randf(RNGManager.Bucket.REWARDS) <= reward_resource.dice_probability:
			offered.append(dice_scene.instantiate())
			items.append({"dice": true})
			
		# Make a tile reward
		else:
			var chosen_resource: TileResource
			if len(forced_rewards) > 0:
				chosen_resource = forced_rewards.pop_front()
			else:
				chosen_resource = Globals.reward_manager.pick_weighted_tile_reward(possible_tile_rewards)
			possible_tile_rewards.erase(chosen_resource)
			var tile: Tile = Globals.tile_grid.create_tile(chosen_resource)
			tile.on_offer = true
			offered.append(tile)
			items.append({"tile": ContentRegistry.get_tile_id(chosen_resource.resource_path)})

	if reward_resource.max_money_pickup > 0 and money_pickup_scene \
	and rolls_money_pickup(reward_resource):
		var pickup: MoneyPickup = money_pickup_scene.instantiate()
		pickup.amount = RNGManager.randi_range(
			RNGManager.Bucket.REWARDS,
			reward_resource.min_money_pickup,
			reward_resource.max_money_pickup
		)
		offered.append(pickup)
		items.append({"money": pickup.amount})

	return offered


## Whether this offer's last choice is a Grid Slot. A full grid always gets
## one while there's a sealed cell left; otherwise it's a roll, drawn only
## when it could come up, so a ship with no sealed cells rolls as it always has.
static func rolls_grid_slot(reward_resource: RewardResource) -> bool:
	var grid: TileGrid = Globals.tile_grid
	if reward_resource.num_of_rewards <= 0 or not grid.has_locked_cell():
		return false
	if not grid.has_free_cell():
		return true
	if reward_resource.grid_slot_probability <= 0.0:
		return false
	return RNGManager.randf(RNGManager.Bucket.REWARDS) < reward_resource.grid_slot_probability


## A certain pickup draws nothing, so offers authored before the chance existed
## keep the same rolls (and the same seeded runs) as they always had.
static func rolls_money_pickup(reward_resource: RewardResource) -> bool:
	if reward_resource.money_pickup_probability >= 1.0:
		return true
	return RNGManager.randf(RNGManager.Bucket.REWARDS) < reward_resource.money_pickup_probability


func _end_reward(draggable: Draggable, end_position: Vector2) -> void:
	if _dismissing:
		return
	var local_end_position: Vector2 = end_position - bounding_box.global_position
	# Don't do anything if the drag ended within the reward window
	if bounding_box.shape.get_rect().has_point(local_end_position):
		return

	var chosen_reward: Node = draggable.get_parent()
	# No cell for it: the offer stands, and the tile drifts back into it.
	if chosen_reward is Tile and not Globals.tile_grid.has_free_cell():
		Events.error_text_popup.emit("GRID FULL", end_position)
		return
	# A slot opens the sealed cell it's dropped on, and only that.
	var slot_cell: Vector2i = Globals.tile_grid.locked_cell_at(end_position)
	if chosen_reward is GridSlot and not Globals.tile_grid.is_cell_locked(slot_cell):
		Events.error_text_popup.emit(tr("ERROR_PICK_SEALED_CELL"), end_position)
		return
	draggable.drag_started.disconnect(Events.show_systems.emit)
	draggable.drag_ended.disconnect(_end_reward)
	
	
	if chosen_reward is Tile:
		Globals.tile_grid.receive_tile(chosen_reward, end_position)
		Events.reward_tile_taken.emit()
		
	elif chosen_reward is Dice:
		chosen_reward.reparent(Globals.player, true)
		Globals.player.dice_manager.add(chosen_reward)
		Globals.player.num_of_dice += 1
		
	elif chosen_reward is MoneyPickup:
		chosen_reward.claim()
		Events.reward_money_taken.emit()

	elif chosen_reward is GridSlot:
		chosen_reward.install(slot_cell)
		
	Events.reward_picked.emit()
	_clear_away(chosen_reward)


## An offer drops where the ship that paid it out used to be. Without holding
## that spot, the surviving ships close ranks straight over the top of it and
## the player has to pick a reward out from under a hull. The space is handed
## back when the offer goes, whether it was taken or the player jumped away.
func _claim_formation_space(count: int) -> void:
	if not is_instance_valid(Globals.enemy_manager):
		return

	var half_width: float = maxf($RichTextLabel.size.x, _REWARD_SPACING * count) * 0.5
	Globals.enemy_manager.reserve_formation_space(
		_formation_key(),
		global_position.x - half_width - _FORMATION_PADDING,
		global_position.x + half_width + _FORMATION_PADDING
	)


func _formation_key() -> StringName:
	return StringName("reward_%d" % get_instance_id())


## A choice was taken: the rest of the offer squashes, stretches and blinks
## out in turn, the way the environment monitor answers a rule biting, instead
## of snapping off screen the moment [param chosen] leaves it.
func _clear_away(chosen: Node) -> void:
	_dismissing = true
	# Nothing left to save: the offer is spent.
	items.clear()
	# A money pickup was paid out as particles; there's nothing left of it to
	# pop.
	if chosen is MoneyPickup:
		chosen.hide()

	var label: RichTextLabel = $RichTextLabel
	label.pivot_offset = (label.size / 2.0).round()
	_pop(label, 0.0)

	var delay: float = _DISMISS_STAGGER
	for reward: Node2D in rewards:
		if not is_instance_valid(reward) or reward == chosen or reward.get_parent() != self:
			continue
		# Keep it bobbing, but out of reach.
		reward.draggable.dragging_allowed = false
		reward.draggable.floating_enabled = true
		_pop(reward, delay)
		delay += _DISMISS_STAGGER

	get_tree().create_timer(delay + _DISMISS_POP_TIME).timeout.connect(queue_free)


## Jumping away abandons the offer. It's left behind with the wreck it came
## from: it falls away down the screen with the departing ships, shrinking
## into the distance and fading, instead of vanishing.
func _dismiss() -> void:
	if _dismissing:
		return
	_dismissing = true
	# Nothing left to save: the player left it behind.
	items.clear()

	# Still in the payout pause, nothing is on screen to animate.
	if not visible or rewards.is_empty():
		queue_free()
		return

	for reward: Node2D in rewards:
		if not is_instance_valid(reward) or reward.get_parent() != self:
			continue
		reward.draggable.dragging_allowed = false
		# Otherwise it keeps pulling its choice back to the spot it was
		# offered at, and the choice stays put while the offer falls away.
		reward.draggable.set_process(false)

	_falling_behind = true
	set_process(true)
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(self, "scale", Vector2.ONE * _LEFT_BEHIND_SCALE, _LEFT_BEHIND_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, _LEFT_BEHIND_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)


## How fast an offer left behind falls: the ships' speed, which ramps up
## with the background as the drive spools.
func _left_behind_speed() -> float:
	var background: BackgroundManager = Globals.background_manager
	if not is_instance_valid(background):
		return _LEFT_BEHIND_FALLBACK_SPEED
	return background.global_speed * background.get_parallax_speed(_LEFT_BEHIND_PARALLAX)


## Squashes [param node] wide, stretches it tall and thin, then pinches it to
## nothing with a puff of sparks where it was. The sparks go on the parent,
## which outlives this offer.
func _pop(node: CanvasItem, delay: float) -> void:
	var rest: Vector2 = node.scale
	var tween: Tween = node.create_tween()
	tween.tween_interval(delay)
	tween.tween_property(node, "scale", rest * Vector2(1.3, 0.7), _DISMISS_POP_TIME * 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", rest * Vector2(0.6, 1.5), _DISMISS_POP_TIME * 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	# Quad, not back: back-in winds up the wrong way first, which reads as a
	# stall at the peak of the stretch.
	tween.tween_property(node, "scale", rest * Vector2(0.0, 1.8), _DISMISS_POP_TIME * 0.4) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if node is Node2D:
		tween.tween_callback(func() -> void:
			Juice.sparkle(get_parent(), (node as Node2D).global_position, Color.WHITE, 6, 30.0)
		)
	tween.tween_callback(node.hide)


func _spawn_money_particles(amount: int) -> void:
	# Parented to this reward's own parent rather than to the reward, which is
	# freed as soon as the player takes something.
	MoneyParticle.spawn_payout(
		get_parent(), global_position, amount, money_particle_scene
	)
