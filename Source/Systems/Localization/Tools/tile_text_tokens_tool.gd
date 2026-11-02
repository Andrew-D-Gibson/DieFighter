extends RefCounted
## Moves the numbers written into tile text onto the steps that own them
## (TextTokens), one colour family at a time. Run through tools/loc.sh tokens
## (tile_text_tokens_cli.gd loads this after the autoloads are up):
##
##   report  --family <f>               numbers still literal, token problems
##   convert --family <f> [--dry-run]   match each literal to a step, write
##                                      text_token there and {name} in the text
##   verify  --family <f> [--against <git ref>]
##                                      the filled text equals the English at
##                                      <ref> (default HEAD) for every tile
##
## <f> is red, blue, green, purple, yellow or all (the folder a tile's art is
## filed in, ColorSymbolBadge). Every line it prints starts with "tokens: ".
##
## Matching: each literal number in a description is compared with the numbers
## the tile's steps hold (amounts, multipliers, ranges, repeat counts, a
## check's threshold, the countdown). A SET overwritten before anything reads
## it doesn't count. When steps of one kind (same effect, same consumer, same
## field) share the value they all take the token, which keeps them in step;
## steps of different kinds are told apart by the unit after the number
## ("3 shields" -> SHIELD). A number that matches no step, or several that
## can't be told apart, is listed as unmatched with its candidates, for a
## hand edit. Every converted file is reloaded and its filled text compared
## with the old text before the change is kept.

const _TILE_DIR: String = "res://Source/Content/Tiles/TileResources/"
const _TEXT_FIELDS: Array[StringName] = [&"activation_description", &"description"]
const _FAMILIES: Array[String] = ["red", "blue", "green", "purple", "yellow"]
## Fields a step's number can live in, in the order they're tried.
const _NUMBER_FIELDS: Array[String] = ["amount", "multiplier", "range_min", "range_max"]

## Per consumer effect: the token's name and the words that follow its number
## in text. A status takes the status's own name and token instead.
const _ATTRIBUTE_NAMES: Dictionary = {
	"DAMAGE": ["damage", "damage"],
	"HEAL": ["heal", "hull|heal"],
	"SHIELD": ["shields", "shield"],
	"CHANGE_ENGINE_CHARGE": ["charge", "charge"],
	"SPEND_ENGINE_CHARGE": ["cost", "charge"],
	"ADD_OVERCHARGE": ["overcharge", "charge|overcharge"],
	"STEAL_MONEY": ["scrap", "scrap|credit"],
	"SPEND_SHIELDS": ["shield_cost", "shield"],
	"ION_DAMAGE": ["ion", "damage|ion"],
	"SIPHON_ENGINE_CHARGE": ["siphon", "charge"],
	"MULTIPLY_STATUSES": ["times", "x|times"],
	"SPEND_HULL": ["hull_cost", "hull"],
	"BOUNTY_DAMAGE": ["damage", "damage"],
	"ADD_EVASION": ["evasion", "evasion|%"],
}
const _OTHER_NAMES: Dictionary = {
	"ADD_AMPLIFIER_MODIFIER": ["boost", "to effects|effect"],
	"ADD_USES_REMAINING": ["uses", "use"],
	"COUNT_DOWN": ["count", "count|by"],
	"ADD_FAMILY_BOOST": ["boost", "damage|boost"],
	"FEED_HOLOGRAM": ["face", "hologram"],
	"SPAWN_HOLOGRAPHIC_DIE": ["face", "hologram"],
	"SPAWN_HOLOGRAM_FOR_ALLY": ["face", "hologram"],
	"ADD_TO_ACTIVATOR_VALUE": ["shift", ""],
	"HOLD_DIE_FOR_TURNS": ["turns", "turn"],
	"ADD_REPETITIONS": ["times", "time|x"],
	"LOCKOUT_TILE": ["locks", "lock|tile"],
	"INCREMENT_TILE_DATA": ["step", ""],
	"SET_TILE_DATA": ["value", ""],
	"ADD_DEATH_SAVE_MODIFIER": ["save", ""],
}

