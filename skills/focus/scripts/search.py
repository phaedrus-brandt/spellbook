#!/usr/bin/env python3
"""Spellbook semantic search. Self-contained — fetches and caches embeddings.json from GitHub.

Usage:
    python3 search.py "payment webhook integration"
    python3 search.py --project-dir /path/to/project
    python3 search.py "query" --top 10 --type skill

Requires: GEMINI_API_KEY or GOOGLE_API_KEY for query embedding.
Embeddings index is pre-computed and fetched from GitHub (no key needed for corpus).
"""

import json
import math
import os
import sys
import time
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.error import HTTPError

REPO = "phrazzld/spellbook"
BRANCH = "master"
RAW = f"https://raw.githubusercontent.com/{REPO}/{BRANCH}"
CACHE_DIR = Path.home() / ".cache" / "spellbook"
CACHE_FILE = CACHE_DIR / "embeddings.json"
CACHE_TTL = 86400  # 24 hours
MODEL = "gemini-embedding-2-preview"
DEFAULT_TOP = 15


def fetch_embeddings() -> dict:
    """Fetch embeddings.json from GitHub, with local caching."""
    CACHE_DIR.mkdir(parents=True, exist_ok=True)

    # Use cache if fresh
    if CACHE_FILE.exists():
        age = time.time() - CACHE_FILE.stat().st_mtime
        if age < CACHE_TTL:
            return json.loads(CACHE_FILE.read_text(encoding="utf-8"))
        print("  Cache stale, refreshing...", file=sys.stderr)

    # Fetch from GitHub
    url = f"{RAW}/embeddings.json"
    print(f"  Fetching embeddings index from GitHub...", file=sys.stderr)
    try:
        req = Request(url, headers={"User-Agent": "spellbook-focus"})
        with urlopen(req, timeout=30) as resp:
            data = resp.read()
        CACHE_FILE.write_bytes(data)
        print(f"  Cached: {len(data) // 1024} KB", file=sys.stderr)
        return json.loads(data)
    except (HTTPError, Exception) as e:
        if CACHE_FILE.exists():
            print(f"  Fetch failed ({e}), using stale cache", file=sys.stderr)
            return json.loads(CACHE_FILE.read_text(encoding="utf-8"))
        print(f"  Error: {e}", file=sys.stderr)
        sys.exit(1)


def cosine_similarity(a: list[float], b: list[float]) -> float:
    dot = sum(x * y for x, y in zip(a, b))
    mag_a = math.sqrt(sum(x * x for x in a))
    mag_b = math.sqrt(sum(x * x for x in b))
    if mag_a == 0 or mag_b == 0:
        return 0.0
    return dot / (mag_a * mag_b)


def embed_query(text: str, dims: int) -> list[float]:
    """Embed a query using Gemini Embedding 2."""
    from google import genai

    api_key = os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")
    if not api_key:
        print("Error: GEMINI_API_KEY or GOOGLE_API_KEY required", file=sys.stderr)
        sys.exit(1)
    client = genai.Client(api_key=api_key)
    result = client.models.embed_content(
        model=MODEL,
        contents=text,
        config={"output_dimensionality": dims, "task_type": "RETRIEVAL_QUERY"},
    )
    return result.embeddings[0].values


def synthesize_project_context(project_dir: Path) -> str:
    """Read project signals and synthesize a description for embedding."""
    parts = []

    for name in ["CLAUDE.md", "README.md"]:
        f = project_dir / name
        if f.exists():
            parts.append(f.read_text(encoding="utf-8")[:2000])
            break

    pkg = project_dir / "package.json"
    if pkg.exists():
        try:
            data = json.loads(pkg.read_text(encoding="utf-8"))
            deps = list(data.get("dependencies", {}).keys())
            dev = list(data.get("devDependencies", {}).keys())
            if deps:
                parts.append(f"Dependencies: {', '.join(deps[:30])}")
            if dev:
                parts.append(f"Dev dependencies: {', '.join(dev[:20])}")
        except json.JSONDecodeError:
            pass

    for manifest, label in [
        ("go.mod", "Go module"),
        ("mix.exs", "Elixir project"),
        ("Cargo.toml", "Rust project"),
        ("requirements.txt", "Python deps"),
        ("pyproject.toml", "Python project"),
    ]:
        f = project_dir / manifest
        if f.exists():
            parts.append(f"{label}: {f.read_text(encoding='utf-8')[:1000]}")

    dirs = [
        d.name
        for d in sorted(project_dir.iterdir())
        if d.is_dir() and not d.name.startswith(".")
    ][:20]
    if dirs:
        parts.append(f"Directories: {', '.join(dirs)}")

    return "\n".join(parts) if parts else "General software project"


def main():
    top_n = DEFAULT_TOP
    type_filter = None
    query = None
    project_dir = None
    output_json = "--json" in sys.argv

    args = sys.argv[1:]
    i = 0
    while i < len(args):
        if args[i] == "--top" and i + 1 < len(args):
            top_n = int(args[i + 1])
            i += 2
        elif args[i] == "--type" and i + 1 < len(args):
            type_filter = args[i + 1]
            i += 2
        elif args[i] == "--project-dir" and i + 1 < len(args):
            project_dir = Path(args[i + 1])
            i += 2
        elif args[i] == "--json":
            i += 1
        elif not args[i].startswith("-"):
            query = args[i]
            i += 1
        else:
            i += 1

    if not query and not project_dir:
        print("Usage: search.py <query> | --project-dir <path>", file=sys.stderr)
        print("  --top N        Number of results (default 15)", file=sys.stderr)
        print("  --type skill   Filter by type (skill|agent)", file=sys.stderr)
        print("  --json         Output as JSON", file=sys.stderr)
        sys.exit(1)

    # Load embeddings (fetches from GitHub if needed)
    data = fetch_embeddings()
    items = data["items"]
    dims = data["dimensions"]

    if type_filter:
        items = [item for item in items if item["type"] == type_filter]

    # Build query text
    if project_dir:
        query_text = synthesize_project_context(project_dir)
        if not output_json:
            print(f"  Analyzing project ({len(query_text)} chars)...", file=sys.stderr)
    else:
        query_text = query

    # Embed query
    query_vec = embed_query(query_text, dims)

    # Rank by similarity
    scored = []
    for item in items:
        sim = cosine_similarity(query_vec, item["embedding"])
        scored.append((sim, item))
    scored.sort(key=lambda x: x[0], reverse=True)

    # Output
    if output_json:
        results = []
        for score, item in scored[:top_n]:
            results.append({
                "score": round(score, 4),
                "type": item["type"],
                "name": item["name"],
                "source": item["source"],
                "fqn": item["fqn"],
                "description": item["description"][:200],
            })
        print(json.dumps(results, indent=2))
    else:
        header = query_text[:80] if query else f"project: {project_dir}"
        print(f"\nTop {top_n} matches for: {header}{'...' if len(str(header)) > 80 else ''}\n")
        for rank, (score, item) in enumerate(scored[:top_n], 1):
            marker = "*" if score > 0.7 else " " if score > 0.5 else "."
            print(f"  {marker} {rank:2d}. [{item['type']:5s}] {item['fqn']}")
            print(f"       score: {score:.4f}  — {item['description'][:100]}")
            print()


if __name__ == "__main__":
    main()
