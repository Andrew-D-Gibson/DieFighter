# Architecture Update — New Since ARCHITECTURE_OVERVIEW.md (4be5537, 2026-07-24)

## New Autoloads
1. `ContentRegistry` (`Autoloads/content_registry.gd`) — maps stable string IDs to `res://` paths so saves survive `.tres` renames/moves; stores IDs in save instead of raw paths.
2. `RNGManager` (`Autoloads/rng_manager.gd`) — owns all RNG "buckets" (`RUN`, `DICE`, `ENEMY_AI`, `TARGETING`, `REWARDS`, `BACKGROUND`, `COSMETIC`); keeps gameplay randomness reproducible from a seed, cosmetic free-running; re-seeds on `Events.load_scenario`.
3. `SaveManager` (`Autoloads/save_manager.gd`) — single autosave slot to `user://save_game.json` (JSON, `SAVE_VERSION = 1`); deletes save on `game_over`; `GameStateManager` keeps a `GameSaveResource` current and calls `write_save()` at checkpoints.
4. `MCPInteractionServer` (`Autoloads/mcp_interaction_server.gd`, also mirrored at repo root) — TCP server on port 9090 for external MCP interaction; runs `PROCESS_MODE_ALWAYS`; 4800+ lines.

## Save System
5. `GameSaveResource` (`Resources/game_save_resource.gd`, renamed from `game_save.gd`) + `Resources/SaveResources/*.tres` slot resources (`game_start.tres`, `tutorial_start.tres`).

## EffectsV2 — Enemy Intents Migration
6. Enemy actions now run through `EffectChainV2`; `effect_data.gd` gained an "Enemy Intents" setting; `effect_enums.gd` expanded (~+44 lines).
7. New effect events: `EffectEvents/Enemy/enemy_action_event.gd`, `EffectEvents/Enemy/scenario_state_effects_event.gd`, `EffectEvents/TileControl/tile_event_triggered_event.gd`, `EffectEvents/AudioVisual/snap_die_to_position_event.gd`.
8. New handlers: `add_amount_handler`, `add_adjacent_tiles_amount_handler`, `add_tile_data_amount_handler`, `set_amount_handler`, `set_amount_to_die_value_handler`, `set_amount_to_enemy_intent_handler`, `set_amount_to_engine_charge_handler`, `target_tile_with_offset_handler`, `give_die_away_handler`, `give_die_to_player_handler`, plus edits to amount/attribute/targeting handlers.
9. Legacy `Content/Effects/*` tree gutted/mostly deleted (activators, attribute changers, targeters, tile movers, tweens removed).

## Modifiers / Tile Effects
10. New `LockoutModifier` (`Modifiers/LockoutModifier/lockout_modifier.gd`) + `lockout_modifier_visual.tscn`; `lockout_effect_event.gd`.
11. `ActivatesTwiceOnValueModifier` (`Modifiers/activates_twice_on_value_modifier.gd`).
12. Amplifier moved from `AmplifierStatus/` (deleted) into modifier/event form: `add_amplifier_modifier_event.gd`, `add_amplifier_modifier_handler.gd`.
13. Grid status-effect subsystem removed (`AmplifierStatus/`, `LockoutStatus/`, `GridStatusEffects/grid_status_effect.gd`).

## New UI Systems
14. `PixelDropdown` (`UI/Buttons/pixel_dropdown.gd` + `.tscn`) — in-tree dropdown mirroring the `OptionButton` API subset, stays under the custom cursor.
15. `ConfirmDialog` (`UI/ConfirmDialog/confirm_dialog.gd` + `.tscn`) — `confirmed()`/`cancelled()` signals.
16. `SaveIndicator` (`UI/SaveIndicator/save_indicator.gd` + `.tscn`) — fades in on `Events.game_saved`.
17. Reworked UI: `MainMenu`, `OptionsMenu`, `PauseMenu`, `button.gd`/`large_button.tscn`.

## Other
18. New util `Source/Systems/utils.gd`.
19. Removed `faction_system.gd` and `enemy_action_filter.gd`; enemy action resources migrated to v2 chains.
20. New tile resources: `inertial_feedback.tres`, `unstable_shield_array.tres`; many `.tres` tiles migrated to `effect_chain_v2`.
21. `project.godot` updated with new autoloads registered.

## Stale in ARCHITECTURE_OVERVIEW.md
- Autoload table omits `ContentRegistry`, `RNGManager`, `SaveManager`, `MCPInteractionServer`.
- No mention of save system or enemy-intents migration to v2.