## Per condition and field (a conditional's own numbers).
const _CONDITION_NAMES: Dictionary = {
	"IF_CHARGE_AT_LEAST.amount": ["cost", "charge"],
	"IF_DICE_OWNED_IN_RANGE.range_max": ["dice", "or fewer|dice"],
	"IF_DICE_OWNED_IN_RANGE.range_min": ["dice", "or more|dice"],
	"IF_DIE_VALUE_IN_RANGE.range_min": ["low", ""],
	"IF_DIE_VALUE_IN_RANGE.range_max": ["high", ""],
}
## Per activation check (its threshold). A check that gates a cost shares the
## cost's name, so "Spend 3 charge" binds both and they can't drift apart.
const _CHECK_NAMES: Dictionary = {
	"CHARGE_AT_LEAST": ["cost", "charge"],
	"SHIELDS_AT_LEAST": ["shield_cost", "shield"],
	"DICE_OWNED_AT_MOST": ["dice", "dice|or fewer"],
	"SUMS_WITH_HELD_DIE": ["total", ""],
}

## Numbers that are rules of the game rather than a tile's data, so they stay
## literal: a countdown fires "At 0". Never matched, never reported.
const RULE_NUMBERS: PackedStringArray = ["0"]
## Tiles whose text keeps a literal number on purpose, with why. The lint
## (test_tile_text_tokens.gd) and report skip these numbers; a family pass
## adds a tile here only when the number really isn't in its data.
## Keyed by tile file name, then the literal as written, e.g.
##   "inverter": {"1": "die faces of the d6, not data", ...}
const LITERAL_EXEMPT: Dictionary = {}

var messages: PackedStringArray = []


## Runs one command; returns the exit status (1 when something needs a hand).
func run(args: Array) -> int:
	if args.is_empty():
		return _fail("usage: tokens <report|convert|verify> --family <red|blue|green|purple|yellow|all> [--dry-run] [--against <ref>]")
	var command: String = args.pop_front()
	var family: String = _option(args, "--family", "all")
	if family != "all" and not family in _FAMILIES:
		return _fail("unknown family '%s'" % family)
	var tiles: Array[String] = tile_files(family)
	match command:
		"report":
			return _report(tiles)
		"convert":
			return _convert(tiles, "--dry-run" in args)
		"verify":
			return _verify(tiles, _option(args, "--against", "HEAD"))
	return _fail("unknown command '%s'" % command)


## Every tile file in [param family] ("all" for every family), sorted.
static func tile_files(family: String) -> Array[String]:
	var files: Array[String] = []
	for file: String in DirAccess.get_files_at(_TILE_DIR):
		if not file.ends_with(".tres"):
			continue
		var path: String = _TILE_DIR + file
		if family == "all" or family_of(load(path)) == family:
			files.append(path)
	files.sort()
	return files


## "yellow" for a tile filed under YellowTiles, "" for one outside the families.
static func family_of(tile: TileResource) -> String:
	var family: ColorSymbolBadge.Family = ColorSymbolBadge.family_of_tile(tile)
	if family == ColorSymbolBadge.Family.NONE:
		return ""
	return String(ColorSymbolBadge.Family.find_key(family)).to_lower()


# ── report ─────────────────────────────────────────────────────────────────────

func _report(tiles: Array[String]) -> int:
	var dirty: int = 0
	for path: String in tiles:
		var tile: TileResource = load(path)
		var lines: PackedStringArray = []
		for field: StringName in _TEXT_FIELDS:
			var text: String = tile.get(field)
			for problem: String in TextTokens.problems(text, tile):
				lines.append("%s: %s" % [field, problem])
			var literals: PackedStringArray = literals_left(path, text)
			if not literals.is_empty():
				lines.append("%s: literal %s" % [field, ", ".join(literals)])
		if not lines.is_empty():
			dirty += 1
			for line: String in lines:
				_say("%s  %s" % [path.get_file(), line])
	_say("%d of %d tiles have literal numbers or token problems" % [dirty, tiles.size()])
	return 1 if dirty > 0 else 0


