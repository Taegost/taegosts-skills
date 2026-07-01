#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Usage: scan-repo-structure.sh [directory]"
  echo "Scan repo for ecosystem, languages, frameworks, config files."
  echo "Output: JSON with {ecosystem, monorepo, languages[], frameworks[], config_files[]}"
  echo "Exit codes: 0 (success), 1 (error)"
  exit 0
fi

dir="${1:-.}"
[[ ! -d "$dir" ]] && echo "directory not found" >&2 && exit 1

echo "$dir" | grep -qE '[;&|$\`]' && echo "invalid characters" >&2 && exit 1

ecosystem="unknown"
monorepo=false
languages=()
frameworks=()
config_files=()

# Detect ecosystem
[[ -f "$dir/package.json" ]] && ecosystem="node" && config_files+=("package.json")
[[ -f "$dir/Gemfile" ]] && ecosystem="ruby" && config_files+=("Gemfile")
[[ -f "$dir/go.mod" ]] && ecosystem="go" && config_files+=("go.mod")
[[ -f "$dir/requirements.txt" || -f "$dir/pyproject.toml" || -f "$dir/setup.py" ]] && ecosystem="python" && [[ -f "$dir/requirements.txt" ]] && config_files+=("requirements.txt")
[[ -f "$dir/Cargo.toml" ]] && ecosystem="rust" && config_files+=("Cargo.toml")
[[ -f "$dir/pom.xml" || -f "$dir/build.gradle" ]] && ecosystem="java"

# Detect languages
find "$dir" -maxdepth 3 -name "*.py" 2>/dev/null | head -1 | grep -q . && languages+=("python")
find "$dir" -maxdepth 3 -name "*.js" 2>/dev/null | head -1 | grep -q . && languages+=("javascript")
find "$dir" -maxdepth 3 -name "*.ts" 2>/dev/null | head -1 | grep -q . && languages+=("typescript")
find "$dir" -maxdepth 3 -name "*.rb" 2>/dev/null | head -1 | grep -q . && languages+=("ruby")
find "$dir" -maxdepth 3 -name "*.go" 2>/dev/null | head -1 | grep -q . && languages+=("go")
find "$dir" -maxdepth 3 -name "*.rs" 2>/dev/null | head -1 | grep -q . && languages+=("rust")
find "$dir" -maxdepth 3 -name "*.java" 2>/dev/null | head -1 | grep -q . && languages+=("java")
find "$dir" -maxdepth 3 -name "*.sh" 2>/dev/null | head -1 | grep -q . && languages+=("shell")

# Detect frameworks
[[ -f "$dir/package.json" ]] && grep -q "react" "$dir/package.json" 2>/dev/null && frameworks+=("react")
[[ -f "$dir/package.json" ]] && grep -q "vue" "$dir/package.json" 2>/dev/null && frameworks+=("vue")
[[ -f "$dir/package.json" ]] && grep -q "next" "$dir/package.json" 2>/dev/null && frameworks+=("nextjs")
[[ -f "$dir/Gemfile" ]] && grep -q "rails" "$dir/Gemfile" 2>/dev/null && frameworks+=("rails")
[[ -f "$dir/requirements.txt" ]] && grep -q "django" "$dir/requirements.txt" 2>/dev/null && frameworks+=("django")
[[ -f "$dir/requirements.txt" ]] && grep -q "flask" "$dir/requirements.txt" 2>/dev/null && frameworks+=("flask")

# Detect monorepo
[[ -f "$dir/lerna.json" || -f "$dir/nx.json" || -d "$dir/packages" ]] && monorepo=true
[[ -f "$dir/package.json" ]] && grep -q "workspaces" "$dir/package.json" 2>/dev/null && monorepo=true

# Detect common config files
[[ -f "$dir/Dockerfile" ]] && config_files+=("Dockerfile")
[[ -f "$dir/docker-compose.yml" || -f "$dir/docker-compose.yaml" ]] && config_files+=("docker-compose.yml")
[[ -d "$dir/.github/workflows" ]] && config_files+=(".github/workflows")
[[ -f "$dir/Makefile" ]] && config_files+=("Makefile")
[[ -f "$dir/CLAUDE.md" || -f "$dir/AGENTS.md" ]] && config_files+=("CLAUDE.md/AGENTS.md")

# Build JSON arrays
json_array() {
  local arr=("$@")
  if [[ ${#arr[@]} -eq 0 ]]; then echo "[]"; return; fi
  printf '['
  for i in "${!arr[@]}"; do
    [[ $i -gt 0 ]] && printf ','
    printf '"%s"' "${arr[$i]}"
  done
  printf ']'
}

cat <<JSONEOF
{
  "ecosystem": "$ecosystem",
  "monorepo": $monorepo,
  "languages": $(json_array "${languages[@]+"${languages[@]}"}"),
  "frameworks": $(json_array "${frameworks[@]+"${frameworks[@]}"}"),
  "config_files": $(json_array "${config_files[@]+"${config_files[@]}"}")
}
JSONEOF
