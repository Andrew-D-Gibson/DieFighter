# Planning Documents — index

Which of these docs are still live, and which are history. Current architecture
lives in `../ARCHITECTURE_OVERVIEW.md`; what changed and why lives in
`../DEVLOG.md`.

| Doc | Status | Use it for |
|-----|--------|------------|
| `CLEANUP_PROGRESS.md` | **Live checklist** (43 open, dated 2026-08-10) | The to-do list for the two plans below. Several items were fixed later without being ticked; check the code before acting on one. |
| `CLEAN_UP_PLAN.md` | Reference | Per-file findings with line numbers from the August pass. Line numbers have drifted. |
| `GLOBAL_CLEANUP_PLAN.md` | Reference | Cross-cutting refactor ideas from the same pass. |
| `TUTORIAL_CLEANUP.md` | Done (2026-09-18) | History. |
| `ARCHITECTURE_UPDATE.md` | Folded into `ARCHITECTURE_OVERVIEW.md` | History. Its autoload and save-system notes are in the overview now. |

The 2026-09-22 cleanup pass (see DEVLOG) didn't come from these docs. It was a
fresh audit: engine lifecycle, the single engine accessor, handler stamping,
options at boot, and dead signals.