## The literal numbers in [param text] (of the tile file at [param path])
## that should be tokens: every one but RULE_NUMBERS and the tile's
## LITERAL_EXEMPT entries.
static func literals_left(path: String, text: String) -> PackedStringArray:
	var exempt: Dictionary = LITERAL_EXEMPT.get(path.get_file().get_basename(), {})
	var left: PackedStringArray = []
	for literal: String in TextTokens.literal_numbers(text):
		if not literal.trim_prefix("+").trim_prefix("-") in RULE_NUMBERS and not exempt.has(literal):
			left.append(literal)
	return left


# ── verify ─────────────────────────────────────────────────────────────────────

func _verify(tiles: Array[String], ref: String) -> int:
	var root: String = ProjectSettings.globalize_path("res://")
	var bad: int = 0
	for path: String in tiles:
		var output: Array = []
		var relative: String = path.trim_prefix("res://")
		if OS.execute("git", ["-C", root, "show", "%s:%s" % [ref, relative]], output, true) != 0:
			_say("%s  not at %s, skipped" % [path.get_file(), ref])
			continue
		var old_file: String = "".join(PackedStringArray(output))
		var tile: TileResource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
		for field: StringName in _TEXT_FIELDS:
			var old_text: String = read_property(old_file, field)
			var filled: String = TextTokens.fill(tile.get(field), tile)
			if filled != old_text:
				bad += 1
				_say("%s  %s differs from %s:\n    was: %s\n    now: %s" % [path.get_file(), field, ref, old_text, filled])
	_say("%d of %d tiles read as they did at %s" % [tiles.size() - bad, tiles.size(), ref] if bad == 0
		else "%d text fields differ from %s" % [bad, ref])
	return 1 if bad > 0 else 0


# ── convert ────────────────────────────────────────────────────────────────────

## A number some step (or the tile) holds, that a literal could be.
class Slot:
	extends RefCounted
	var res: Resource
	var field: String
	var value: float
	## Steps of one kind share a token when they share a value.
	var kind: String
	## The token's name, before de-duplication.
	var name: String
	## Words that follow this number in text (regex alternatives).
	var unit: String
	## True when the number reaches the player's own ship (TARGET_PLAYER).
	var on_self: bool


## One literal number's match: the slots it binds and how.
class Match:
	extends RefCounted
	var start: int
	var end: int
	var slots: Array[Slot] = []
	var name: String
	## The expression written as text_token_value ("" = the default field).
	var expression: String
	## True when the text shows the number with its sign flipped.
	var negated: bool
	## True when this repeats an earlier literal's token (worth a look).
	var reused: bool
	## True when nothing named the number (token "n"): matched on value
	## alone, so worth a look.
	var suspect: bool


