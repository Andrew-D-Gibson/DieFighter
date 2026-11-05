class_name PiercingDamageEvent
extends DamageEvent
## A hit that goes straight past the shields to the hull (Leeching Shot's
## "Steal hull"). Being a DamageEvent, it is grown and shrunk like any other
## hit (an Amplifier, Weakened, Exposed) and Phased still dodges it; only the
## shields are skipped.


func soaked_by_shields() -> bool:
	return false
