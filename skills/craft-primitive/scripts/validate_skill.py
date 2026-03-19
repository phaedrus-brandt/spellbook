#!/usr/bin/env python3
"""
Validate agent skill structure and frontmatter.

Usage:
    python validate_skill.py <skill_directory>

Returns JSON with validation results.
"""

import sys
import os
import json
import re
from pathlib import Path

try:
    import yaml  # type: ignore
except ImportError:
    yaml = None

ALLOWED_PROPERTIES = {
    "name",
    "description",
    "license",
    "allowed-tools",
    "metadata",
    "user-invocable",
    "disable-model-invocation",
    "argument-hint",
}


def strip_inline_comment(value):
    """Strip YAML inline comments while preserving quoted # characters."""
    in_single = False
    in_double = False
    escaped = False
    out = []

    for ch in value:
        if escaped:
            out.append(ch)
            escaped = False
            continue
        if ch == "\\":
            escaped = True
            out.append(ch)
            continue
        if ch == "'" and not in_double:
            in_single = not in_single
            out.append(ch)
            continue
        if ch == '"' and not in_single:
            in_double = not in_double
            out.append(ch)
            continue
        if ch == "#" and not in_single and not in_double:
            break
        out.append(ch)

    return "".join(out).rstrip()


def parse_frontmatter(frontmatter_text):
    """Parse the small frontmatter subset used by skills."""
    frontmatter = {}
    current_key = None
    multiline_buffer = []

    for raw_line in frontmatter_text.splitlines():
        line = raw_line.rstrip("\n")

        if current_key:
            if raw_line.startswith("  "):
                multiline_buffer.append(raw_line[2:])
                continue
            if not line.strip():
                multiline_buffer.append("")
                continue

            frontmatter[current_key] = "\n".join(multiline_buffer).strip()
            current_key = None
            multiline_buffer = []

        if not line.strip():
            continue

        if ":" not in line:
            return None, f"Invalid frontmatter line: {line}"

        key, value = line.split(":", 1)
        key = key.strip()
        value = strip_inline_comment(value.strip())

        if not key:
            return None, f"Invalid frontmatter line: {line}"

        if value in {"|", ""}:
            current_key = key
            multiline_buffer = []
        else:
            frontmatter[key] = value

    if current_key:
        frontmatter[current_key] = "\n".join(multiline_buffer).strip()

    return frontmatter, None