func _convert(tiles: Array[String], dry_run: bool) -> int:
	var total: int = 0
	var matched: int = 0
	var clean_tiles: int = 0
	var unmatched_lines: PackedStringArray = []
	for path: String in tiles:
		var tile: TileResource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
		var slots: Array[Slot] = _slots_of(tile)
		var used: Dictionary = {}
		# Names already in use, and whether each is your own ship's number.
		var taken: Dictionary = {}
		var own: Dictionary = tile._text_tokens()
		for name: String in TextTokens.values_of(tile):
			if not own.has(name):
				taken[name] = false
		var new_texts: Dictionary = {}
		var bindings: Array[Match] = []
		var tile_unmatched: int = 0
		for field: StringName in _TEXT_FIELDS:
			var text: String = tile.get(field)
			var masked: String = TextTokens.mask_non_prose(text)
			var matches: Array[Match] = []
			for literal: RegExMatch in TextTokens.literal_regex().search_all(masked):
				if literal.get_string(0).trim_prefix("+").trim_prefix("-") in RULE_NUMBERS \
						or (LITERAL_EXEMPT.get(path.get_file().get_basename(), {}) as Dictionary).has(literal.get_string(0)):
					continue
				total += 1
				var found: Match = _match_literal(literal, masked, slots, used, taken, bindings + matches)
				if found == null:
					tile_unmatched += 1
					unmatched_lines.append(_describe_unmatched(path, field, text, literal, slots))
					continue
				matched += 1
				matches.append(found)
			var new_text: String = text
			matches.reverse()
			for found: Match in matches:
				new_text = new_text.substr(0, found.start) + "{%s}" % found.name + new_text.substr(found.end)
			matches.reverse()
			bindings.append_array(matches)
			if new_text != text:
				new_texts[field] = new_text
		if tile_unmatched == 0:
			clean_tiles += 1
		if bindings.is_empty():
			continue
		var summary: PackedStringArray = []
		for found: Match in bindings:
			var shown: float = -found.slots[0].value if found.negated else found.slots[0].value
			summary.append("{%s}=%s%s%s" % [found.name, TextTokens.format_value(shown),
				"" if found.slots.size() == 1 else " (%d steps)" % found.slots.size(),
				" (CHECK: reuses an earlier token)" if found.reused
					else " (CHECK: matched on value alone)" if found.suspect else ""])
		_say("%s %s  %s" % ["would convert" if dry_run else "converted", path.get_file(), "  ".join(summary)])
		if not dry_run:
			var error: String = _write(path, tile, new_texts, bindings)
			if not error.is_empty():
				_say("ERROR %s: %s (file left unchanged)" % [path.get_file(), error])
	for line: String in unmatched_lines:
		_say(line)
	var rate: float = 100.0 * matched / total if total > 0 else 100.0
	_say("matched %d of %d literal numbers (%.0f%%); %d of %d tiles fully matched" % [matched, total, rate, clean_tiles, tiles.size()])
	return 0 if matched == total else 1


func _match_literal(literal: RegExMatch, masked: String, slots: Array[Slot], used: Dictionary, taken: Dictionary, earlier: Array[Match]) -> Match:
	var raw: String = literal.get_string(0)
	var sign: String = raw.left(1) if raw.left(1) in ["+", "-"] else ""
	var magnitude: float = raw.trim_prefix("+").trim_prefix("-").to_float()
	var after: String = _words_after(masked, literal.get_end(0))
	# Tried in order: the signed value, then the bare number (a "+2" bonus, a
	# "-1" written before an amount of 1), then the negation (a cost of 3
	# stored as -3).
	var tries: Array = []
	if sign == "-":
		tries.append([-magnitude, true, false])
	tries.append([magnitude, false, false])
	if sign != "-":
		tries.append([-magnitude, false, true])
	for attempt: Array in tries:
		var value: float = attempt[0]
		var candidates: Array[Slot] = []
		for slot: Slot in slots:
			if not used.has(slot) and is_equal_approx(slot.value, value):
				candidates.append(slot)
		var group: Array[Slot] = _pick_group(candidates, after)
		if group.is_empty():
			continue
		var found: Match = Match.new()
		var takes_sign: bool = attempt[1]
		found.start = literal.get_start(0) + (0 if takes_sign or sign.is_empty() else 1)
		found.end = literal.get_end(0)
		found.slots = group
		var negated: bool = attempt[2]
		found.negated = negated
		var field: String = group[0].field
		var default_field: String = String(group[0].res.call(&"_text_token_field")) \
				if group[0].res.has_method(&"_text_token_field") else "amount"
		if group[0].res is TileResource:
			default_field = field
		found.expression = ("-" + field) if negated else ("" if field == default_field else field)
		found.name = group[0].name if group[0].res is TileResource else _unique_name(group[0], taken)
		taken[found.name] = group[0].on_self
		found.suspect = group[0].name == "n"
		for slot: Slot in group:
			used[slot] = true
		return found
	# Nothing left unbound: the same number written twice for one step
	# ("3 damage, +3 per feed" both read the multiplier). Reused only when it
	# is unambiguous, and flagged for a look.
	var same: Array[Match] = []
	for previous: Match in earlier:
		var shown: float = -previous.slots[0].value if previous.negated else previous.slots[0].value
		if is_equal_approx(absf(shown), magnitude) and not same.any(func(m: Match) -> bool: return m.name == previous.name):
			same.append(previous)
	if same.size() == 1:
		var reused: Match = Match.new()
		var shown_sign: bool = sign == "-" and (-same[0].slots[0].value if same[0].negated else same[0].slots[0].value) < 0
		reused.start = literal.get_start(0) + (0 if shown_sign or sign.is_empty() else 1)
		reused.end = literal.get_end(0)
		reused.slots = same[0].slots
		reused.name = same[0].name
		reused.expression = same[0].expression
		reused.negated = same[0].negated
		reused.reused = true
		return reused
	return null


