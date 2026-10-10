# Asset Pipeline Setup

The `/asset-produce` and `/asset-gen` skills call paid third-party APIs. Nothing else in
this project needs any of the setup below — if you are only writing design docs, epics,
stories, or code, you can skip this file entirely.

---

## 1. Python

The generation tools are Python CLI scripts under `.claude/skills/asset-gen/tools/`.

Install Python 3.10+ from [python.org](https://www.python.org/downloads/) and tick
**"Add Python to PATH"** during install.

Verify:

```bash
python --version
```

> On Windows the launcher is `python` or `py`. The upstream asset-gen docs are written for
> Linux/macOS and say `python3` — substitute whichever resolves on your machine. The skills
> resolve this automatically with `for cmd in python python3 py`.

---

## 2. Python packages

**Minimal — images and 3D models.** This is enough for the whole `/asset-produce` flow
except automatic background removal:

```bash
pip install xai-sdk google-genai requests pillow numpy
```

**Full — adds background removal for animated sprites.** Heavy and GPU-oriented; the
upstream `requirements.txt` pins `onnxruntime-gpu` and `nvidia-cudnn-cu12`, which only make
sense on an NVIDIA machine:

```bash
pip install -r .claude/skills/asset-gen/tools/requirements.txt
```

On a machine without an NVIDIA GPU, install the CPU variant instead — it is slower but works:

```bash
pip install rembg pymatting onnxruntime
```

---

## 3. API keys

Three separate paid accounts. Each key is only needed for the jobs listed:

| Key | Provider | Needed for |
|-----|----------|-----------|
| `GOOGLE_API_KEY` | [Google AI Studio](https://aistudio.google.com/) | Gemini images — characters, references, UI, exact layouts |
| `XAI_API_KEY` | [xAI Console](https://console.x.ai/home) | Grok images — textures, props, scenery; **and all video** (animated sprites) |
| `TRIPO3D_API_KEY` | [Tripo3D](https://platform.tripo3d.ai/) | All 3D — `glb`, `rig`, `retarget` |

You can run a 2D-only project with just `XAI_API_KEY`. `/asset-produce` reports exactly
which assets are blocked by a missing key rather than failing the whole batch.

Set them as **environment variables** — never write them into a file in this repo. The
`.claude/settings.json` deny list already blocks reading `.env` files, and `assets/` output
is the only thing the pipeline writes.

Set them yourself in your own shell or system settings; do not paste keys into a chat
session. On Windows, the persistent route is System Properties → Environment Variables, or
`setx` from a terminal you control. On Linux/macOS, export them from your shell profile.

Verify without printing the values:

```bash
for k in GOOGLE_API_KEY XAI_API_KEY TRIPO3D_API_KEY; do eval "v=\$$k"; [ -n "$v" ] && echo "$k: set" || echo "$k: MISSING"; done
```

---

## 4. Optional system tools

Only needed for animated sprites (the video → frames → matte recipe):

| Tool | Used for |
|------|----------|
| `ffmpeg` | extracting frames from generated video |
| `imagemagick` (`magick`) | downscaling frames to a common size before matting |

---

## 5. Cost control — read this before your first run

**These APIs bill per call, and there is no spending cap in this repo.**

`/asset-produce` gates every batch behind an explicit cost estimate and an approval prompt,
and that gate never carries over between runs. But it is a prompt, not an enforced limit —
the only hard ceiling is the one you set with the provider.

**Set a spending limit in each provider's billing console before generating anything.**

Reference costs:

| Job | Cost |
|-----|------|
| Grok image | 2¢ |
| Gemini image | 5¢ (512) · 7¢ (1K) · 10¢ (2K) · 15¢ (4K) |
| GLB 3D model | 30¢ (`--quality hd`: 60¢) |
| Rig a biped | +25¢ |
| Retarget one animation clip | 10¢ |
| Video | 5¢/sec |

A full rigged character with walk/idle/attack lands around **92¢**. A 40-asset batch of
simple 2D sprites is under a dollar; a 40-asset batch of 3D models is roughly **$15**.

Two traps that cost real money:

- **A timed-out Tripo3D job is usually still running.** The task id is saved in a
  `<output>.tripo.json` sidecar. Resume it — resubmitting double-charges.
- **Review every PNG before converting it to GLB.** A bad source image wastes 30¢+
  downstream.

---

## 6. Verify the install

```bash
python .claude/skills/asset-gen/tools/asset_gen.py --help
```

If that prints the subcommand list (`image`, `video`, `glb`, `rig`, `retarget`, `resume`),
the pipeline is ready. Then run `/asset-produce --dry-run` to see the commands a real batch
would issue without spending anything.
