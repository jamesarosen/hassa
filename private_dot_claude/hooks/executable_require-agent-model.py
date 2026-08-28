#!/usr/bin/env python3
"""PreToolUse hook that requires an explicit `model` field on agent dispatch.

The Agent/Task tool defaults to inheriting the parent's model, which silently
sends expensive frontier work to subagents. This hook blocks any dispatch
that doesn't pick a model deliberately.

Claude Code accepts family aliases (`sonnet`, `haiku`, `opus`, `fable`),
optionally with bracket params (`sonnet[1m]`).

Cursor's Task tool uses full slugs that include the thinking/effort level,
and the allowlist changes per session. Composer and Grok are allowed at
every thinking/effort level. Fast variants are not: they cost more and
do less thinking.

Allowed Cursor patterns:

  claude-sonnet-5-thinking-high
  claude-opus-5-thinking-high
  claude-4.6-sonnet-medium-thinking
  claude-opus-5[effort=high]
  composer-2.5
  composer-2.5[fast=false]
  cursor-grok-4.6-high
  cursor-grok-4.5-medium
  grok-4.5[effort=high]
  gpt-5.6-sol-high
  gpt-5.6-terra-medium

Denied: `inherit`, `composer-2.5-fast`, `cursor-grok-4.6-high-fast`,
`*[fast=true]`.
"""

from __future__ import annotations

import json
import re
import sys

_AGENT_TOOLS = frozenset({"Task", "Agent"})
_CLAUDE_ALIASES = frozenset({"sonnet", "haiku", "opus", "fable"})
_INHERIT = frozenset({"inherit", ""})
_FAST_FALSEY = frozenset({"false", "0", "no", ""})

# Cursor docs: append `[id=value,…]` to pin effort/context/fast.
# Claude Code: `sonnet[1m]`, `opus[1m]`.
_TRAILING_BRACKETS = re.compile(r"\[[^\]]*\]$")
_FAST_TOKEN = re.compile(r"(?:^|[-.])fast(?:[-.]|$)")

# Full model IDs are kebab/dot slugs with at least one separator, e.g.
# claude-sonnet-5-thinking-high, composer-2.5, cursor-grok-4.6-high.
_MODEL_SLUG = re.compile(r"^[a-z][a-z0-9]*(?:[-.][a-z0-9]+)+$")

_EXAMPLES = (
    "sonnet, haiku, opus; or a Cursor slug such as "
    "claude-sonnet-5-thinking-high, composer-2.5, cursor-grok-4.6-high "
    "(any thinking level; not *-fast)"
)


def _deny(message: str) -> None:
    json.dump(
        {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": message,
            }
        },
        sys.stdout,
    )
    sys.exit(0)


def _normalize(model: str) -> str:
    return _TRAILING_BRACKETS.sub("", model.strip().lower())


def _bracket_params(model: str) -> dict[str, str]:
    match = _TRAILING_BRACKETS.search(model.strip().lower())
    if not match:
        return {}
    inner = match.group(0)[1:-1]
    params: dict[str, str] = {}
    if not inner:
        return params
    for part in inner.split(","):
        if "=" not in part:
            continue
        key, value = part.split("=", 1)
        params[key.strip()] = value.strip()
    return params


def is_fast_variant(model: object) -> bool:
    """True for exploded `-fast` slugs or `[fast=true]` (not `[fast=false]`)."""
    if not isinstance(model, str):
        return False
    raw = model.strip().lower()
    params = _bracket_params(raw)
    if "fast" in params and params["fast"] not in _FAST_FALSEY:
        return True
    return bool(_FAST_TOKEN.search(_normalize(raw)))


def is_allowed_model(model: object) -> bool:
    """True when `model` is an explicit non-fast Claude alias or Cursor slug."""
    if not isinstance(model, str) or is_fast_variant(model):
        return False
    base = _normalize(model)
    if base in _INHERIT:
        return False
    if base in _CLAUDE_ALIASES:
        return True
    return bool(_MODEL_SLUG.match(base))


def main() -> None:
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(1)

    if input_data.get("tool_name") not in _AGENT_TOOLS:
        sys.exit(0)

    tool_input = input_data.get("tool_input", {}) or {}
    model = tool_input.get("model")

    if not model:
        _deny(
            "Agent dispatch requires an explicit `model` field. "
            f"Pick one deliberately: {_EXAMPLES}."
        )

    if is_fast_variant(model):
        _deny(
            "Fast model variants are not allowed "
            f"(got {model!r}). Drop `-fast` or `fast=true` and use the "
            "standard slug at the same thinking level "
            "(e.g. composer-2.5, cursor-grok-4.6-high)."
        )

    if not is_allowed_model(model):
        _deny(
            "Agent `model` must be an explicit pick, not inherit. "
            f"Accepted: {_EXAMPLES} (got {model!r})."
        )

    sys.exit(0)


if __name__ == "__main__":
    main()