## The candidates one literal binds: all of them when they are one kind,
## else the one kind whose unit follows the number. Empty when none or
## ambiguous.
func _pick_group(candidates: Array[Slot], after: String) -> Array[Slot]:
	var kinds: Dictionary = {}
	for slot: Slot in candidates:
		if not kinds.has(slot.kind):
			kinds[slot.kind] = [] as Array[Slot]
		(kinds[slot.kind] as Array[Slot]).append(slot)
	if kinds.size() == 1:
		return kinds.values()[0]
	var fitting: Array = []
	for kind: String in kinds:
		var unit: String = (kinds[kind] as Array[Slot])[0].unit
		if not unit.is_empty() and RegEx.create_from_string("^(%s)" % unit).search(after) != null:
			fitting.append(kinds[kind])
	if fitting.is_empty():
		fitting = kinds.values()
	if fitting.size() > 1:
		# "Apply 1 (burn) ... Apply 1 (burn) to you": the words up to the
		# sentence's end say whose ship.
		var to_you: bool = after.get_slice(".", 0).contains(" to you")
		var by_ship: Array = fitting.filter(func(group: Array) -> bool: return (group[0] as Slot).on_self == to_you)
		if not by_ship.is_empty():
			fitting = by_ship
	if fitting.size() == 1:
		return fitting[0]
	# Kinds that name the number alike are one number shown once (a check's
	# threshold and the cost it gates): they take one token and must agree.
	var merged: Array[Slot] = []
	for group: Array in fitting:
		if (group[0] as Slot).name != (fitting[0][0] as Slot).name:
			return [] as Array[Slot]
		merged.append_array(group)
	return merged


## The prose right after a number, lower case, BBCode dropped, for unit
## matching ("3 [color=blue]shields[/color]" -> "shields").
func _words_after(masked: String, from: int) -> String:
	var rest: String = masked.substr(from, 40).strip_edges(true, false)
	return rest.to_lower()


func _unique_name(slot: Slot, taken: Dictionary) -> String:
	var base: String = slot.name
	if slot.on_self and taken.has(base) and not taken[base]:
		base = "self_" + base
	var name: String = base
	var counter: int = 2
	while taken.has(name):
		name = "%s_%d" % [base, counter]
		counter += 1
	return name


func _describe_unmatched(path: String, field: StringName, text: String, literal: RegExMatch, slots: Array[Slot]) -> String:
	var start: int = maxi(0, literal.get_start(0) - 24)
	var context: String = text.substr(start, literal.get_end(0) - start + 24).replace("\n", " ")
	var near: PackedStringArray = []
	var magnitude: float = absf(literal.get_string(0).to_float())
	for slot: Slot in slots:
		if is_equal_approx(absf(slot.value), magnitude):
			near.append("%s.%s=%s (%s)" % [_where(slot.res), slot.field, TextTokens.format_value(slot.value), slot.kind])
	return "unmatched %s %s  '%s' in \"...%s...\"  candidates: %s" % [
		path.get_file(), field, literal.get_string(0), context, ", ".join(near) if not near.is_empty() else "none"]


func _where(res: Resource) -> String:
	var id: String = res.resource_path.get_slice("::", 1)
	return id if not id.is_empty() else "tile"


# ── slots ──────────────────────────────────────────────────────────────────────

func _slots_of(tile: TileResource) -> Array[Slot]:
	var slots: Array[Slot] = []
	if tile.countdown > 0:
		slots.append(_slot(tile, "countdown", tile.countdown, "tile.countdown", ["countdown", ""], false))
	for check: ActivationResource in tile.activation_checks:
		if check != null and _embedded(check, tile) and check.threshold != 0:
			var type_name: String = String(ActivationResource.ActivationType.find_key(check.type))
			slots.append(_slot(check, "threshold", check.threshold, "check." + type_name,
				_CHECK_NAMES.get(type_name, ["threshold", ""]), false))
	_chain_slots(tile.effect_chain, tile, slots)
	for event: TileEvent in tile.event_responses:
		_chain_slots(tile.event_responses[event], tile, slots)
	return slots


