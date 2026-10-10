# Docs Directory

> ## ⚠️ ĐỌC TRƯỚC — FILE NÀY LÀ MẪU CHƯA BẢN ĐỊA HOÁ (đo 11/10)
>
> Mẫu StudioForge, mô tả cấu trúc mà repo này **không có**:
>
> | file này trỏ tới | thực tế |
> |---|---|
> | `docs/architecture/control-manifest.md` (*bắt buộc*, có `Manifest Version:`) | **KHÔNG TỒN TẠI** — `docs/architecture/` chỉ có `tr-registry.yaml` |
> | `docs/engine-reference/godot/VERSION.md` | **có thật**, nhưng từng ghim **Godot 4.6** trong khi repo chạy **4.7.2** — đã sửa 11/10 |
>
> `tr-registry.yaml` và template ADR thì **có thật**. Xem `CLAUDE.md` ở gốc repo.

When authoring or editing files in this directory, follow these standards.

## Architecture Decision Records (`docs/architecture/`)

Use the ADR template: `.claude/docs/templates/architecture-decision-record.md`

**Required sections:** Title, Status, Context, Decision, Consequences,
ADR Dependencies, Engine Compatibility, GDD Requirements Addressed

**Status lifecycle:** `Proposed` → `Accepted` → `Superseded`
- Never skip `Accepted` — stories referencing a `Proposed` ADR are auto-blocked
- Use `/architecture-decision` to create ADRs through the guided flow

**TR Registry:** `docs/architecture/tr-registry.yaml`
- Stable requirement IDs (e.g. `TR-MOV-001`) that link GDD requirements to stories
- Never renumber existing IDs — only append new ones
- Updated by `/architecture-review` Phase 8

**Control Manifest:** `docs/architecture/control-manifest.md`
- Flat programmer rules sheet: Required / Forbidden / Guardrails per layer
- Date-stamped `Manifest Version:` in header
- Stories embed this version; `/story-done` checks for staleness

**Validation:** Run `/architecture-review` after completing a set of ADRs.

## Engine Reference (`docs/engine-reference/`)

Version-pinned engine API snapshots. **Always check here before using any
engine API** — the LLM's training data predates the pinned engine version.

Current engine: see `docs/engine-reference/godot/VERSION.md`
