class_name RetiredEffectHandler
extends EffectHandler
## Stands behind an effect whose mechanic is gone (the Reckoning's event
## horizon, its Saved Ship tile) but whose enum value has to stay, since the
## values after it are stored in .tres files by ordinal. Does nothing.


func apply(_data: EffectData, _context: EffectContext, _engine: ScenarioEngine) -> void:
	pass
