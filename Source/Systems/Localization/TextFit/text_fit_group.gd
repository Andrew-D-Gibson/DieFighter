class_name TextFitGroup
extends RefCounted
## Fitted texts that are drawn at one size: whatever scale the tightest of
## them needs, they all take. A row of tabs, a bar of buttons or a column of
## options reads as a set; one German title shrunk among full-size
## neighbours looks like a mistake.
##
## Give each member's TextFitter or TextFitBox the same group (its `group`
## property). Any member's change re-solves the whole group, once, at the end
## of the frame.

## The scale every member draws at now.
var scale: float = 1.0

## [best_scale: Callable, fit_at: Callable] per member; a member's callables
## go invalid when it's freed, and it drops out.
var _members: Array[Array] = []
var _queued: bool = false


## Adds a member: [param best_scale] returns the largest scale it fits at on
## its own; [param fit_at] fits it at most at the scale it's given.
func add(best_scale: Callable, fit_at: Callable) -> void:
	_members.append([best_scale, fit_at])
	request()


func remove(fit_at: Callable) -> void:
	_members = _members.filter(func(member: Array) -> bool: return member[1] != fit_at)
	request()


## Re-solves the group at the end of the frame (once, however many members
## ask).
func request() -> void:
	if _queued:
		return
	_queued = true
	_resolve.call_deferred()


func _resolve() -> void:
	_queued = false
	_members = _members.filter(func(member: Array) -> bool:
		return (member[0] as Callable).is_valid() and (member[1] as Callable).is_valid())
	if _members.is_empty():
		return
	var shared: float = 1.0
	for member: Array in _members:
		shared = minf(shared, float((member[0] as Callable).call()))
	scale = shared
	for member: Array in _members:
		(member[1] as Callable).call(shared)