func _chain_slots(chain: EffectChain, tile: TileResource, slots: Array[Slot]) -> void:
	if chain == null or not _embedded(chain, tile):
		return
	if chain.base_repetitions != 1:
		slots.append(_slot(chain, "base_repetitions", chain.base_repetitions, "chain.repetitions", ["times", "time|x|tile"], false))
	_list_slots(chain.effects, tile, slots, [], [], false)
	var conditions: Array[EffectData] = []
	conditions.assign(chain.repetition_conditions)
	_list_slots(conditions, tile, slots, [], [], false)


## [param before] and [param after] are the steps that run before and after
## [param steps]: a conditional's branch reads the amount its parent list set
## up, and hands its own amount to the step after the conditional.
func _list_slots(steps: Array[EffectData], tile: TileResource, slots: Array[Slot],
		before: Array[EffectData], after: Array[EffectData], on_self_at_start: bool) -> void:
	var on_self: bool = on_self_at_start
	for i: int in steps.size():
		var step: EffectData = steps[i]
		if step == null or not _embedded(step, tile):
			continue
		if step.category == EffectEnums.Category.TARGETING:
			on_self = step.subtype == EffectEnums.TargetingSubtype.TARGET_PLAYER
		var earlier: Array[EffectData] = before.duplicate()
		earlier.append_array(steps.slice(0, i))
		var later: Array[EffectData] = []
		later.assign(steps.slice(i + 1))
		later.append_array(after)
		if step.category != EffectEnums.Category.AUDIO_VISUAL:
			_step_slots(step, earlier, later, slots, on_self)
		if step is ConditionalEffectData:
			var conditional: ConditionalEffectData = step
			var inner_before: Array[EffectData] = earlier.duplicate()
			inner_before.append(step)
			_list_slots(conditional.if_true_effects, tile, slots, inner_before, later, on_self)
			_list_slots(conditional.if_false_effects, tile, slots, inner_before, later, on_self)


func _step_slots(step: EffectData, earlier: Array[EffectData], later: Array[EffectData], slots: Array[Slot], on_self: bool) -> void:
	var consumer: EffectData = step
	var consumer_on_self: bool = on_self
	if step.category == EffectEnums.Category.AMOUNT_MODIFIER:
		var read: Array = _consumer(later, on_self)
		if read.is_empty():
			return # overwritten or never read: not a number the player sees
		consumer = read[0]
		consumer_on_self = read[1]
	for field: String in _NUMBER_FIELDS:
		if not EffectCatalog.uses_field(step.category, step.subtype, field):
			continue
		var value: float = float(step.get(field))
		if field == "multiplier" and is_equal_approx(value, 1.0):
			continue
		var naming: Array = _naming(consumer, field)
		var kind: String = "%s/%s.%s" % [_effect_name(step), field, _effect_name(consumer)]
		if consumer.category == EffectEnums.Category.ATTRIBUTE_CHANGE \
				and consumer.subtype == EffectEnums.AttributeChangeSubtype.APPLY_STATUS:
			kind += ":" + consumer.string_param
		if consumer_on_self:
			kind += "@you"
		if step.category == EffectEnums.Category.AMOUNT_MODIFIER \
				and step.subtype in [EffectEnums.AmountModifierSubtype.ADD, EffectEnums.AmountModifierSubtype.MULTIPLY] \
				and _reads_die_value(earlier):
			naming = ["bonus", ""] if step.subtype == EffectEnums.AmountModifierSubtype.ADD else ["times", "x"]
		slots.append(_slot(step, field, value, kind, naming, consumer_on_self))


