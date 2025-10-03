extends GPUParticles2D

func _ready() -> void:
	Events.start_scenario.connect(_update_particle_amount)
	Events.engine_charge_changed.connect(_update_particle_amount)
	

func _update_particle_amount() -> void:
	var engine_charge_percentage: float = Globals.player.engine_charge / float(Globals.player.max_engine_charge)

	self.amount_ratio = engine_charge_percentage
