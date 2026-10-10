# Source Directory

> ## ⚠️ ĐỌC TRƯỚC — FILE NÀY LÀ MẪU CHƯA BẢN ĐỊA HOÁ (đo 11/10)
>
> Đây là **file mẫu của khung StudioForge**, viết cho một repo mà repo này **không có**.
> Đo trên đĩa `D:\PROJECT\ProjectOut\game\bravecross-game`:
>
> | file này trỏ tới | thực tế |
> |---|---|
> | `src/` — "Source Directory" | **RỖNG**: chỉ có `.gitkeep` và chính `CLAUDE.md` này |
> | `tests/` — *"Tests live in `tests/`"* | **KHÔNG TỒN TẠI** |
> | "Technical Preferences → … File Extension Routing" | `.claude/docs/technical-preferences.md` **toàn `[TO BE CONFIGURED]`** |
>
> **Mã thật nằm ở các thư mục NGANG CẤP, không phải ở đây:** `ui/` · `lua/` · `battle/` ·
> `game/` · `sc/` · `rig/` · `tools/`. **Bộ kiểm thật** là `python tools/check.py`
> (**57** dòng kết quả = 52 bộ trong `SUITES` + 5 bộ Python) cùng `tools/verify_*.gd` —
> **không phải** một thư mục `tests/`. Xem `CLAUDE.md` ở gốc repo.

When writing or editing game code in this directory, follow these standards.

## Engine Version Warning

The LLM's training data predates the pinned engine version.
**Always check `docs/engine-reference/` before using any engine API.**
Do not guess at post-cutoff API signatures — look them up first.

## Coding Standards

- All public APIs require doc comments
- Gameplay values must be **data-driven** (external config files), never hardcoded
- Prefer dependency injection over singletons for testability
- Every new system needs a corresponding ADR in `docs/architecture/`
- Commits must reference the relevant story ID or design document

## File Routing

Match the engine-specialist agent to the file type being written.
See `CLAUDE.md` → Technical Preferences → Engine Specialists → File Extension Routing.

When in doubt, use the primary engine specialist configured in `CLAUDE.md`.

## Tests

Tests live in `tests/` — not in `src/`.
Run `/test-setup` to scaffold the test framework if it doesn't exist yet.
Every gameplay system should have unit tests covering its formulas and edge cases.

## Verification-Driven Development

Write tests first when adding gameplay systems.
For UI changes, verify with screenshots.
Compare expected output to actual output before marking work complete.
