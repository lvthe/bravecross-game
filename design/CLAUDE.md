# Design Directory

> ## ⚠️ ĐỌC TRƯỚC — FILE NÀY LÀ MẪU CHƯA BẢN ĐỊA HOÁ (đo 11/10)
>
> Mẫu StudioForge. Đo trên đĩa, thư mục `design/` **chỉ có** `CLAUDE.md` và `registry/`:
>
> | file này trỏ tới | thực tế |
> |---|---|
> | `design/gdd/` và `design/gdd/systems-index.md` | **KHÔNG TỒN TẠI** |
> | `design/quick-specs/` | **KHÔNG TỒN TẠI** |
> | `design/ux/` (`[screen-name].md`, `hud.md`, …) | **KHÔNG TỒN TẠI** |
>
> Nghịch lý đáng nhớ: tài liệu **thật** của repo này (`bravecross-game/**/*.md`) **dày đặc số
> đo bằng tiếng Việt**, còn ba file `src/` · `docs/` · `design/CLAUDE.md` là mẫu **tiếng Anh**
> mô tả một cấu trúc không tồn tại. Xem `CLAUDE.md` ở gốc repo.

When authoring or editing files in this directory, follow these standards.

## GDD Files (`design/gdd/`)

Every GDD must include all **8 required sections** in this order:
1. Overview — one-paragraph summary
2. Player Fantasy — intended feeling and experience
3. Detailed Rules — unambiguous mechanics
4. Formulas — all math defined with variables
5. Edge Cases — unusual situations handled
6. Dependencies — other systems listed
7. Tuning Knobs — configurable values identified
8. Acceptance Criteria — testable success conditions

**File naming:** `[system-slug].md` (e.g. `movement-system.md`, `combat-system.md`)

**Systems index:** `design/gdd/systems-index.md` — update when adding a new GDD.

**Design order:** Foundation → Core → Feature → Presentation → Polish

**Validation:** Run `/design-review [path]` after authoring any GDD.
Run `/review-all-gdds` after completing a set of related GDDs.

## Quick Specs (`design/quick-specs/`)

Lightweight specs for tuning changes, minor mechanics, or balance adjustments.
Use `/quick-design` to author.

## UX Specs (`design/ux/`)

- Per-screen specs: `design/ux/[screen-name].md`
- HUD design: `design/ux/hud.md`
- Interaction pattern library: `design/ux/interaction-patterns.md`
- Accessibility requirements: `design/ux/accessibility-requirements.md`

Use `/ux-design` to author. Validate with `/ux-review` before passing to `/team-ui`.
