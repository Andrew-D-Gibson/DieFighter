## OpenShopHandler
## ============================================================
## A non-combat example handler showing that ScenarioEngine handles
## ALL scenario effects, not just combat.
##
## When a shop tile is activated, its EffectChainV2 contains an
## EffectData with category=SCENARIO_CONTROL, subtype=OPEN_SHOP.
## This handler creates an OpenShopEvent and enqueues it.
##
## OpenShopEvent.resolve() calls the shop UI to open itself.
## ============================================================

class_name OpenShopHandler
extends EffectHandler


func apply(_data: EffectData, context: EffectContext, engine: ScenarioEngine) -> void:
	var event := OpenShopEvent.new()
	event.actor = context.actor
	engine.enqueue_event(event)


# ── OpenShopEvent (defined inline for brevity) ─────────────────────────────────
## In your real project, put this in Source/Combat/Events/open_shop_event.gd.

class OpenShopEvent extends EffectEvent:
	func resolve(_engine: ScenarioEngine) -> void:
		# The shop UI listens to Events.open_shop (or however you open it).
		# This keeps all scenario control flowing through the engine queue.
		if Globals.scenario_manager:
			Globals.scenario_manager.open_shop()
