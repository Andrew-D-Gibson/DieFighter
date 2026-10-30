class_name ProgressTools
extends RefCounted
## The options menu's two progress buttons: wipe the player's progress back to
## a first launch, or fill it in as if they'd seen everything. Both leave the
## options themselves alone, so a wipe doesn't also lose the window size,
## volume and language.

## Where the region rules and hazards live, for marking every arrival card
## read.
const _REGION_DIRS: Array[String] = [
	"res://Source/Resources/BackgroundResources/BackgroundHazards/",
	"res://Source/Resources/BackgroundResources/BackgroundModifiers/",
]


## Back to a first launch: no run to continue, the tutorial unplayed, the codex
## empty and every region's arrival card waiting to be read.
static func erase() -> void:
	SaveManager.delete_save()
	CollectionManager.clear()
	Globals.tutorial_completed = false
	OptionsSettings.save_options_settings()


## As if the player had seen everything: the tutorial played, every tile and
## enemy in the codex and every region's arrival card read. A run in progress
## is left alone.
static func unlock_all() -> void:
	var regions: Array[String] = []
	for dir: String in _REGION_DIRS:
		for path: String in Utils.list_resource_paths(dir):
			regions.append(EnvironmentMonitor.region_id(load(path)))
	CollectionManager.unlock(CodexCatalog.tile_ids(), CodexCatalog.enemy_ids(), regions)
	Globals.tutorial_completed = true
	OptionsSettings.save_options_settings()
