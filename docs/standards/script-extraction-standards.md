---
tags: [standards, scripts, extraction]
description: Canonical reference for when inline bash blocks in skills should be extracted to standalone scripts.
---

# Script Extraction Standards

Canonical reference for when inline bash blocks in skills should be extracted to standalone scripts.

## When to extract

Inline bash blocks in skills should be extracted to standalone scripts when:

- The block is duplicated across multiple skills
- The block contains complex fallback chains or error handling
- Extraction enables unit testing

## Related standards

Extracted scripts are standalone scripts: the general script rules they follow — script requirements, runtime script path resolution, the `scripts/lib/` shared-library tier, and the `scripts/verify-scripts.sh` gate scope — are canonical in `docs/standards/script-standards.md` and are not duplicated here.
