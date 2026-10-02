#!/usr/bin/env python3
"""Allocate shell panes for review agents in capped `reviews` tabs.

Review tabs are labeled `reviews`, `reviews (2)`, `reviews (3)`, ... and hold at most
MAX_PANES panes each. A request for N panes is placed in the first tab with N free
slots, so one review fan-out stays together. Overflow opens the next numbered tab.
Panes are split to form a grid: the largest pane is split right when it is wide
and down when it is tall.

Prints JSON: {"panes": [{"pane_id": ..., "tab_id": ...}, ...]}
"""

import argparse
import json
import re
import subprocess
import sys

MAX_PANES = 4
CWD = "/Users/mehulkar/dev/vercel/vercel-core"
LABEL = re.compile(r"^reviews(?: \((\d+)\))?$")


def herdr(*args):
    result = subprocess.run(["herdr", *args], capture_output=True, text=True)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or f"herdr {' '.join(args)} failed")
    return json.loads(result.stdout)["result"]


def tab_number(label):
    match = LABEL.match(label or "")
    if not match:
        return None
    return int(match.group(1) or 1)


def tab_label(number):
    return "reviews" if number == 1 else f"reviews ({number})"


def is_idle_shell(pane):
    if pane.get("agent"):
        return False
    info = herdr("pane", "process-info", "--pane", pane["pane_id"])["process_info"]
    processes = info.get("foreground_processes") or []
    return all(proc.get("name") in {"zsh", "bash", "sh", "fish"} for proc in processes)


def review_tabs(workspace):
    tabs = herdr("tab", "list", "--workspace", workspace)["tabs"]
    panes = herdr("pane", "list", "--workspace", workspace)["panes"]
    found = []
    for tab in tabs:
        number = tab_number(tab.get("label"))
        if number is None:
            continue
        tab_panes = [pane for pane in panes if pane.get("tab_id") == tab["tab_id"]]
        found.append({"number": number, "tab_id": tab["tab_id"], "panes": tab_panes})
    return sorted(found, key=lambda tab: tab["number"])


def sole_idle_shell(tab):
    panes = tab["panes"]
    return len(panes) == 1 and (tab.get("fresh") or is_idle_shell(panes[0]))


def free_slots(tab):
    # A tab whose only pane is an idle shell is effectively empty.
    if sole_idle_shell(tab):
        return MAX_PANES
    return MAX_PANES - len(tab["panes"])


def split_largest(tab_id, any_pane_id):
    layout = herdr("pane", "layout", "--pane", any_pane_id)["layout"]
    if layout["tab_id"] != tab_id:
        raise RuntimeError(f"pane {any_pane_id} is not in tab {tab_id}")
    largest = max(layout["panes"], key=lambda pane: pane["rect"]["width"] * pane["rect"]["height"])
    rect = largest["rect"]
    # Terminal cells are about twice as tall as wide; this ratio yields a 2x2 grid.
    direction = "right" if rect["width"] > 3 * rect["height"] else "down"
    created = herdr(
        "pane", "split", largest["pane_id"], "--direction", direction, "--cwd", CWD, "--no-focus",
    )
    return created["pane"]["pane_id"]


def fill(tab, count):
    """Allocate `count` panes in `tab`, reusing an idle sole shell pane."""
    allocated = []
    panes = tab["panes"]
    if sole_idle_shell(tab):
        allocated.append(panes[0]["pane_id"])
    anchor = panes[0]["pane_id"]
    while len(allocated) < count:
        allocated.append(split_largest(tab["tab_id"], anchor))
    return [{"pane_id": pane_id, "tab_id": tab["tab_id"]} for pane_id in allocated]


def create_tab(workspace, number):
    created = herdr(
        "tab", "create", "--workspace", workspace, "--label", tab_label(number), "--cwd", CWD, "--no-focus",
    )
    return {"number": number, "tab_id": created["tab"]["tab_id"], "panes": [created["root_pane"]], "fresh": True}


def allocate(workspace, count):
    result = []
    remaining = count
    while remaining:
        want = min(remaining, MAX_PANES)
        tabs = review_tabs(workspace)
        target = next((tab for tab in tabs if free_slots(tab) >= want), None)
        if target is None:
            used = {tab["number"] for tab in tabs}
            number = next(n for n in range(1, len(used) + 2) if n not in used)
            target = create_tab(workspace, number)
        result.extend(fill(target, want))
        remaining -= want
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", required=True)
    parser.add_argument("--count", type=int, default=1)
    args = parser.parse_args()
    if args.count < 1:
        parser.error("--count must be at least 1")
    try:
        print(json.dumps({"panes": allocate(args.workspace, args.count)}))
    except RuntimeError as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
