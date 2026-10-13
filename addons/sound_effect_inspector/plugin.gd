@tool
extends EditorPlugin

const SoundEffectInspector = preload("res://addons/sound_effect_inspector/sound_effect_inspector.gd")

var _inspector_plugin: SoundEffectInspector


func _enter_tree() -> void:
	_inspector_plugin = SoundEffectInspector.new()
	add_inspector_plugin(_inspector_plugin)


func _exit_tree() -> void:
	remove_inspector_plugin(_inspector_plugin)
	_inspector_plugin.cleanup()
	_inspector_plugin = null
