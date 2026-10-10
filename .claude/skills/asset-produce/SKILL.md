---
name: asset-produce
description: "Executes approved asset specs into real files by driving the asset-gen tools (Gemini, Grok, Tripo3D). Reads generation prompts from design/assets/specs/, confirms projected spend, produces PNG/GLB/animated sprites into assets/, and updates the asset manifest. Run after /asset-spec approval, before /asset-audit."
argument-hint: "[system:<name> | level:<name> | character:<name> | ASSET-NNN] [--dry-run] [--model gemini|grok]"
user-invocable: true
allowed-tools: Read, Glob, Grep, Write, Edit, Bash, AskUserQuestion
model: sonnet
---

This skill is the bridge between design and production. `/asset-spec` writes generation
prompts but stops there; `/asset-gen` knows how to call the paid APIs but knows nothing
about the studio's specs, manifest, or art bible. This skill connects the two.

**It spends real money.** Every gate below is mandatory — never generate before Phase 4 approval.

---

## Phase 0: Preflight

Resolve the Python interpreter once and reuse it for every call in this session:

```bash
for cmd in python python3 py; do command -v "$cmd" >/dev/null 2>&1 && { echo "$cmd"; break; }; done
```

If nothing resolves, STOP and report: "Python not found. See `docs/asset-pipeline-setup.md`."
Do not attempt to install it.

Check the three API keys:

```bash
for k in GOOGLE_API_KEY XAI_API_KEY TRIPO3D_API_KEY; do
  eval "v=\$$k"; [ -n "$v" ] && echo "$k: set" || echo "$k: MISSING"
done
```

Map which keys each job actually needs — do not block on a key the run will never use:

| Missing key | Blocks |
|-------------|--------|
| `GOOGLE_API_KEY` | `--model gemini` images only |
| `XAI_API_KEY` | `--model grok` images, and all video (animated sprites) |
| `TRIPO3D_API_KEY` | `glb`, `rig`, `retarget` — all 3D |

If a key needed by the selected assets is missing, surface exactly which assets are
blocked and offer to proceed with the rest.

---

## Phase 1: Resolve Target

**With an argument** — `system:combat`, `level:forest`, `character:hero`: read
`design/assets/specs/[target-name]-assets.md`.

**With `ASSET-NNN`**: grep `design/assets/specs/` for that ID and produce only that asset.

**With no argument**: read `design/assets/asset-manifest.md`, collect every row whose
Status is `Needed`, group them by spec file, and use `AskUserQuestion`:
- Prompt: "[N] assets across [N] specs are still `Needed`. Which batch should I produce?"
- Options: one per spec file, plus `[All of them]` and `[Stop here]`

If no spec file exists, STOP: "No approved specs found. Run `/asset-spec` first."

---

## Phase 2: Parse Specs

For each `## ASSET-[NNN] — [Name]` block, extract:

| Spec field | Used as |
|------------|---------|
| Category | routes to a job type (Phase 3) |
| Dimensions | `--size` and `--aspect-ratio` |
| Format | sanity check — PNG/GLB only; anything else is not generatable |
| Naming | output filename |
| Texture Res | `--size` for 3D source images |
| **Generation Prompt** | `--prompt` verbatim |
| Status | skip anything not `Needed` |

**Never rewrite the Generation Prompt.** It is anchored to the art bible's shape language
and color system by `art-director`. Editing it silently breaks visual consistency across
the project. If a prompt looks wrong, surface it and ask — do not fix it in place.

Skip and report, do not guess:
- **Audio** — `/asset-spec` writes sonic descriptions, not prompts. asset-gen has no audio backend.
- Any block missing a Generation Prompt.
- Any asset whose Status is already `In Progress` or `Done` (a prior run may still be resumable — see Phase 6).

---

## Phase 3: Route Each Asset to a Job

Read `.claude/skills/asset-gen/SKILL.md` before building commands — it carries the
authoritative flags, costs, and pitfalls.

| Category | Job | Model | Output |
|----------|-----|-------|--------|
| Sprite / 2D Art | `image` | gemini (characters) / grok (tiles, props) | `assets/art/` |
| VFX / Particles | `image` | grok | `assets/vfx/` |
| Environment | `image` | grok (textures) / gemini (landmarks) | `assets/art/environment/` |
| UI | `image` | gemini | `assets/art/ui/` |
| 3D Assets | `image` → `glb` | gemini for the source image | `assets/art/models/` |
| 3D biped character | `image` → `rig` → `retarget` | gemini | `assets/art/models/` |
| Audio | — | — | skipped, reported |

Model routing rule from asset-gen: **Gemini when the result must match what you described**
(characters, references, exact layouts, UI); **Grok when it just needs to look good**
(textures, simple objects, scenery). `--model` on the command line overrides this per run.

Output path = category directory + the spec's `Naming` value. Respect the naming
convention in `.claude/docs/technical-preferences.md` — do not invent your own.

**Constraints that cost money if broken:**
- Minimum image generation is 1K. A sprite displayed under 128px comes out muddy — flag it and offer a kit + `grid_slice.py` instead of one call per sprite.
- Review every PNG before any GLB conversion. A bad source image wastes 30¢+ downstream.
- Do **not** background-remove an image destined for `glb` — Tripo3D needs the solid background.
- `rig` is biped-only. Route quadrupeds to plain `glb`.

---

## Phase 4: Cost Gate (mandatory)

Build the full job list and total it before spending anything. Present:

