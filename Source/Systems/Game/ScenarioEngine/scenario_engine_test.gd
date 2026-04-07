extends Node2D

@onready var engine: ScenarioEngine = $ScenarioEngine

func _ready() -> void:
		# Register test modifiers.
		engine.add_modifier(DoubleDamageModifier.new())
		engine.add_modifier(ShieldAfterDealingDamageModifier.new(2))  # +2 shields

		# Create a fake DamageEvent (target = player for easy testing).
		var dmg := DamageEvent.new()
		dmg.actor   = Globals.player       # or any valid node
		dmg.targets = [Globals.player]     # targeting self, fine for testing
		dmg.amount  = 5

		engine.event_resolved.connect(func(event):
			if event is DamageEvent:
				print("Damage resolved. Final amount was: ", event.amount)
				# Should print 10 (5 * 2 from DoubleDamageModifier)
			elif event is ShieldEvent:
				print("Shield follow-up resolved. Amount: ", event.amount)
				# Should print 2 (from ShieldAfterDealingDamageModifier)
		)

		engine.queue_event(dmg)
		await engine.process_event_queue()
