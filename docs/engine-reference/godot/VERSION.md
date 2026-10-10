# Godot Engine — Version Reference

| Field | Value |
|-------|-------|
| **Engine Version** | Godot 4.7.2 |
| **Release Date** | January 2026 (của bản 4.6 — CHƯA xác minh cho 4.7.2) |
| **Project Pinned** | 2026-10-11 |
| **Last Docs Verified** | 2026-02-12 |
| **LLM Knowledge Cutoff** | May 2025 |

> **GHI CHÚ 11/10 — bảng này TỪNG ghim Godot 4.6 và LỆCH với chính repo.** Nguồn thật:
> `project.godot:11` ghi `config/features=PackedStringArray("4.7", "GL Compatibility")`,
> và `CLAUDE.md` ghi engine chạy là `Godot_v4.7.2-stable_win64_console.exe` (xem skill
> `chay-game`). Nay bảng theo **4.7.2**. Ô `Release Date` **giữ nguyên số cũ** — nó là của
> 4.6 và **chưa ai xác minh cho 4.7.2**; đừng chép nó đi như một sự thật.

## Knowledge Gap Warning

The LLM's training data likely covers Godot up to ~4.3. Versions 4.4, 4.5,
and 4.6 introduced significant changes that the model does NOT know about.
Always cross-reference this directory before suggesting Godot API calls.

## Post-Cutoff Version Timeline

| Version | Release | Risk Level | Key Theme |
|---------|---------|------------|-----------|
| 4.4 | ~Mid 2025 | MEDIUM | Jolt physics option, FileAccess return types, shader texture type changes |
| 4.5 | ~Late 2025 | HIGH | Accessibility (AccessKit), variadic args, @abstract, shader baker, SMAA |
| 4.6 | Jan 2026 | HIGH | Jolt default, glow rework, D3D12 default on Windows, IK restored |

## Verified Sources

- Official docs: https://docs.godotengine.org/en/stable/
- 4.5→4.6 migration: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.6.html
- 4.4→4.5 migration: https://docs.godotengine.org/en/stable/tutorials/migrating/upgrading_to_godot_4.5.html
- Changelog: https://github.com/godotengine/godot/blob/master/CHANGELOG.md
- Release notes: https://godotengine.org/releases/4.6/
