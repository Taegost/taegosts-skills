#!/usr/bin/env bash
# sync-taegosts-skills.sh -- Maintain a persistent clone and sync taegosts-skills
#
# Maintains a persistent clone at $HERMES_HOME/taegosts-skills/ and syncs
# skills, scripts, and tests to $HERMES_HOME/skills/.
#
# Only overwrites files that exist in the repo. Does NOT delete skills
# installed from other sources.
#
# Usage:
#   sync-taegosts-skills.sh [--dry-run]
#
# Environment:
#   HERMES_HOME  -- base directory (default: $HOME)

set -euo pipefail

HERMES_HOME="${HERMES_HOME:-$HOME}"
REPO_URL="${SYNC_REPO_URL:-https://github.com/Taegost/taegosts-skills.git}"
CLONE_DIR="$HERMES_HOME/taegosts-skills"
SKILLS_DIR="$HERMES_HOME/skills"
DRY_RUN=false

if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "[DRY RUN] No changes will be made"
fi

# --- Step 1: Clone or update ---
if [[ ! -d "$CLONE_DIR/.git" ]]; then
    echo "Cloning $REPO_URL to $CLONE_DIR ..."
    if $DRY_RUN; then
        echo "  [DRY RUN] Would clone"
    else
        git clone "$REPO_URL" "$CLONE_DIR" 2>&1 | tail -1
    fi
else
    echo "Updating existing clone at $CLONE_DIR ..."
fi

if ! $DRY_RUN; then
    cd "$CLONE_DIR"
    git fetch origin 2>&1
    git checkout main 2>&1
    git reset --hard origin/main 2>&1 | tail -1
    echo "  On main at $(git rev-parse --short HEAD)"
fi

# --- Step 2: Sync skills (per-skill, additive only) ---
CHANGED=0

sync_skills() {
    local src="$1"
    local dest="$2"

    if [[ ! -d "$src" ]]; then
        echo "  WARN: $src not found, skipping"
        return
    fi

    local synced=0
    local up_to_date=0

    for skill_dir in "$src"/*/; do
        [[ ! -d "$skill_dir" ]] && continue
        local skill_name
        skill_name=$(basename "$skill_dir")
        local dest_skill="$dest/$skill_name"

        if $DRY_RUN; then
            local needs_sync=false
            if [[ ! -d "$dest_skill" ]]; then
                needs_sync=true
            else
                # Compare only files that exist in source
                while IFS= read -r src_file; do
                    local rel="${src_file#"$skill_dir"}"
                    if [[ ! -f "$dest_skill/$rel" ]] || ! diff -q "$src_file" "$dest_skill/$rel" >/dev/null 2>&1; then
                        needs_sync=true
                        break
                    fi
                done < <(find "$skill_dir" -type f)
            fi
            if $needs_sync; then
                echo "  [DRY RUN] Would sync: $skill_name"
                synced=$((synced + 1))
            else
                up_to_date=$((up_to_date + 1))
            fi
        else
            local needs_sync=false
            if [[ ! -d "$dest_skill" ]]; then
                needs_sync=true
            else
                # Compare only files that exist in source
                while IFS= read -r src_file; do
                    local rel="${src_file#"$skill_dir"}"
                    if [[ ! -f "$dest_skill/$rel" ]] || ! diff -q "$src_file" "$dest_skill/$rel" >/dev/null 2>&1; then
                        needs_sync=true
                        break
                    fi
                done < <(find "$skill_dir" -type f)
            fi
            if $needs_sync; then
                mkdir -p "$dest_skill"
                cp -r "$skill_dir/." "$dest_skill/"
                echo "  synced: $skill_name"
                synced=$((synced + 1))
                CHANGED=$((CHANGED + 1))
            else
                up_to_date=$((up_to_date + 1))
            fi
        fi
    done

    echo "  $synced synced, $up_to_date up to date"
}

sync_files() {
    local src="$1"
    local dest="$2"
    local label="$3"

    if [[ ! -d "$src" ]]; then
        echo "  WARN: $src not found, skipping"
        return
    fi

    mkdir -p "$dest"

    local synced=0
    local up_to_date=0

    for src_file in "$src"/*; do
        [[ ! -f "$src_file" ]] && continue
        local filename
        filename=$(basename "$src_file")
        local dest_file="$dest/$filename"

        if $DRY_RUN; then
            if [[ ! -f "$dest_file" ]] || ! diff -q "$src_file" "$dest_file" >/dev/null 2>&1; then
                echo "  [$label] [DRY RUN] Would sync: $filename"
                synced=$((synced + 1))
            else
                up_to_date=$((up_to_date + 1))
            fi
        else
            if [[ ! -f "$dest_file" ]] || ! diff -q "$src_file" "$dest_file" >/dev/null 2>&1; then
                cp "$src_file" "$dest_file"
                echo "  [$label] synced: $filename"
                synced=$((synced + 1))
                CHANGED=$((CHANGED + 1))
            else
                up_to_date=$((up_to_date + 1))
            fi
        fi
    done

    echo "  $synced synced, $up_to_date up to date"
}

echo ""
echo "Syncing skills ..."
sync_skills "$CLONE_DIR/skills" "$SKILLS_DIR"

echo "Syncing scripts ..."
sync_files "$CLONE_DIR/scripts" "$SKILLS_DIR/scripts" "scripts"

echo "Syncing tests ..."
if [[ -d "$CLONE_DIR/tests/scripts" ]]; then
    echo "  test scripts:"
    sync_files "$CLONE_DIR/tests/scripts" "$SKILLS_DIR/tests/scripts" "test-scripts"
fi
if [[ -d "$CLONE_DIR/tests/skills" ]]; then
    for test_dir in "$CLONE_DIR/tests/skills"/*/; do
        [[ ! -d "$test_dir" ]] && continue
        local_name=$(basename "$test_dir")
        echo "  test skills/$local_name:"
        sync_files "$test_dir" "$SKILLS_DIR/tests/skills/$local_name" "test-$local_name"
    done
fi

# --- Step 3: Make scripts executable ---
if ! $DRY_RUN; then
    chmod +x "$SKILLS_DIR/scripts/"*.sh 2>/dev/null || true
    chmod +x "$SKILLS_DIR/tests/scripts/"*.sh 2>/dev/null || true
fi

# --- Summary ---
echo ""
if $DRY_RUN; then
    echo "Dry run complete. No changes made."
elif [[ "$CHANGED" -eq 0 ]]; then
    echo "All up to date. Clone at $CLONE_DIR"
else
    echo "Synced $CHANGED items. Clone at $CLONE_DIR"
fi
