class_name TextTokens
extends RefCounted
## Design numbers in content text, read from the content's own data.
##
## Content English names a number by a {placeholder} instead of writing it
## ("Apply {exposed} (exposed)"), so the text can never disagree with the
## effect that does the work, and a translator keeps the placeholder as they
## would any other. A step marks the number it owns with
##   text_token = &"exposed"           # the placeholder's name
##   text_token_value = "amount + 1"   # optional; see below
## on any resource embedded in the content's file (EffectData, EffectChain,
## ActivationResource). Names bind, not positions, so reordering a chain
## never rewires the text. Several steps may share a name when they carry the
## same number (Amplifier's two +2s); problems() reports them if they drift
## apart.
##
## text_token_value is a small Expression over the marking resource's own
## numeric properties: "-amount" (a cost stored as a negative), "range_max",
## "amount + 1". It may also name another token, for a number the text shows
## as a total ("or 9 if ..." on an ADD 5 after {damage} 4: "amount + damage").
## Left empty it reads the class's own number: _text_token_field() on the
## resource, or "amount".
##
## The content's root resource may add numbers that live on itself through
##   func _text_tokens() -> Dictionary    # {"countdown": 4}
##
## These are static design values, filled once when the text is shown. They
## differ from [data]...[/data] (a tile's run-time counters, Tile.
## fill_data_tokens) and from (die_N)/(keyword) tokens (drawn by
## Utils.format_text), which both run after this.

## The marking properties, on whichever resource owns the number.
const TOKEN_PROPERTY: StringName = &"text_token"
const VALUE_PROPERTY: StringName = &"text_token_value"

## A placeholder in text: {name}, lower snake case.
static var _placeholder: RegEx = RegEx.create_from_string(r"\{([a-z_][a-z0-9_]*)\}")
## Spans whose digits aren't prose: [data] counters, BBCode tags,
## (die_3)-style tokens and placeholders.
static var _not_prose: RegEx = RegEx.create_from_string(
		r"\[data\].*?\[/data\]|\[[^\]]*\]|\([a-z_0-9=.]+\)|\{[^}]*\}")
## A number written into prose, with any sign stuck to it ("+2", "-1"). The
## dash in a range ("4-6", "{high_min}-6") isn't a sign; mask_non_prose()
## leaves a placeholder's closing brace for that.
static var _literal: RegEx = RegEx.create_from_string(r"(?<![0-9A-Za-z}])[+-]?\d+(?:\.\d+)?")


## One number a resource contributes: the placeholder name, the value, and
## where it came from (for problem reports).
class Binding:
	extends RefCounted
	var name: String
	var value: Variant
	var source: Resource
	var error: String

	func _init(p_name: String, p_value: Variant, p_source: Resource, p_error: String = "") -> void:
		name = p_name
		value = p_value
		source = p_source
		error = p_error


## [param text] with each {name} replaced by its number from [param root].
## A name nothing binds stays as written, which problems() reports.
static func fill(text: String, root: Resource) -> String:
	if root == null or not "{" in text:
		return text
	var values: Dictionary = values_of(root)
	var result: String = text
	for found: RegExMatch in _placeholder.search_all(text):
		var name: String = found.get_string(1)
		if values.has(name):
			result = result.replace(found.get_string(0), values[name])
	return result


## Every number [param root] binds, by name, as the text shows it. Where
## several steps share a name the first one found wins.
static func values_of(root: Resource) -> Dictionary:
	var values: Dictionary = {}
	for binding: Binding in bindings_of(root):
		if binding.error.is_empty() and not values.has(binding.name):
			values[binding.name] = format_value(binding.value)
	return values


## Every binding in [param root]'s file, in a stable order: the root's own
## (_text_tokens()) first, then embedded resources depth first in property
## order.
static func bindings_of(root: Resource) -> Array[Binding]:
	var found: Array[Binding] = []
	if root == null:
		return found
	if root.has_method(&"_text_tokens"):
		var own: Dictionary = root.call(&"_text_tokens")
		for name: Variant in own:
			found.append(Binding.new(str(name), own[name], root))
	var file: String = root.resource_path.get_slice("::", 0)
	var marked: Array[Resource] = []
	_collect(root, file, marked, {})
	# Resolved in passes, so an expression can lean on another token
	# whatever order the steps come in.
	var resolved: Dictionary = {}
	for binding: Binding in found:
		resolved[binding.name] = binding.value
	var pending: Array[Resource] = marked
	while not pending.is_empty():
		var waiting: Array[Resource] = []
		var progressed: Array[Binding] = []
		for res: Resource in pending:
			var binding: Binding = _binding(res, resolved)
			if binding.error.is_empty():
				progressed.append(binding)
			else:
				waiting.append(res)
		for binding: Binding in progressed:
			found.append(binding)
			if not resolved.has(binding.name):
				resolved[binding.name] = binding.value
		if progressed.is_empty():
			for res: Resource in waiting:
				found.append(_binding(res, resolved))
			break
		pending = waiting
	return found


## The {name}s [param text] uses, in order, once each.
static func names_in(text: String) -> PackedStringArray:
	var names: PackedStringArray = []
	for found: RegExMatch in _placeholder.search_all(text):
		if not found.get_string(1) in names:
			names.append(found.get_string(1))
	return names


