class_name ReckoningQueue
extends RefCounted
## The Reckoning's queue (RECKONING_ENDINGS.md §2): the run played backwards,
## one wave per encounter, last in first out. Each wave is the echoes of the
## ships destroyed there and the ships saved or spared there, so a fight
## where the player killed two pirates and saved the Hauler comes back as all
## three together. The very first kill comes last, alone.
##
## Pure: built from FateLedger's kills and allies, so it can be read (and
## tested) without a fight. A wave is a Dictionary:
##   "encounter": the encounter index it replays (-1 for a save from before
##                encounters were kept, or the first kill's lone wave)
##   "echoes":    Array[String], the enemy ids of the ships destroyed there
##   "civilian":  true when one of those died on the civilian side
##   "allies":    Array[Dictionary], the FateLedger.allies entries saved there
##   "debts":     Array[Dictionary], the entries spared there
##   "first":     true on the closing wave of the very first kill

## The most encounters whose echoes come back, besides the first kill. Older
## encounters still send the ships saved in them: the cap trims the fight,
## never who the player can save.
const MAX_ENCOUNTERS: int = 12


## The waves for a run that destroyed [param kills] and saved or spared
## [param allies] (FateLedger's lists), in the order they arrive. Kills of the
## faction ids in [param skip] stay dead (the Rearguard, for a player who
## never paid a tithe). A run saved before encounters were kept falls back to
## the old Tally (FateLedger.tally_waves), with every ally waiting from the
## start.
static func build(kills: Array[Dictionary], allies: Array[Dictionary],
		skip: Array[String] = [], max_encounters: int = MAX_ENCOUNTERS) -> Array[Dictionary]:
	var kept: Array[Dictionary] = []
	for entry: Dictionary in kills:
		if str(entry.get("faction", "")) in skip or str(entry.get("enemy", "")).is_empty():
			continue
		kept.append(entry)
	if not _all_have_encounters(kept) or not _all_have_encounters(allies):
		return _legacy(kept, allies, skip)

	var by_encounter: Dictionary[int, Dictionary] = {}
	var first: Dictionary = kept[0] if not kept.is_empty() else {}
	for i: int in range(1, kept.size()):
		var kill: Dictionary = kept[i]
		var wave: Dictionary = _wave_for(by_encounter, int(kill["encounter"]))
		(wave["echoes"] as Array[String]).append(str(kill["enemy"]))
		if bool(kill.get("civilian", false)):
			wave["civilian"] = true
	for ally: Dictionary in allies:
		var wave: Dictionary = _wave_for(by_encounter, int(ally["encounter"]))
		var list: String = "debts" if str(ally.get("kind", "")) == FateLedger.KIND_DEBT else "allies"
		(wave[list] as Array[Dictionary]).append(ally)

	var order: Array[int] = by_encounter.keys()
	order.sort()
	order.reverse()
	var waves: Array[Dictionary] = []
	var with_echoes: int = 0
	for encounter: int in order:
		var wave: Dictionary = by_encounter[encounter]
		if not (wave["echoes"] as Array[String]).is_empty():
			with_echoes += 1
			if with_echoes > max_encounters:
				(wave["echoes"] as Array[String]).clear()
				wave["civilian"] = false
		if is_empty_wave(wave):
			continue
		waves.append(wave)

	if not first.is_empty():
		var last: Dictionary = _new_wave(-1)
		(last["echoes"] as Array[String]).append(str(first["enemy"]))
		last["civilian"] = bool(first.get("civilian", false))
		last["first"] = true
		waves.append(last)
	return waves


## Whether [param wave] brings nobody at all.
static func is_empty_wave(wave: Dictionary) -> bool:
	return (wave.get("echoes", []) as Array).is_empty() and (wave.get("allies", []) as Array).is_empty() \
		and (wave.get("debts", []) as Array).is_empty()


static func _new_wave(encounter: int) -> Dictionary:
	var echoes: Array[String] = []
	var saved: Array[Dictionary] = []
	var spared: Array[Dictionary] = []
	return {"encounter": encounter, "echoes": echoes, "civilian": false, "allies": saved, "debts": spared, "first": false}


static func _wave_for(by_encounter: Dictionary[int, Dictionary], encounter: int) -> Dictionary:
	if not by_encounter.has(encounter):
		by_encounter[encounter] = _new_wave(encounter)
	return by_encounter[encounter]


static func _all_have_encounters(entries: Array[Dictionary]) -> bool:
	for entry: Dictionary in entries:
		if not entry.has("encounter"):
			return false
	return true


## The Reckoning as a run saved before encounters were kept knew it: the
## kills backwards in waves of three, and every saved ship waiting from the
## first wave on.
static func _legacy(kills: Array[Dictionary], allies: Array[Dictionary], skip: Array[String]) -> Array[Dictionary]:
	var waves: Array[Dictionary] = []
	var tally: Array[Array] = FateLedger.tally_waves(kills, skip)
	for i: int in tally.size():
		var wave: Dictionary = _new_wave(-1)
		(wave["echoes"] as Array[String]).assign(tally[i])
		wave["first"] = i == tally.size() - 1
		waves.append(wave)
	if allies.is_empty():
		return waves
	if waves.is_empty() or bool(waves[0]["first"]):
		waves.push_front(_new_wave(-1))
	for ally: Dictionary in allies:
		var list: String = "debts" if str(ally.get("kind", "")) == FateLedger.KIND_DEBT else "allies"
		(waves[0][list] as Array[Dictionary]).append(ally)
	return waves
