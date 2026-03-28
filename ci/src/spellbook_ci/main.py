"""Spellbook CI pipeline — local-first quality gates via Dagger."""

from typing import Annotated

import anyio

import dagger
from dagger import DefaultPath, Doc, Ignore, dag, function, object_type

# Files to check per gate
SHELL_FILES = [
    "bootstrap.sh",
    "scripts/generate-index.sh",
    "scripts/check-vendored-copies.sh",
    "skills/reflect/scripts/gather_evidence.sh",
    "harnesses/claude/hooks/shaping-ripple.sh",
]

PYTHON_HOOK_FILES = [
    "harnesses/claude/hooks/check-todo-quality.py",
    "harnesses/claude/hooks/codex-post-feedback.py",
    "harnesses/claude/hooks/codex-session-init.py",
    "harnesses/claude/hooks/disk-space-guard.py",
    "harnesses/claude/hooks/env-var-newline-guard.py",
    "harnesses/claude/hooks/exa-research-reminder.py",
    "harnesses/claude/hooks/exclusion-guard.py",
    "harnesses/claude/hooks/fix-what-you-touch.py",
    "harnesses/claude/hooks/github-cli-guard.py",
    "harnesses/claude/hooks/permission-auto-approve.py",
    "harnesses/claude/hooks/portable-code-guard.py",
    "harnesses/claude/hooks/session-health-check.py",
    "harnesses/claude/hooks/stop-quality-gate.py",
    "harnesses/claude/hooks/time-context.py",
    "harnesses/claude/hooks/destructive-command-guard.py",
    "harnesses/claude/hooks/block-master-push.py",
]

PYTHON_SCRIPT_FILES = [
    "scripts/embeddings_cache.py",
    "scripts/gemini_embeddings.py",
    "scripts/generate-embeddings.py",
    "scripts/lib/search_core.py",
    "scripts/search-embeddings.py",
]

YAML_FILES = [
    "index.yaml",
    "registry.yaml",
    ".spellbook.yaml",
]


def _lint_container(source: dagger.Directory) -> dagger.Container:
    """Base container with shellcheck and yamllint installed."""
    return (
        dag.container()
        .from_("python:3.12-slim")
        .with_exec(["apt-get", "update", "-qq"])
        .with_exec(
            [
                "apt-get",
                "install",
                "-y",
                "-qq",
                "--no-install-recommends",
                "shellcheck",
            ]
        )
        .with_exec(["pip", "install", "-q", "yamllint"])
        .with_directory("/src", source)
        .with_workdir("/src")
    )