## The step in [param later] that reads the running amount, and whether it
## acts on your own ship: [step, on_self], or [] when another SET replaces
## the amount first (or nothing reads it).
func _consumer(later: Array[EffectData], on_self: bool) -> Array:
	var targets_you: bool = on_self
	for next: EffectData in later:
		if next == null or next.category == EffectEnums.Category.AUDIO_VISUAL:
			continue
		if next.category == EffectEnums.Category.TARGETING:
			targets_you = next.subtype == EffectEnums.TargetingSubtype.TARGET_PLAYER
			continue
		if next.category == EffectEnums.Category.AMOUNT_MODIFIER:
			if _replaces_amount(next):
				return []
			continue
		if next is ConditionalEffectData:
			# A branch may adjust the amount for the reader after it; if both
			# branches replace it, this amount never shows.
			var branches: ConditionalEffectData = next
			if _any_replaces(branches.if_true_effects) and _any_replaces(branches.if_false_effects):
				return []
			continue
		return [next, targets_you]
	return []


func _any_replaces(steps: Array[EffectData]) -> bool:
	for step: EffectData in steps:
		if step and step.category == EffectEnums.Category.AMOUNT_MODIFIER and _replaces_amount(step):
			return true
	return false


## True for an amount modifier that throws the running amount away.
func _replaces_amount(step: EffectData) -> bool:
	return step.subtype == EffectEnums.AmountModifierSubtype.SET \
		or String(EffectEnums.AmountModifierSubtype.find_key(step.subtype)).begins_with("SET_")


## True when the last amount set before this point came from the die, so an
## ADD/MULTIPLY reads as "die +N" / "Nx die".
func _reads_die_value(earlier: Array[EffectData]) -> bool:
	for j: int in range(earlier.size() - 1, -1, -1):
		var previous: EffectData = earlier[j]
		if previous and previous.category == EffectEnums.Category.AMOUNT_MODIFIER and _replaces_amount(previous):
			return previous.subtype == EffectEnums.AmountModifierSubtype.SET_TO_DIE_VALUE
	return false


## [name, unit words] for the effect that reads a number from [param field].
func _naming(step: EffectData, field: String) -> Array:
	var subtype_name: String = String(EffectEnums.subtype_enum(step.category).find_key(step.subtype))
	if step.category == EffectEnums.Category.CONDITIONAL:
		var key: String = "%s.%s" % [subtype_name, field]
		return _CONDITION_NAMES.get(key, ["low" if field == "range_min" else "high" if field == "range_max" else "n", ""])
	if field == "range_max" and step.category == EffectEnums.Category.TILE_CONTROL:
		return ["cap", "\\+|up to"]
	if step.category == EffectEnums.Category.ATTRIBUTE_CHANGE:
		if step.subtype in [EffectEnums.AttributeChangeSubtype.APPLY_STATUS, EffectEnums.AttributeChangeSubtype.CLEAR_STATUS] \
				and not step.string_param.is_empty():
			return [step.string_param.to_snake_case(), "\\(%s" % step.string_param]
		if _ATTRIBUTE_NAMES.has(subtype_name):
			return _ATTRIBUTE_NAMES[subtype_name]
	if _OTHER_NAMES.has(subtype_name):
		return _OTHER_NAMES[subtype_name]
	return ["n", ""]


func _effect_name(step: EffectData) -> String:
	return "%s.%s" % [EffectEnums.Category.find_key(step.category),
		EffectEnums.subtype_enum(step.category).find_key(step.subtype)]


func _slot(res: Resource, field: String, value: float, kind: String, naming: Array, on_self: bool) -> Slot:
	var slot: Slot = Slot.new()
	slot.res = res
	slot.field = field
	slot.value = value
	slot.kind = kind
	slot.name = naming[0]
	slot.unit = naming[1]
	slot.on_self = on_self
	return slot


## Only resources written in the tile's own file can carry its tokens.
func _embedded(res: Resource, tile: TileResource) -> bool:
	return res.resource_path.begins_with(tile.resource_path + "::")


# ── writing ────────────────────────────────────────────────────────────────────

