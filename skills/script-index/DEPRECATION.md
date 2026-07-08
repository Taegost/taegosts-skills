# script-index (DEPRECATED)

**Status:** Deprecated
**Deprecated:** 2026-07-07
**Replaced by:** `index-scripts.py` and `update-indexes.py`

---

## Why Deprecated

The `script-index` skill has been replaced by automated index scripts that provide the same functionality with better maintainability:

- **`index-scripts.py`** - Generates script indexes automatically from script files
- **`update-indexes.py`** - Updates existing indexes when scripts change

These automated scripts eliminate the need for a manually-curated skill that required agents to load it first before starting work.

## What Replaces It

The automated index scripts are a drop-in replacement:

| Old (Manual) | New (Automated) |
|--------------|-----------------|
| `script-index` skill (SKILL.md) | `index-scripts.py` generates indexes |
| Manual routing table | Automated script discovery |
| Load skill before coding | Indexes updated automatically |

## Migration Path

**No migration needed.** The automated scripts are a drop-in replacement:

1. The `index-scripts.py` script automatically generates script indexes from the repository structure
2. The `update-indexes.py` script keeps indexes current when scripts are added/removed
3. Agents no longer need to load a skill first - indexes are available automatically

## Original Skill Location

The deprecated skill has been moved to:
```
skills/_deprecated/script-index/SKILL.md
```

## References

- Wave 2 Plan: Script extraction and index infrastructure
- Commit: `cb8f58a` - feat: implement Phase 2 - Index Infrastructure
