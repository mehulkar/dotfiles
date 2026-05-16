---
description: Research a topic and output results as a local HTML webpage
argument-hint: <topic>
allowed-tools: WebSearch, WebFetch, Bash, Write
---

Research the following topic and produce a self-contained HTML report.

Topic: $ARGUMENTS

Steps:
1. If `$ARGUMENTS` is empty, ask the user for a topic before proceeding.
2. Research the topic using WebSearch and WebFetch. Gather enough material to produce a substantive report — key facts, recent developments, notable sources, and differing viewpoints where relevant. Cite sources with their URLs.
3. Create a tmp directory for this report at `/tmp/research-<slug>-<timestamp>/` where `<slug>` is a kebab-case version of the topic and `<timestamp>` is `date +%Y%m%d-%H%M%S`.
4. Write the findings to `index.html` inside that directory. The page should be a single self-contained HTML file (inline CSS, no external assets) with:
   - A clear title and the date the report was generated
   - A short summary / TL;DR
   - Sectioned findings with headings
   - A Sources section listing every URL cited, as clickable links
   - Readable typography, sensible max-width, and dark-mode-friendly styling
5. Print the absolute file path and a `file://` URL the user can open in a browser.

Do not open the browser automatically — just report the path.
