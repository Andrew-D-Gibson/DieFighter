# Localization plan — DieFighter

## Context
DieFighter has no localization yet. Every string is hardcoded English:
- ~150 strings in scripts
- ~94 in scenes
- ~400 in `.tres` content: tiles, enemies, enemy actions, tutorial steps, scenario dialogue, hazards and modifiers

The pieces that exist today are only placeholders:
- A disabled "Language" dropdown (`options_menu.tscn`, items `["English"]`).
- A `language` key saved by `OptionsSettings`, plus a `# TODO: Set Language` at `options_settings.gd:106`.

**Goal:** ship the top Steam languages: English, Simplified Chinese, Russian, Spanish (es), Brazilian Portuguese (pt_BR), German, Japanese and French. To get there we need:
- **One CSV translation file** for all text.
- **A working language dropdown.**
- **A repeatable way to check every string in every language** for fit and appearance.
- **Translations:** I write machine drafts, then humans review them.

## Decisions taken
- **One file:** `Localization/translations.csv`. This is Godot's native CSV translation import.
  - Columns: `keys, en, zh_CN, ru, es, pt_BR, de, ja, fr, _context, _max_chars, _status, _en_hash`.
  - Godot ignores any column whose name starts with `_`. Those columns are notes for translators and tooling.
  - It opens in Excel, Numbers or Google Sheets. Save it as **UTF-8 CSV**.
- **Keys are semantic, not English-as-key**, so fixing an English typo doesn't orphan every translation.
  - UI and code: `UI_END_TURN`, `MAP_HOVER_CORRUPTING`, `ERR_REQUIRES_DIE`.
  - Content: generated from the stable `ContentRegistry` ID, e.g. `TILE.<id>.NAME`, `TILE.<id>.DESC`, `ENEMY.<id>.NAME`, `TUTORIAL.<id>.TEXT`.
- **Content stays authored in English in the `.tres` files**, so the CONTENT_BUILD_GUIDE workflow barely changes. A sync tool copies the English into the CSV `en` column. At runtime, display code calls `tr(key)`.

## Phase 1 — Infrastructure
1. **`Localization` autoload** (`Source/Systems/Autoloads/localization.gd`). Before adding it, check `manage_autoloads`; none currently covers this. It is responsible for:
   - **The supported locale list:** code, native name such as "Deutsch" or "简体中文", and font profile.
   - **`set_locale(code)`:** calls `TranslationServer.set_locale` and swaps the font profile (Phase 4), then emits `Events.locale_changed`.
   - **First-launch default:** uses `OS.get_locale_language()` if that language is supported, otherwise English.
2. **`project.godot`:**
   - Register the CSV translations under `internationalization/locale/translations`.
   - Keep `fallback = en`.
   - Turn on including text-server/ICU data in exports. CJK line-breaking needs it.
3. **`OptionsSettings`:** replace the TODO with `Localization.set_locale(...)`.
   - The default changes from `"eng"` to `""`, meaning "detect".
   - Save the locale in the `Game` section. Persistence already works there.
4. **Options dropdown** (`options_menu.gd`/`.tscn`):
   - Unhide the Language row.
   - Fill it from `Localization`'s list. Language names are always shown in their own language and are never translated.
   - **Fix an existing bug:** the animation-speed, FPS and scale handlers (`options_menu.gd:192-235`) and `OptionsSettings` decide what to do by matching the item's display text ("None", "0.5x"). Translating that text would break them. Switch them to `set_item_id` / `set_item_metadata`, and save the IDs instead.
5. **Live switching:**
   - Scene-placed Labels use `auto_translate_mode` with key text, so Godot refreshes them automatically.
   - Text that code sets gets a small `_refresh_text()` hook, run on `NOTIFICATION_TRANSLATION_CHANGED`.
   - Known places this applies:
     - `button.gd`: it caches `_text_on_ready`, so it must translate the key and re-wrap it in `[wave]`.
     - `main_viewer.gd` tabs
     - `run_stats.gd`
     - The InfoShower, if open
     - The map legend
     - Tiles' descriptions, which are cached on render

## Phase 2 — Make every string translatable
Patterns, applied across the files the survey found:
- **Scenes:** replace `text = "END TURN"` with the key `UI_END_TURN`; auto-translate does the rest.
  - Placeholder text in InfoShower, BossIntroCard and TutorialTextPopup is excluded with `auto_translate_mode = DISABLED`.
- **Scripts:** use `tr("KEY")` and `tr("KEY").format({...})` with **named placeholders**, so translators can reorder them.
  - Example: `run_stats.gd:72` becomes one key with `{sector} {total} {encounters} {kills} {credits}`.