## What is wrong with [param text]'s placeholders against [param root]'s
## data: a name nothing binds, a binding whose expression fails, steps that
## share a name but disagree on the number. Empty when the text is sound.
static func problems(text: String, root: Resource) -> PackedStringArray:
	var out: PackedStringArray = []
	var by_name: Dictionary = {}
	for binding: Binding in bindings_of(root):
		if not binding.error.is_empty():
			out.append("{%s}: %s" % [binding.name, binding.error])
			continue
		var shown: String = format_value(binding.value)
		if by_name.has(binding.name) and by_name[binding.name] != shown:
			out.append("{%s} is %s on one step and %s on another" % [binding.name, by_name[binding.name], shown])
		elif not by_name.has(binding.name):
			by_name[binding.name] = shown
	for name: String in names_in(text):
		if not by_name.has(name):
			out.append("{%s} has no binding (no step's text_token is \"%s\")" % [name, name])
	return out


## The numbers still written into [param text]'s prose, sign included, in
## order. Digits inside tags, (tokens), {placeholders} and [data] counters
## don't count.
static func literal_numbers(text: String) -> PackedStringArray:
	var numbers: PackedStringArray = []
	for found: RegExMatch in _literal.search_all(mask_non_prose(text)):
		numbers.append(found.get_string(0))
	return numbers


## The pattern literal_numbers() finds, for tools that need the positions.
static func literal_regex() -> RegEx:
	return _literal


## [param text] with every non-prose span blanked out character for
## character, so positions still line up with the original. A placeholder
## keeps its closing brace, so the dash after it reads as a range, not a sign.
static func mask_non_prose(text: String) -> String:
	var masked: String = text
	for found: RegExMatch in _not_prose.search_all(text):
		var start: int = found.get_start(0)
		var length: int = found.get_end(0) - start
		var blank: String = " ".repeat(length)
		if found.get_string(0).begins_with("{"):
			blank = " ".repeat(length - 1) + "}"
		masked = masked.substr(0, start) + blank + masked.substr(start + length)
	return masked


## A number as the text shows it: whole numbers without a decimal point.
static func format_value(value: Variant) -> String:
	if value is float:
		var number: float = value
		if is_equal_approx(number, roundf(number)):
			return str(int(roundf(number)))
		return String.num(number, 2)
	return str(value)


## Gathers every resource in [param file] that marks a token.
static func _collect(res: Resource, file: String, found: Array[Resource], visited: Dictionary) -> void:
	if visited.has(res.get_instance_id()):
		return
	visited[res.get_instance_id()] = true
	var token: Variant = res.get(TOKEN_PROPERTY)
	if token != null and not String(token).is_empty():
		found.append(res)
	for property: Dictionary in res.get_property_list():
		var name: String = property.name
		if not (property.usage & PROPERTY_USAGE_STORAGE) or name == "script" or name.begins_with("metadata/"):
			continue
		var value: Variant = res.get(name)
		if value is Resource or value is Array or value is Dictionary:
			_collect_value(value, file, found, visited)


static func _collect_value(value: Variant, file: String, found: Array[Resource], visited: Dictionary) -> void:
	if value is Resource:
		var sub: Resource = value
		# Only scripted resources embedded in this file: another file (a
		# tile's upgraded_version) binds its own text, and engine resources
		# (SpriteFrames, textures) hold no design numbers.
		var embedded: bool = sub.resource_path.is_empty() or sub.resource_path.begins_with(file + "::")
		if embedded and sub.get_script() != null and not sub is Script:
			_collect(sub, file, found, visited)
	elif value is Array:
		for item: Variant in value:
			_collect_value(item, file, found, visited)
	elif value is Dictionary:
		var entries: Dictionary = value
		for key: Variant in entries:
			_collect_value(entries[key], file, found, visited)


## The number [param res] marks, from its expression over its own fields
## and the tokens already [param resolved].
static func _binding(res: Resource, resolved: Dictionary) -> Binding:
	var name: String = String(res.get(TOKEN_PROPERTY))
	var expression_text: String = str(res.get(VALUE_PROPERTY)) if res.get(VALUE_PROPERTY) != null else ""
	if expression_text.strip_edges().is_empty():
		expression_text = String(res.call(&"_text_token_field")) if res.has_method(&"_text_token_field") else "amount"
	var inputs: PackedStringArray = []
	var input_values: Array = []
	for property: Dictionary in res.get_property_list():
		if property.usage & PROPERTY_USAGE_STORAGE and property.type in [TYPE_INT, TYPE_FLOAT]:
			inputs.append(property.name)
			input_values.append(res.get(property.name))
	for token: String in resolved:
		if not token in inputs:
			inputs.append(token)
			input_values.append(resolved[token])
	var expression: Expression = Expression.new()
	if expression.parse(expression_text, inputs) != OK:
		return Binding.new(name, null, res, "can't read \"%s\": %s" % [expression_text, expression.get_error_text()])
	var value: Variant = expression.execute(input_values, null, false)
	if expression.has_execute_failed() or not (value is int or value is float):
		return Binding.new(name, null, res, "\"%s\" isn't a number here" % expression_text)
	return Binding.new(name, value, res)
