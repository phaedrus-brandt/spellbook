# Focus Sync

Nuke all Spellbook-managed primitives and rebuild from the manifest.

## Process

### 1. Read Manifest

Parse `.spellbook.yaml` from project root. If missing, error and suggest
running `/focus init`.

### 2. Resolve Collections

Fetch `collections.yaml` from:
```
https://raw.githubusercontent.com/phrazzld/spellbook/main/collections.yaml
```

For each collection in the manifest, expand to individual skill names.
Merge with directly-listed skills. Deduplicate.

### 3. Nuke Managed Primitives

**This is the critical safety step.** Only remove directories with
`.spellbook` marker files.

For each harness directory (skills and agents):
```bash
find "${DIR}" -maxdepth 2 -name ".spellbook" -type f | while read marker; do
  managed_dir="$(dirname "$marker")"
  rm -rf "$managed_dir"
done
```

### 4. Install Each Skill

For each skill in the resolved list:

```bash
skill="debug"
target="${SKILLS_DIR}/${skill}"
raw="https://raw.githubusercontent.com/phrazzld/spellbook/main"

mkdir -p "$target"
curl -sfL "$raw/skills/$skill/SKILL.md" -o "$target/SKILL.md"
```

**Downloading subdirectories** (references/, scripts/, assets/):

Use the GitHub API to discover directory contents:
```bash
api="https://api.github.com/repos/phrazzld/spellbook/contents/skills/$skill"

for subdir in references scripts assets; do
  files=$(curl -sf "$api/$subdir" 2>/dev/null | \
    python3 -c "import sys,json; [print(f['path']) for f in json.load(sys.stdin)]" 2>/dev/null) || continue
  mkdir -p "$target/$subdir"
  echo "$files" | while read path; do
    fname=$(basename "$path")
    curl -sfL "$raw/$path" -o "$target/$subdir/$fname"
  done
done
```

**Handle nested reference directories** (e.g., references/harnesses/):
```bash
# Check for directories within references/
dirs=$(curl -sf "$api/references" 2>/dev/null | \
  python3 -c "import sys,json; [print(f['name']) for f in json.load(sys.stdin) if f['type']=='dir']" 2>/dev/null) || true
for nested_dir in $dirs; do
  nested_files=$(curl -sf "$api/references/$nested_dir" 2>/dev/null | \
    python3 -c "import sys,json; [print(f['path']) for f in json.load(sys.stdin)]" 2>/dev/null) || continue
  mkdir -p "$target/references/$nested_dir"
  echo "$nested_files" | while read path; do
    fname=$(basename "$path")
    curl -sfL "$raw/$path" -o "$target/references/$nested_dir/$fname"
  done
done
```

### 5. Write Marker

For each installed primitive:
```bash
cat > "$target/.spellbook" << EOF
source: phrazzld/spellbook
name: $skill
installed: $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
```

### 6. Rate Limiting

GitHub API has rate limits (60 req/hour unauthenticated, 5000 with token).
For large manifests, use `gh api` if available (auto-authenticated) or check
for `GITHUB_TOKEN` in environment.

If rate-limited, fall back to cloning the entire repo:
```bash
tmp=$(mktemp -d)
git clone --depth 1 https://github.com/phrazzld/spellbook.git "$tmp"
# Copy from local clone instead of individual API calls
cp -R "$tmp/skills/$skill/" "$target/"
rm -rf "$tmp"
```

### 7. Post-Install

Run harness-specific setup (see `references/harnesses/`).
Report results.
