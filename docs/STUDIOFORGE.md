# StudioForge — what this is

StudioForge is [Claude Code Game Studios](https://github.com/Donchitos/Claude-Code-Game-Studios)
(CCGS) with the asset-generation half of [godogen](https://github.com/htdt/godogen) grafted
onto it, plus one new skill connecting the two.

Both upstreams are MIT. `LICENSE` is CCGS's; godogen's is preserved at
`.claude/skills/asset-gen/LICENSE.md` alongside the code it covers.

---

## Why merge them

The two projects have exactly complementary gaps.

**CCGS produces prompts and then stops.** `/asset-spec` Phase 3 tasks the `art-director`
agent with writing *"a generation prompt ready for use with AI image tools"* — anchored to
the art bible's shape language and color system. Then it writes that prompt to a file and
the pipeline ends. You copy it somewhere else by hand.

**CCGS cannot see the game run.** Nothing in its 73 skills builds, runs, or screenshots
anything. `/playtest-report` is a form for recording what human testers said.

**godogen has both of those and almost no design layer.** Its runtime manifest is about ten
lines; there is no GDD, no ADR, no epic, no story, no sprint, no design review. Fine for a
weekend prototype, thin for anything with a second month.

So: CCGS supplies the process and the engine knowledge, godogen supplies the hands.

---

## What was taken from godogen

Only `asset-gen/` — a self-contained skill, 8 files, no dependency on godogen's runtime
manifest or engine guides. It landed at `.claude/skills/asset-gen/`.

It is genuinely engine-agnostic: it emits PNG, GLB, and sprite sheets. Godot, Unity, and
Unreal all consume those, so **the engine choice in `CLAUDE.md` stays open**. Only
godogen's *capture* recipes are Godot/Bevy/Babylon-specific, and those were not taken.

### Changes made to the vendored copy

1. **Template tokens rendered.** Upstream ships `${ASSET_GEN_SKILL_DIR}`,
   `${RUNTIME_ASSET_DIR}`, `${ASSET_SKILL_COMMAND}`, `${AGENT_NAME}` for `publish.sh` to
   substitute. Rendered to `.claude/skills/asset-gen`, `assets`, `/asset-gen`, `Claude`.
2. **Manifest target redirected.** Upstream tells the agent to track assets in `README.md`.
   That collides with CCGS's `design/assets/asset-manifest.md`. The skill now writes to the
   studio manifest, using an extended schema that keeps godogen's **in-game Size** column —
   its most useful idea, and something CCGS's spec format genuinely lacks.
3. **Interpreter note added.** Upstream is written for Linux/macOS and says `python3`. The
   note points at the same `python python3 py` resolution the CCGS hooks already use.
4. **Status vocabulary aligned** with CCGS's `Needed → In Progress → Done → Approved`.

Everything else — model routing, costs, the Tripo3D resume rule, the animated-sprite
recipe, the visual pitfalls — is upstream text, unchanged.

---

## What was added

**`/asset-produce`** (`.claude/skills/asset-produce/`) — the bridge, and the only wholly new
skill. It reads the spec files `/asset-spec` wrote, routes each asset to the right
generation job, totals the projected spend, asks before spending it, generates, and updates
the manifest.

Design decisions worth knowing:

- **The cost gate never carries over.** Every batch re-asks, including a single 2¢ image.
- **Generation prompts are never rewritten.** They are art-bible-anchored; silently editing
  one breaks visual consistency project-wide. Problems get surfaced, not fixed in place.
- **In-game size is collected explicitly.** CCGS specs carry pixel dimensions and polycount
  but not world scale, and godogen's docs are blunt about the consequence: without it,
  programmers consistently scale assets wrong.
- **Audio is skipped, loudly.** `/asset-spec` writes sonic descriptions rather than prompts,
  and asset-gen has no audio backend. The skill reports these rather than guessing.
- **`Done` ≠ `Approved`.** `/asset-produce` sets `Done` (the file exists). `/asset-audit` is
  read-only by design and cannot promote anything, so `Approved` stays a deliberate edit
  after the audit comes back clean.

### Other files touched

| File | Change |
|------|--------|
| `CLAUDE.md` | Asset Production section; pipeline filled into the tech stack |
| `.claude/settings.json` | allow-rules for the asset-gen tools, `ffmpeg`, `magick` |
| `.claude/skills/asset-spec/SKILL.md` | Phase 6 now offers `/asset-produce` as the next step |
| `.claude/docs/workflow-catalog.yaml` | `asset-produce` step so `/help` knows the phase |
| `docs/asset-pipeline-setup.md` | new — Python, packages, API keys, cost control |

The 49 agents, 12 hooks, 11 rules, and the other 73 skills are untouched CCGS.

---

## What was deliberately left behind

- **`publish.sh`** — see the warning below.
- **`prompts/runtime.md`** — godogen's autonomous runtime. It would fight CCGS's
  collaboration protocol directly: CCGS requires the agent to ask before every write,
  godogen is built to run unattended for hours.
- **The engine guides** (`godot.md`, `bevy.md`, `babylon.md`) — CCGS already has 16
  engine-specialist agents covering Godot, Unity, and Unreal in far more depth. Taking
  godogen's would have forced the project to Godot for no gain.
- **`onnxruntime-gpu` / `nvidia-cudnn`** are not installed by default. See the setup doc for
  the CPU alternative.

---

## ⚠️ Never run godogen's `publish.sh` against this repo

It is destructive here, by design — it expects an empty target:

- [`publish.sh:110`](https://github.com/htdt/godogen/blob/main/publish.sh) —
  `rsync -a --delete "$TMP/skills/" "$TARGET/.claude/skills/"`. The source holds only
  `asset-gen`, and `--delete` removes everything at the destination that is not in the
  source. **All 75 skills here would be deleted.**
- The next line copies godogen's runtime over `CLAUDE.md`, wiping the studio configuration.
- `--force` runs `rm -rf` on the whole target directory first.

To pull a newer `asset-gen` from upstream, copy the directory by hand and re-apply the four
changes listed above:

```bash
cp -r <godogen>/asset-gen/. .claude/skills/asset-gen/
```

Then re-render the tokens (`sed -i` on `${ASSET_GEN_SKILL_DIR}` → `.claude/skills/asset-gen`,
`${RUNTIME_ASSET_DIR}` → `assets`, `${ASSET_SKILL_COMMAND}` → `/asset-gen`, `${AGENT_NAME}` →
`Claude`), redirect the manifest section away from `README.md`, and diff `/asset-produce`
against the new flags before trusting it.

---

## The pipeline

```
/art-bible          shape language, color system, asset standards
      ↓
/asset-spec         per-asset specs + art-bible-anchored generation prompts
      ↓                                   → design/assets/specs/*.md
/asset-produce      cost gate → generate → real files
      ↓                                   → assets/**
/asset-audit        validate delivered files against their specs (read-only)
      ↓
   Approved         deliberate manifest edit after a clean audit
```

Setup and cost control before the first run: `docs/asset-pipeline-setup.md`.

---

## Kit packaging

This folder is the clean, reusable kit. It was cut from the StudioForge workspace with
three kinds of content removed:

| Removed | Why |
|---------|-----|
| `.github/` | CCGS's own repo governance. `CODEOWNERS` assigns code ownership to the upstream author and `FUNDING.yml` adds their sponsor button — both wrong in someone else's game repo. Skills only need `.github/workflows/tests.yml`, which `/test-setup` creates fresh. |
| `CONTRIBUTING.md`, `SECURITY.md`, `UPGRADING.md` | About contributing to and upgrading upstream CCGS. No skill references them. The one README link to `UPGRADING.md` now points at the upstream copy on GitHub. |
| `design/quick-specs/`, `assets/data/tongue.json` | Content belonging to a specific game, not the kit. |

`README.md` is a Vietnamese quick-start with a phase-ordered skill index built from
`.claude/docs/workflow-catalog.yaml`. The upstream English README is kept verbatim as
`README.en.md`, apart from that one link.

`CCGS Skill Testing Framework/` stays despite looking like upstream tooling: `/skill-test`
and `/skill-improve` read `catalog.yaml` from that exact path.

The registry files (`design/registry/entities.yaml`, `docs/registry/architecture.yaml`,
`docs/architecture/tr-registry.yaml`) are empty schemas, not example data.

The kit has no `.git` on purpose. Initialise git inside each game copied from it, or every
game would share one commit history.