@object_type
class SpellbookCi:
    """Local CI pipeline for the spellbook repo."""

    @function
    async def lint_yaml(
        self,
        source: Annotated[
            dagger.Directory,
            DefaultPath("/"),
            Ignore([".git", "__pycache__", ".venv", "ci"]),
            Doc("Repo source directory"),
        ],
    ) -> str:
        """Validate YAML files parse correctly."""
        ctr = _lint_container(source)
        # yamllint with relaxed config — just check valid YAML, not style
        for f in YAML_FILES:
            ctr = ctr.with_exec(["python3", "-c", f"import yaml; yaml.safe_load(open('{f}'))"])
        return await ctr.stdout()

    @function
    async def lint_shell(
        self,
        source: Annotated[
            dagger.Directory,
            DefaultPath("/"),
            Ignore([".git", "__pycache__", ".venv", "ci"]),
        ],
    ) -> str:
        """Run shellcheck on all bash scripts (errors only)."""
        ctr = _lint_container(source)
        # --severity=error: only actual errors, not style warnings
        ctr = ctr.with_exec(["shellcheck", "--severity=error"] + SHELL_FILES)
        return await ctr.stdout()

    @function
    async def lint_python(
        self,
        source: Annotated[
            dagger.Directory,
            DefaultPath("/"),
            Ignore([".git", "__pycache__", ".venv", "ci"]),
        ],
    ) -> str:
        """Syntax-check all Python files via py_compile."""
        ctr = _lint_container(source)
        all_py = PYTHON_HOOK_FILES + PYTHON_SCRIPT_FILES
        for f in all_py:
            ctr = ctr.with_exec(["python3", "-m", "py_compile", f])
        return await ctr.stdout()

    @function
    async def check_frontmatter(
        self,
        source: Annotated[
            dagger.Directory,
            DefaultPath("/"),
            Ignore([".git", "__pycache__", ".venv", "ci"]),
        ],
    ) -> str:
        """Validate SKILL.md and agent frontmatter: required fields, line limits."""
        script = r'''
import sys, os, yaml

errors = []

# Check skills
for name in sorted(os.listdir("skills")):
    path = f"skills/{name}/SKILL.md"
    if not os.path.isfile(path):
        continue
    with open(path) as f:
        content = f.read()
    lines = content.splitlines()

    # Line count check
    if len(lines) > 500:
        errors.append(f"{path}: {len(lines)} lines (max 500)")

    # Parse frontmatter
    if not content.startswith("---"):
        errors.append(f"{path}: missing frontmatter")
        continue
    parts = content.split("---", 2)
    if len(parts) < 3:
        errors.append(f"{path}: malformed frontmatter")
        continue
    try:
        fm = yaml.safe_load(parts[1])
    except yaml.YAMLError as e:
        errors.append(f"{path}: invalid YAML frontmatter: {e}")
        continue
    if not fm or not isinstance(fm, dict):
        errors.append(f"{path}: empty frontmatter")
        continue
    if "name" not in fm:
        errors.append(f"{path}: missing 'name' in frontmatter")
    if "description" not in fm:
        errors.append(f"{path}: missing 'description' in frontmatter")

# Check agents
for name in sorted(os.listdir("agents")):
    if not name.endswith(".md"):
        continue
    path = f"agents/{name}"
    with open(path) as f:
        content = f.read()
    if not content.startswith("---"):
        errors.append(f"{path}: missing frontmatter")
        continue
    parts = content.split("---", 2)
    if len(parts) < 3:
        errors.append(f"{path}: malformed frontmatter")
        continue
    try:
        fm = yaml.safe_load(parts[1])
    except yaml.YAMLError as e:
        errors.append(f"{path}: invalid YAML frontmatter: {e}")
        continue
    if not fm or not isinstance(fm, dict):
        errors.append(f"{path}: empty frontmatter")
        continue
    if "name" not in fm:
        errors.append(f"{path}: missing 'name' in frontmatter")
    if "description" not in fm:
        errors.append(f"{path}: missing 'description' in frontmatter")

if errors:
    for e in errors:
        print(f"FAIL: {e}", file=sys.stderr)
    sys.exit(1)
print(f"OK: all frontmatter valid")
'''
        return await (
            _lint_container(source)
            .with_exec(["python3", "-c", script])
            .stdout()
        )

    @function
    async def check_index_drift(
        self,
        source: Annotated[
            dagger.Directory,
            DefaultPath("/"),
            Ignore([".git", "__pycache__", ".venv", "ci"]),
        ],
    ) -> str:
        """Verify index.yaml matches what generate-index.sh would produce."""
        # Strip the timestamp comment before diffing — it changes every run
        return await (
            _lint_container(source)
            .with_exec(["sh", "-c", "grep -v '^# Generated:' index.yaml > /tmp/index-committed.yaml"])
            .with_exec(["bash", "scripts/generate-index.sh"])
            .with_exec(["sh", "-c", "grep -v '^# Generated:' index.yaml > /tmp/index-generated.yaml"])
            .with_exec(["diff", "-u", "/tmp/index-committed.yaml", "/tmp/index-generated.yaml"])
            .stdout()
        )

    @function
    async def check_vendored_copies(
        self,
        source: Annotated[
            dagger.Directory,
            DefaultPath("/"),
            Ignore([".git", "__pycache__", ".venv", "ci"]),
        ],
    ) -> str:
        """Verify vendored copies match their canonical sources."""
        return await (
            _lint_container(source)
            .with_exec(["bash", "scripts/check-vendored-copies.sh"])
            .stdout()
        )

    @function
    async def test_bun(
        self,
        source: Annotated[
            dagger.Directory,
            DefaultPath("/"),
            Ignore([".git", "__pycache__", ".venv", "ci"]),
        ],
    ) -> str:
        """Run Bun tests for the research skill."""
        return await (
            dag.container()
            .from_("oven/bun:latest")
            .with_directory("/src", source)
            .with_workdir("/src/skills/research")
            .with_exec(["bun", "test"])
            .stdout()
        )

    @function
    async def check(
        self,
        source: Annotated[
            dagger.Directory,
            DefaultPath("/"),
            Ignore([".git", "__pycache__", ".venv", "ci"]),
            Doc("Repo source directory"),
        ],
    ) -> str:
        """Run all quality gates. Exits non-zero if any fail."""
        results: list[tuple[str, bool, str]] = []

        async def run_gate(name: str, coro):
            try:
                output = await coro
                results.append((name, True, output.strip() if output else "OK"))
            except dagger.ExecError as e:
                results.append((name, False, e.stderr.strip() if e.stderr else str(e)))
            except Exception as e:
                results.append((name, False, str(e)))

        async with anyio.create_task_group() as tg:
            tg.start_soon(run_gate, "lint-yaml", self.lint_yaml(source))
            tg.start_soon(run_gate, "lint-shell", self.lint_shell(source))
            tg.start_soon(run_gate, "lint-python", self.lint_python(source))
            tg.start_soon(run_gate, "check-frontmatter", self.check_frontmatter(source))
            tg.start_soon(run_gate, "check-index-drift", self.check_index_drift(source))
            tg.start_soon(run_gate, "check-vendored-copies", self.check_vendored_copies(source))
            tg.start_soon(run_gate, "test-bun", self.test_bun(source))

        # Format results
        lines = ["Spellbook CI Results", "=" * 40]
        passed = 0
        failed = 0
        for name, ok, msg in sorted(results):
            status = "PASS" if ok else "FAIL"
            if ok:
                passed += 1
            else:
                failed += 1
            lines.append(f"  {status}  {name}")
            if not ok:
                for line in msg.splitlines()[:5]:
                    lines.append(f"         {line}")
        lines.append("=" * 40)
        lines.append(f"{passed} passed, {failed} failed")

        summary = "\n".join(lines)

        if failed > 0:
            raise Exception(summary)

        return summary