## Writes the new text and the step markings into [param path], then reloads
## it and checks the filled text reads exactly as before. Restores the file
## and returns why when it doesn't.
func _write(path: String, tile: TileResource, new_texts: Dictionary, bindings: Array[Match]) -> String:
	var original: String = FileAccess.get_file_as_string(path)
	var content: String = original
	for field: StringName in new_texts:
		var replaced: String = replace_property(content, field, tile.get(field), new_texts[field])
		if replaced.is_empty():
			return "couldn't find its %s line" % field
		content = replaced
	for found: Match in bindings:
		if found.reused:
			continue
		for slot: Slot in found.slots:
			if slot.res is TileResource:
				continue # the tile's own numbers bind by name (_text_tokens)
			var id: String = slot.res.resource_path.get_slice("::", 1)
			var lines: PackedStringArray = ["text_token = &\"%s\"" % found.name]
			if not found.expression.is_empty():
				lines.append("text_token_value = \"%s\"" % found.expression)
			var marked: String = _mark_sub_resource(content, id, lines)
			if marked.is_empty():
				return "couldn't find sub-resource %s" % id
			content = marked
	_save(path, content)
	var fresh: TileResource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	for field: StringName in _TEXT_FIELDS:
		var filled: String = TextTokens.fill(fresh.get(field), fresh) if fresh else ""
		if fresh == null or filled != tile.get(field) or not TextTokens.problems(fresh.get(field), fresh).is_empty():
			_save(path, original)
			return "%s would read \"%s\", not \"%s\"" % [field, filled, tile.get(field)]
	return ""


func _save(path: String, content: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(content)
	file.close()


## Adds [param lines] to the [sub_resource] section with [param id], before
## its metadata (where the inspector would put them). "" if there's none.
func _mark_sub_resource(content: String, id: String, lines: PackedStringArray) -> String:
	var header: String = "id=\"%s\"]\n" % id
	var start: int = content.find(header)
	if start < 0:
		return ""
	start += header.length()
	var end: int = content.find("\n\n", start)
	if end < 0:
		end = content.length()
	var section: String = content.substr(start, end - start)
	var kept: PackedStringArray = []
	for line: String in section.split("\n"):
		if not line.begins_with("text_token"):
			kept.append(line)
	var at: int = kept.size()
	for i: int in kept.size():
		if kept[i].begins_with("metadata/"):
			at = i
			break
	for i: int in range(lines.size() - 1, -1, -1):
		kept.insert(at, lines[i])
	return content.substr(0, start) + "\n".join(kept) + content.substr(end)


## [param content] with the root resource's [param property] string changed
## from [param old_value] to [param new_value]. "" when the line isn't there
## or doesn't hold [param old_value].
static func replace_property(content: String, property: StringName, old_value: String, new_value: String) -> String:
	var found: RegExMatch = _property_regex(property).search(content)
	if found == null or _unescape(found.get_string(1)) != old_value:
		return ""
	return content.substr(0, found.get_start(1)) + _escape(new_value) + content.substr(found.get_end(1))


## The root resource's [param property] string as written in a .tres file's
## [param content], "" when it isn't set.
static func read_property(content: String, property: StringName) -> String:
	var found: RegExMatch = _property_regex(property).search(content)
	return _unescape(found.get_string(1)) if found else ""


static func _property_regex(property: StringName) -> RegEx:
	return RegEx.create_from_string("(?m)^%s = \"((?:[^\"\\\\]|\\\\.)*)\"" % property)


## Godot writes .tres strings with only backslash and quote escaped.
static func _escape(text: String) -> String:
	return text.replace("\\", "\\\\").replace("\"", "\\\"")


static func _unescape(text: String) -> String:
	var plain: String = ""
	var i: int = 0
	while i < text.length():
		if text[i] == "\\" and i + 1 < text.length():
			i += 1
		plain += text[i]
		i += 1
	return plain


# ── output ─────────────────────────────────────────────────────────────────────

func _option(args: Array, flag: String, fallback: String) -> String:
	var at: int = args.find(flag)
	return args[at + 1] if at >= 0 and at + 1 < args.size() else fallback


func _say(line: String) -> void:
	messages.append(line)


func _fail(line: String) -> int:
	_say("ERROR " + line)
	return 1
