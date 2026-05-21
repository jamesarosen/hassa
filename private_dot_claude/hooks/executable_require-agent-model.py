#!/usr/bin/env python3
"""PreToolUse hook that requires an explicit `model` field on agent dispatch.

The Agent/Task tool defaults to inheriting the parent's model, which silently
sends expensive Opus work to subagents. This hook blocks any dispatch that
doesn't pick a model deliberately (sonnet, haiku, or opus).
"""

import json
import sys

_AGENT_TOOLS = frozenset({"Task", "Agent"})
_ALLOWED_MODELS = frozenset({"sonnet", "haiku", "opus"})


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
            "Pick one deliberately: sonnet, haiku, or opus."
        )

    if model not in _ALLOWED_MODELS:
        _deny(
            f"Agent `model` must be one of sonnet, haiku, or opus (got {model!r})."
        )

    sys.exit(0)


if __name__ == "__main__":
    main()