- **Sentences split across labels** (e.g. `jump_gate.gd:241-242` "SECTOR %d" / "OF %d"): either one key per label, documented in `_context`, or merge them into one label.
- **Plurals:** use `tr_n()` for the cases written by hand:
  - `status_badge.gd:49` "stack%s"
  - `environment_monitor.gd:285` turns
  - `player.gd:597` DIE/DICE
  - Russian needs three plural forms.
  - ⚠ Plural columns in CSV are **unconfirmed for 4.7.1**. Verify first with a two-row test CSV and `tr_n` in a live eval. If unsupported, use explicit `_ONE`/`_FEW`/`_MANY` keys plus a tiny plural-rule helper in `Localization`.
- **Content resources:**
  - Add a `display_name()` / `display_description()` accessor to `TileResource`, `EnemyResource`, `EnemyActionResource`, `TutorialStep`, `ScenarioShipState`, `ScenarioResource` (boss title/subtitle), `BackgroundHazardResource`, `BackgroundModifierResource`, modifiers and statuses.
  - The accessor returns `tr(<generated key>)`, falling back to the English field.
  - Every call site that reads `tile_name` / `description` etc. for display switches to the accessor.
- **Lookups keyed by display names must use stable IDs:**
  - `Keywords` `_DEFINITIONS`/`_TOKENS` and `[url=Term]` meta switch to keyword IDs. `status_badge.gd:51` stops passing `display_name`.
  - Keyword labels and rule texts become keys (`KW.FEED.LABEL`, `KW.FEED.RULE`).
- **`EffectData.string_param`** currently holds both internal IDs and on-screen callouts (`"SIPHON"`, `"RAM {amount}"`). Add a separate `callout` field holding the English text with a generated key, and migrate the ~55 callout uses. Internal IDs stay untranslated.
- **Untouched in the body text:**
  - The token grammar: `(die_3)`, `(burn)`, `(target)`, `(delay=0.3)`, `[color=red]`, `[data]…[/data]`.
  - `Utils.format_text` runs after `tr()`, so translators keep tokens and BBCode exactly as in English. The linter (Phase 3) enforces this.
- **Leave English:** the DevConsole, TilePalette and editor-only `effect_catalog.gd` labels.
- **Small fixes found during the survey:**
  - The broken `color=red]` tag in the Lone Wolf Lance description.
  - Tile names with BBCode inside them: move the colour to the display code.

## Phase 3 — Sync and lint tooling
1. **`tools/loc_sync.gd`** is a headless script: `Godot --headless --path . --script tools/loc_sync.gd`.
   - **Content entries:** walks `ContentRegistry` content and writes or updates the `en` column for every generated content key.
   - **Code and scene keys:** collects them by scanning `.tscn` / `.gd` for `tr("…")` and key-shaped `text =`. Their English lives in the CSV.
   - **Stale entries:** stores a hash of the English in `_en_hash`. When the English changes, the row's `_status` is set to `stale` and translations stay until someone reviews them.
   - **Removals:** rows whose key no longer exists are reported, not deleted.
2. **`tools/loc_lint.gd`** (also a GUT test in `test/content/`):
   - Every key used in code exists in the CSV.
   - No empty cells for shipped locales.
   - Placeholder, token and BBCode parity with `en`: `{x}`, `%d`, `(die_n)`, `(delay=…)`, and balanced `[color]`/`[wave]`/`[url]`.
   - Every character is covered by that locale's font profile (`Font.has_char`).
   - `_max_chars` hints are respected.
3. **Docs:** add a CONTENT_BUILD_GUIDE §13 "Text & localization": write the English in the `.tres`, run `loc_sync`, run the lint, and never put display text in `string_param`.

## Phase 4 — Fonts (biggest visual risk)
Today's default font, m3x6, has **no accented letters, Cyrillic or CJK**. Plan:
- **A `FontProfile` resource per locale:** primary font, fallback chain, base size, and line-spacing adjustment.
  - `Localization.set_locale` applies it by swapping `default_font` / `default_font_size` in `Assets/Themes/default.tres` at runtime.
  - The hardcoded `preload`s of m5x7 also go through the profile: `damage_number.gd`, `amplifier_visual.gd`, `environment_monitor.gd`.
- **Latin and Cyrillic** (en/es/pt/de/fr/ru): a pixel font in the m3x6 style that adds Latin-1, Latin Extended-A and Cyrillic.
- **zh_CN and ja:** a ~12 px CJK pixel font, e.g. Fusion Pixel 12px or Ark Pixel 12px (both OFL).
  - CJK can't be drawn in 6 px, so these locales use a larger base size and accept fewer lines per box.
  - The audit (Phase 5) shows where that breaks.
