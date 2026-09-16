#!/usr/bin/env python3
"""Print aggregate LLM token usage and cost from a Pi session JSONL file."""

import argparse
import json
import os
from pathlib import Path

TOKEN_FIELDS = ("input", "output", "cacheRead", "cacheWrite")


def usage_objects(entry):
    if entry.get("type") == "message":
        message = entry.get("message") or {}
        usage = message.get("usage")
        if usage:
            yield usage
    elif entry.get("type") in {"compaction", "branch_summary"}:
        usage = entry.get("usage")
        if usage:
            yield usage


def format_count(value):
    return f"{value:,}"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("session", nargs="?", default=os.environ.get("PI_SESSION_FILE"))
    args = parser.parse_args()
    if not args.session:
        parser.error("session path required or PI_SESSION_FILE must be set")

    totals = {field: 0 for field in TOKEN_FIELDS}
    cost = 0.0
    with Path(args.session).expanduser().open() as session:
        for line in session:
            if not line.strip():
                continue
            for usage in usage_objects(json.loads(line)):
                for field in TOKEN_FIELDS:
                    totals[field] += int(usage.get(field) or 0)
                cost += float((usage.get("cost") or {}).get("total") or 0)

    total_tokens = sum(totals.values())
    print(
        "Review cost: "
        f"{format_count(total_tokens)} tokens "
        f"(input {format_count(totals['input'])}, output {format_count(totals['output'])}, "
        f"cache read {format_count(totals['cacheRead'])}, cache write {format_count(totals['cacheWrite'])}); "
        f"${cost:.4f}"
    )


if __name__ == "__main__":
    main()
