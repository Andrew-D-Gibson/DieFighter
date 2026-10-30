# Art sources

Every texture the game loads is exported from an `.aseprite` file in this
folder. Edit the `.aseprite`; never edit the PNGs in `Assets/` by hand, as the
next export overwrites them.

## Where things go

`Art/` mirrors `Assets/`:

| Source                                    | Exports to                                     |
| ----------------------------------------- | ---------------------------------------------- |
| `Art/Textures/UI/foo.aseprite`, 1 frame   | `Assets/Textures/UI/foo.png`                   |
| `Art/Textures/UI/foo.aseprite`, 2+ frames | `Assets/Textures/UI/foo-Sheet.png` (a horizontal strip of every frame) |

- Only visible layers are exported. Hide a layer to keep work in progress, a
  reference sketch or a lit/unlit variant out of the game.
- Changing a file from 1 frame to several (or back) changes its PNG's name.
  The scene or resource that loads it has to point at the new name, and the old
  PNG has to be deleted.
- Renaming or moving a texture in Godot's FileSystem dock moves the PNG and
  fixes everything that loads it, but Godot can't see this folder, so its
  `.aseprite` keeps the old name. Rename the source to match, or the next
  export recreates the old PNG and edits never reach the new one.
  `--check` catches it: the old PNG shows as `stale` and the new one as
  `no source`.
- Folders starting with `_` are never exported:
  - `_Palettes/`: `aseprite_palette_final.aseprite` holds the 33 approved
    colours (see `CONTENT_BUILD_GUIDE.md`).
  - `_Workfiles/`: layouts and old versions that don't map 1:1 to a PNG, e.g.
    the cockpit mock-up, the button and check-box templates, and earlier
    drafts of art whose source had drifted from what the game shows. Copy
    from them freely; editing them changes nothing in game.
- Godot ignores this folder (`.gdignore`).

## Exporting

```sh
python3 tools/export_art.py                 # everything (about a second)
python3 tools/export_art.py Art/Textures/UI # just a file or folder
python3 tools/export_art.py --check         # change nothing; report stale PNGs and PNGs with no source
```

A PNG is only rewritten when its pixels change, so a full export leaves
untouched art alone. Needs Aseprite (set `ASEPRITE` if it isn't in
`/Applications`) and Pillow.

On the Mac, `git pull` exports by itself. The hooks in `tools/githooks` run
after a merge or a rebasing pull and export whatever came in. Turn them on
once per clone with `git config core.hooksPath tools/githooks`. The exported
PNGs show up as changes to commit, along with a new `.import` file for any new
PNG (Godot writes it the next time the editor gets focus).

## iPad (Pixquare + GitSync)

1. Pull in GitSync.
2. Open and edit the `.aseprite` in Pixquare, keeping the original format.
3. Commit and push in GitSync.
4. On the Mac: `git pull` (the hook exports), check the game, and commit the
   updated PNGs.

To add new art, save a new `.aseprite` into the matching `Art/` folder. The
next export creates its PNG.