```
## Production Plan — [target]

| Asset ID | Name | Job | Model | Output | Cost |
|----------|------|-----|-------|--------|------|
| ASSET-001 | hero_idle | image | gemini 1K | assets/art/hero_idle.png | 7¢ |
| ASSET-004 | crate | image → glb | gemini + tripo | assets/art/models/crate.glb | 37¢ |

**Total: [N] assets — approximately [X]¢ (~$Y.YY)**

Skipped: ASSET-009 (Audio — no generation backend)
Blocked: ASSET-012 (needs TRIPO3D_API_KEY)
```

Reference costs: Grok image 2¢ · Gemini 1K 7¢ / 2K 10¢ / 4K 15¢ · GLB 30¢ (hd 60¢) ·
rig +25¢ · retarget 10¢/clip · video 5¢/sec. A rigged character with walk/idle/attack
lands around 92¢.

Then `AskUserQuestion`:
- Prompt: "This will spend approximately **[X]¢**. Proceed?"
- Options:
  - `[A] Generate all — [X]¢`
  - `[B] Generate a subset — let me pick`
  - `[C] Downgrade to Grok where possible — [lower]¢`
  - `[D] Dry run only — show commands, spend nothing`

`--dry-run` jumps straight to [D]. **Never skip this gate,** even for a single 2¢ image,
and even when the user has approved a previous batch. Approval does not carry across runs.

---

## Phase 5: Generate

Mark the manifest rows `In Progress` before the first call, so an interrupted run is
recoverable.

Run independent images in parallel — issue multiple Bash calls in one message. Chain
`image → glb → rig → retarget` sequentially per asset.

Keep stderr out of context; read it only on failure:

```bash
_log=$(mktemp)
result=$($PY .claude/skills/asset-gen/tools/asset_gen.py image \
  --prompt "..." --model gemini --size 1K -o assets/art/hero_idle.png 2>"$_log") \
  || tail -20 "$_log"
echo "$result"
```

Each call returns `{"ok": true, "path": "...", "cost_cents": N}`. Accumulate the real
`cost_cents` — report actuals at the end, not the estimate.

**On timeout in `glb` / `rig` / `retarget`:** the task id is already saved in the
`<output>.tripo.json` sidecar and the job is likely still running server-side. Resume for
free — **never resubmit, that double-charges:**

```bash
$PY .claude/skills/asset-gen/tools/asset_gen.py resume -o assets/art/models/crate.glb
```

For animated sprites follow the full recipe in `.claude/skills/asset-gen/SKILL.md`
(reference → pose → video → ffmpeg extract → `find_loop_frame.py` → `rembg_matting.py`).
Loop-trim walk/idle cycles; skip trimming for one-shots like attack and death.

If a generation fails or the output is visually wrong, stop that asset and report it.
Do not silently retry — every retry is another charge.

---

## Phase 6: In-game Size (do not skip)

`/asset-spec` records pixel dimensions and polycount, but **not** in-game scale — and
without it programmers consistently scale assets wrong. Fill the gap now.

Propose a value per asset from the design docs and ask the user to confirm:

- 3D models — meters: `4m long`, `1.8m tall`
- Textures — tile size: `2m tile`
- Backgrounds — pixels + behavior: `1920x1080, fullscreen`
- Sprites — display pixels: `128x128 px`

---

## Phase 7: Update Manifest

Ask: "May I update `design/assets/asset-manifest.md`?"

Extend each produced row to the full studio schema:

| Asset ID | Name | Category | Status | In-game Size | Path | Cost | Spec File |
|----------|------|----------|--------|--------------|------|------|-----------|

Set Status to `Done`. **Do not set `Approved`.** `Done` means the file exists; `Approved`
means it passed review. `/asset-audit` is a read-only diagnostic — it reports violations
but cannot edit the manifest, so the promotion `Done → Approved` is a separate, deliberate
edit made after the audit comes back clean. Recompute the Progress Summary counts.

Then update the source spec file: flip each produced asset's `**Status:** Needed` to
`**Status:** Done` and append the delivered path under it.

Report actual total spend versus the Phase 4 estimate.

---

## Phase 8: Close

`AskUserQuestion`:
- Prompt: "Produced [N] assets for **[target]** — [X]¢ spent. What's next?"
- Options:
  - `[A] Run /asset-audit — validate the delivered files against their specs`
  - `[B] Produce the next batch`
  - `[C] Spec more assets — /asset-spec`
  - `[D] Stop here`

---

## Guardrails

1. **Never generate before the Phase 4 gate.** No exceptions, no carry-over approval.
2. **Never edit a Generation Prompt** — it is art-bible-anchored. Surface problems instead.
3. **Never resubmit a timed-out Tripo3D job.** Resume from the sidecar.
4. **Never rembg a `glb` source image.**
5. **Never write an asset table into `README.md`.** `design/assets/asset-manifest.md` is the single source of truth.
6. **Never invent an asset that has no spec.** Missing spec means run `/asset-spec` first.
7. Follow the studio collaboration protocol — ask before every Write/Edit.

---

## Error Recovery Protocol

If a generation fails, report immediately in this form:

```
ASSET-[NNN] ([name]): FAILED — [reason from stderr]
Spent so far: [X]¢
Remaining in batch: [N] assets
```

Then `AskUserQuestion`: `[A] Skip and continue` / `[B] Retry this asset (costs again)` /
`[C] Stop the batch`.

Leave failed assets at `In Progress` in the manifest with a note, so the next run finds
them. Never mark a failed asset `Done`.
