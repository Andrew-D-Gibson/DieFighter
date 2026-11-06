class_name FateSelfWard
extends Modifier
## Keeps everything off "You" (FateSelf) that the player didn't aim at it:
## Burn ticks, splash, a stray hand-off, any area effect that slipped past
## the targeting handlers. A die spent while it's targeted still lands, and
## the die goes to it. Statuses, shields and heals never do (Duty's shields
## included): it has no side to help, and a status would only tick later as
## a hit nobody aimed.
##
## On the Reckoning's engine for the whole fight (ReckoningDirector). Priority
## 0: a cancellation, ahead of everything that would read the targets.


func _init() -> void:
	modifier_name = "Fate Self Ward"
	priority = 0


func on_before_event(event: EffectEvent, _engine: ScenarioEngine) -> void:
	if event.targets.is_empty() or FateSelf.is_self(event.actor):
		return
	var turned_away: bool = false
	for target: Node in event.targets.duplicate():
		if not FateSelf.is_self(target):
			continue
		if FateSelf.is_aimed_at(event, target) and not _never_lands(event):
			continue
		event.targets.erase(target)
		turned_away = true
	# A hand-off left with no one sends the die home, so it stays live.
	if turned_away and event.targets.is_empty() and event is not GiveDieToTargetEvent:
		event.canceled = true


static func _never_lands(event: EffectEvent) -> bool:
	return event is ApplyStatusEvent or event is ShieldEvent or event is HealEvent \
		or event is TransferStatusesEvent or event is MultiplyStatusesEvent