def validate_skill(skill_path: str) -> dict:
    """Validate a skill directory and return results."""
    results = {
        "valid": True,
        "errors": [],
        "warnings": [],
        "info": []
    }

    skill_dir = Path(skill_path)

    # Check directory exists
    if not skill_dir.exists():
        results["valid"] = False
        results["errors"].append(f"Directory does not exist: {skill_path}")
        return results

    if not skill_dir.is_dir():
        results["valid"] = False
        results["errors"].append(f"Path is not a directory: {skill_path}")
        return results

    # Check SKILL.md exists
    skill_md = skill_dir / "SKILL.md"
    if not skill_md.exists():
        skill_md_lower = skill_dir / "skill.md"
        if skill_md_lower.exists():
            results["warnings"].append("Found skill.md (lowercase) - recommend SKILL.md")
            skill_md = skill_md_lower
        else:
            results["valid"] = False
            results["errors"].append("Missing SKILL.md file")
            return results

    # Read and parse SKILL.md
    content = skill_md.read_text()

    # Check frontmatter exists
    if not content.startswith("---"):
        results["valid"] = False
        results["errors"].append("Missing YAML frontmatter (must start with ---)")
        return results

    # Extract frontmatter
    match = re.match(r'^---\n(.*?)\n---', content, re.DOTALL)
    if not match:
        results["valid"] = False
        results["errors"].append("Invalid frontmatter format (missing closing ---)")
        return results

    frontmatter_text = match.group(1)
    body = content[match.end():].strip()

    # Parse frontmatter — prefer yaml.safe_load, fallback to manual parser
    if yaml is not None:
        try:
            fm_dict = yaml.safe_load(frontmatter_text)
        except yaml.YAMLError as e:
            results["valid"] = False
            results["errors"].append(f"Invalid YAML in frontmatter: {e}")
            return results
        if fm_dict is not None and not isinstance(fm_dict, dict):
            results["valid"] = False
            results["errors"].append("Frontmatter must be a YAML mapping")
            return results
        fm_dict = fm_dict or {}
    else:
        fm_dict, parse_error = parse_frontmatter(frontmatter_text)
        if parse_error:
            results["valid"] = False
            results["errors"].append(parse_error)
            return results

    # Check for unexpected properties
    unexpected_keys = set(fm_dict) - ALLOWED_PROPERTIES
    if unexpected_keys:
        results["valid"] = False
        results["errors"].append(
            f"Unexpected key(s): {', '.join(sorted(unexpected_keys))}. "
            f"Allowed: {', '.join(sorted(ALLOWED_PROPERTIES))}"
        )

    # Validate required fields: name
    if "name" not in fm_dict:
        results["valid"] = False
        results["errors"].append("Missing required field: name")
    else:
        name = fm_dict["name"]
        if not isinstance(name, str):
            results["valid"] = False
            results["errors"].append(f"Name must be a string, got {type(name).__name__}")
        else:
            name = name.strip()
            if len(name) > 64:
                results["valid"] = False
                results["errors"].append(f"name too long ({len(name)} chars, max 64)")
            if not re.match(r'^[a-z0-9-]+$', name):
                results["valid"] = False
                results["errors"].append("name must be lowercase letters, numbers, and hyphens only")
            if name.startswith('-') or name.endswith('-') or '--' in name:
                results["valid"] = False
                results["errors"].append(f"Name '{name}' cannot start/end with hyphen or contain consecutive hyphens")

            # Name must match directory name
            dir_name = skill_dir.name
            if name != dir_name:
                results["warnings"].append(
                    f"name '{name}' does not match directory name '{dir_name}'"
                )

    # Validate required fields: description
    if "description" not in fm_dict:
        results["valid"] = False
        results["errors"].append("Missing required field: description")
    else:
        desc = fm_dict["description"]
        if not isinstance(desc, str):
            results["valid"] = False
            results["errors"].append(f"Description must be a string, got {type(desc).__name__}")
        else:
            desc = desc.strip()
            if len(desc) > 1024:
                results["valid"] = False
                results["errors"].append(f"description too long ({len(desc)} chars, max 1024)")
            if len(desc) < 50:
                results["warnings"].append(f"description quite short ({len(desc)} chars) - consider adding trigger terms")

    # Warn on command-surface complexity
    argument_hint = fm_dict.get("argument-hint", "")
    if isinstance(argument_hint, str) and argument_hint:
        argument_flags = set(re.findall(r'--[a-z0-9][a-z0-9-]*', argument_hint))
        if len(argument_flags) > 1:
            results["warnings"].append(
                "argument-hint includes multiple flags; keep happy path intent-first"
            )

    # Check body length — hard limits
    body_lines = len(body.split("\n")) if body else 0
    if body_lines > 500:
        results["valid"] = False
        results["errors"].append(f"SKILL.md body is {body_lines} lines (max 500)")
    elif body_lines > 150:
        refs_dir = skill_dir / "references"
        if not refs_dir.exists():
            results["warnings"].append(
                f"SKILL.md body is {body_lines} lines without references/ — extract to references"
            )
        else:
            results["info"].append(
                f"SKILL.md body is {body_lines} lines with references/ — progressive disclosure in use"
            )

    # Warn on slash-command flag overuse in body
    slash_flag_usages = re.findall(r'/[a-z][a-z-]*\s+--[a-z][a-z-]*', body)
    if len(slash_flag_usages) > 3:
        results["warnings"].append(
            f"Detected {len(slash_flag_usages)} slash-command flag examples; consider simplifying command surface"
        )

    # Check scripts are executable
    scripts_dir = skill_dir / "scripts"
    if scripts_dir.exists():
        for script in scripts_dir.iterdir():
            if script.is_file() and script.suffix in [".py", ".sh", ".bash"]:
                if not os.access(script, os.X_OK):
                    results["warnings"].append(f"Script not executable: {script.name} (run chmod +x)")

    # Info about structure
    refs_dir = skill_dir / "references"
    if refs_dir.exists():
        ref_files = list(refs_dir.glob("*.md"))
        results["info"].append(f"Found {len(ref_files)} reference files")

    if scripts_dir.exists():
        script_files = [f for f in scripts_dir.iterdir() if f.is_file()]
        results["info"].append(f"Found {len(script_files)} scripts")

    templates_dir = skill_dir / "templates"
    if templates_dir.exists():
        template_files = list(templates_dir.iterdir())
        results["info"].append(f"Found {len(template_files)} templates")

    return results


def main():
    if len(sys.argv) < 2:
        print(json.dumps({
            "valid": False,
            "errors": ["Usage: validate_skill.py <skill_directory>"],
            "warnings": [],
            "info": []
        }))
        sys.exit(1)

    skill_path = sys.argv[1]
    results = validate_skill(skill_path)

    print(json.dumps(results, indent=2))
    sys.exit(0 if results["valid"] else 1)


if __name__ == "__main__":
    main()