- **Title fonts** (Bladerunner, Jersey25): the main-menu "DIE FIGHTER" logo can stay English. Any other text drawn in those fonts needs a fallback.

## Phase 5 — Visual audit ("run through the whole game")
Three tools, cheapest first:
1. **Pseudo-localization:** Godot's built-in `internationalization/pseudolocalization`. Use a toggle plus a `lang pseudo` dev-console command, with roughly 40% expansion, accents and brackets. This works **before any translations exist**:
   - Untranslated strings show without brackets.
   - Overflow shows as clipped brackets.
2. **Overflow watcher** (a debug-only child of `Localization`). While you play normally in any language, it checks each visible Label/RichTextLabel after layout.
   - It flags:
     - `get_content_height() > size.y`
     - clipped `visible_characters`
     - autowrap disabled with content wider than the box
     - glyphs missing from the font
   - Each problem gets a red outline on screen and a line in `debug_log.txt` with the node path and key.
3. **Localization gallery and report** (`Source/Debug/LocAudit/loc_audit.tscn` plus a runner script). For each locale it forces every text surface into view, screenshots it to `user://loc_audit/<locale>/<surface>/<item>.png`, and collects watcher flags. Surfaces covered:
   - Main menu, options (all 3 tabs), pause menu, confirm dialog
   - InfoShower for all 90 tiles, all enemies, all enemy actions, keywords and statuses
   - Map plus legend and hover captions
   - Shop, reward, game over and victory, jump gate, boss intro cards
   - Every tutorial step, every scenario dialogue line, environment monitor hazards and modifiers
   - Tile error popups and effect callouts

   It writes `user://loc_audit/report.html`: a contact sheet per locale, with flagged items first, side by side with English.
   - **Running it:** a dev-console command `loc_audit [locale|all]` starts it. I can also run it through MCP (`run_project` → `call_method`).
   - **Automation:** it drives screens directly through existing signals (`Events.show_info(InfoResource)`, GameStateManager states, `change_scene`), not by playing.
   - **Missed screens:** anything it misses is caught by the watcher during real play.

## Phase 6 — Translation pass
- I fill the 7 columns with machine drafts and set `_status = machine`. I use a glossary tab so terms stay consistent: ship, die/dice, Feed, Burn, Hull, credits, sector.
- The lint and audit run per locale. I fix overflow by shortening text or adjusting layouts, and record `_max_chars` where it's tight.
- Reviewers edit the CSV and set `_status = reviewed`.

## Order and milestones
Each item is one commit, following the milestone-commit habit:
1. **Infra, dropdown, ID-based options fix, pseudolocale.** Playable, with English only.
2. **UI scenes and scripts converted.**
3. **Content accessors, keywords by ID, callout field, sync and lint tooling, guide section.**
4. **Font profiles.**
5. **Overflow watcher, then the audit gallery and report.**
6. **Machine drafts for the 7 languages, then audit fixes.**

## What's needed from you
1. **Fonts:** pick and license them. I'll shortlist pixel fonts that cover:
   - Latin Extended + Cyrillic in an m3x6-like style
   - 12 px CJK

   You choose based on the look. Also decide how much CJK text growth is acceptable.
2. **Glossary sign-off:** which terms stay English. The game title is a likely one; possibly keyword names, if you want them to read like brand terms.
3. **Text baked into art:** tell me about, or let me inventory, any sprites with text drawn in, e.g. tab art or logos. Those need per-locale images or must stay English.
4. **Native reviewers** for each language, or a budget for paid review. Machine drafts aren't ship quality, especially ja and zh_CN.
5. **Running and reviewing:** run the audit and review `report.html` per language. Final "looks right" calls are yours or the reviewers'.
6. **Outside the game:** the Steam store page, capsule art and achievements need their own localization. They are out of scope here.

## Verification
- `validate_script` after every `.gd` edit, and `validate_scripts` at each milestone. Rebuild the class cache with `--import` for new `class_name`s.
- **Live checks via MCP:**
  - `run_project`
  - switch locales with `call_method Localization.set_locale`
  - screenshot the options, InfoShower and map
  - `game_get_errors`
  - grep `godot.log`
- **GUT:** the new loc-lint test plus the existing suite.
- **Pseudo-locale:** a full audit run in the pseudo-locale before real translations. It is the acceptance bar for "every string goes through translation".
- **Per-language:** an audit run per real locale, with zero overflow flags and zero missing glyphs.
