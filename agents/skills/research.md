---
description: Research a topic and output results as a local HTML slideshow
argument-hint: <topic>
allowed-tools: WebSearch, WebFetch, Bash, Write
---

Research the following topic and produce a self-contained HTML slideshow.

Topic: $ARGUMENTS

Steps:
1. If `$ARGUMENTS` is empty, ask the user for a topic before proceeding.
2. Research the topic using WebSearch and WebFetch (and, when relevant, by reading files in the current repo). Gather enough material to produce a substantive deck — key facts, recent developments, notable sources, and differing viewpoints where relevant. Cite sources with their URLs.
3. Create a tmp directory for this report at `/tmp/research-<slug>-<timestamp>/` where `<slug>` is a kebab-case version of the topic and `<timestamp>` is `date +%Y%m%d-%H%M%S`.
4. Write the findings to `index.html` inside that directory as a **single self-contained HTML slideshow** (inline CSS + inline JS, no external assets). Follow the structure described in the "Slideshow shape" and "Slideshow template" sections below.
5. Print the absolute file path and a `file://` URL the user can open in a browser. Do not open the browser automatically.

## Slideshow shape

- 8–14 slides. Each slide focuses on one idea — prefer short bullets and visual structure over long paragraphs.
- First slide: title + one-sentence framing.
- Final slide: Sources, with clickable links to every URL cited (plus key in-repo file paths if the research read source code).
- Use the visual primitives in the template: bullet lists, small two-column card grids, ASCII / Mermaid-free diagrams in `<div class="ascii">`, code blocks via `<pre><code>`, and small tables. Avoid walls of prose.
- Content is centered on screen (vertically and horizontally) inside a centered max-width column. Prose is centered; code, lists, tables, and diagrams stay left-aligned within that centered column for readability.
- Keyboard navigation: ←/→/Space/PageUp/PageDown to step, Home/End to jump, `f` toggles fullscreen. The deck must deep-link via `#<n>` hash and restore the slide on reload.
- Dark-mode-friendly styling. Inline CSS only — no external fonts, no remote assets.

## Slideshow template

Use the following structure (adapt copy, slide count, and per-slide content to the topic; keep the CSS, layout, and JS as-is unless the topic genuinely needs a different visual primitive):

```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>{{TOPIC}} — Slides</title>
    <style>
      :root {
        color-scheme: dark;
        --bg: #0b0d10;
        --bg-elev: #14181d;
        --bg-code: #0f1318;
        --fg: #e6e9ee;
        --fg-dim: #9aa3ad;
        --accent: #5cc8ff;
        --accent-2: #b78bff;
        --border: #232a32;
        --ok: #6ad48f;
        --err: #ff7a7a;
        --warn: #f0b86b;
      }
      * { box-sizing: border-box; }
      html, body {
        margin: 0;
        height: 100%;
        background: var(--bg);
        color: var(--fg);
        font: 18px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", "Helvetica Neue", Arial, sans-serif;
        -webkit-font-smoothing: antialiased;
        overflow: hidden;
      }
      .deck { position: relative; width: 100vw; height: 100vh; }
      .slide {
        position: absolute;
        inset: 0;
        display: none;
        padding: 56px 72px 80px;
        overflow: auto;
        justify-content: center;
        align-items: center;
        text-align: center;
      }
      .slide.active { display: flex; flex-direction: column; }
      .slide > * { width: 100%; max-width: 880px; }
      .slide ul { text-align: left; margin-left: auto; margin-right: auto; }
      .slide pre, .slide .ascii { margin-left: auto; margin-right: auto; text-align: left; }
      .slide table { margin-left: auto; margin-right: auto; }
      .pillrow { justify-content: center; display: flex; gap: 8px; flex-wrap: wrap; margin: 8px 0 16px; }
      .grid2 { margin-left: auto; margin-right: auto; display: grid; grid-template-columns: 1fr 1fr; gap: 18px; }
      .eyebrow {
        font-size: 12px;
        letter-spacing: 0.12em;
        text-transform: uppercase;
        color: var(--fg-dim);
        margin-bottom: 12px;
      }
      h1 { font-size: 40px; line-height: 1.15; margin: 0 0 16px; letter-spacing: -0.01em; }
      h2 { font-size: 28px; line-height: 1.2; margin: 0 0 24px; letter-spacing: -0.005em; }
      h2 .accent { color: var(--accent); }
      .title-slide h1 { font-size: 52px; }
      .lede { font-size: 20px; color: var(--fg-dim); margin: 0 0 20px; }
      ul { padding-left: 22px; margin: 0 0 16px; }
      li { margin: 8px 0; }
      code, .mono {
        font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Monaco, Consolas, monospace;
        font-size: 0.92em;
      }
      code { background: var(--bg-code); border: 1px solid var(--border); padding: 1px 6px; border-radius: 4px; }
      pre { background: var(--bg-code); border: 1px solid var(--border); padding: 14px 18px; border-radius: 8px; font-size: 14px; overflow: auto; }
      .ascii { white-space: pre; background: var(--bg-code); border: 1px solid var(--border); border-radius: 8px; padding: 14px 18px; font: 13px/1.5 ui-monospace, monospace; overflow: auto; }
      .card { background: var(--bg-elev); border: 1px solid var(--border); border-radius: 10px; padding: 16px 18px; }
      .card h3 { margin: 0 0 6px; font-size: 16px; color: var(--accent-2); }
      .card p { margin: 0; color: var(--fg-dim); font-size: 14px; }
      table { border-collapse: collapse; font-size: 15px; }
      th, td { border: 1px solid var(--border); padding: 8px 12px; text-align: left; vertical-align: top; }
      th { background: var(--bg-elev); color: var(--fg-dim); font-weight: 600; }
      .ok { color: var(--ok); } .err { color: var(--err); } .warn { color: var(--warn); }
      .pill { display: inline-block; padding: 4px 10px; border-radius: 999px; background: var(--bg-elev); border: 1px solid var(--border); font-size: 12px; color: var(--fg-dim); }
      .nav { position: absolute; right: 24px; bottom: 18px; display: flex; gap: 12px; align-items: center; color: var(--fg-dim); font-size: 13px; }
      .nav button { background: var(--bg-elev); border: 1px solid var(--border); color: var(--fg); font: inherit; padding: 6px 12px; border-radius: 6px; cursor: pointer; }
      .nav button:hover { border-color: var(--accent); }
      .counter { font-variant-numeric: tabular-nums; }
      .hint { position: absolute; left: 24px; bottom: 18px; color: var(--fg-dim); font-size: 12px; }
      a { color: var(--accent); text-decoration: none; }
      a:hover { text-decoration: underline; }
    </style>
  </head>
  <body>
    <div class="deck" id="deck">

      <!-- Slide 1: title -->
      <section class="slide active title-slide">
        <div class="eyebrow">Research · {{DATE}}</div>
        <h1>{{TOPIC}}</h1>
        <p class="lede">{{ONE_SENTENCE_FRAMING}}</p>
      </section>

      <!-- Add 7–13 content slides here. Examples of patterns to use:

           Bullet slide:
           <section class="slide">
             <div class="eyebrow">Section name</div>
             <h2>Slide headline</h2>
             <ul><li>...</li></ul>
           </section>

           Diagram slide:
           <section class="slide">
             <div class="eyebrow">Flow</div>
             <h2>How it works</h2>
             <div class="ascii">step 1
  └─ step 2
       └─ step 3</div>
           </section>

           Two-card slide:
           <section class="slide">
             <h2>Trade-offs</h2>
             <div class="grid2">
               <div class="card"><h3>Pros</h3><p>...</p></div>
               <div class="card"><h3>Cons</h3><p>...</p></div>
             </div>
           </section>

           Table / code slide as needed.
      -->

      <!-- Final slide: sources -->
      <section class="slide">
        <div class="eyebrow">Sources</div>
        <h2>References</h2>
        <ul style="font-size: 14px;">
          <li><a href="{{URL}}">{{TITLE}}</a></li>
          <!-- repeat for every URL cited -->
        </ul>
      </section>

    </div>

    <div class="hint">← / → to navigate · press <code>f</code> for fullscreen</div>
    <div class="nav">
      <button id="prev">←</button>
      <span class="counter"><span id="cur">1</span> / <span id="total">1</span></span>
      <button id="next">→</button>
    </div>

    <script>
      const slides = document.querySelectorAll('.slide');
      const cur = document.getElementById('cur');
      const total = document.getElementById('total');
      let i = 0;
      total.textContent = slides.length;
      function show(n) {
        i = Math.max(0, Math.min(slides.length - 1, n));
        slides.forEach((s, idx) => s.classList.toggle('active', idx === i));
        cur.textContent = i + 1;
        location.hash = '#' + (i + 1);
      }
      document.getElementById('prev').onclick = () => show(i - 1);
      document.getElementById('next').onclick = () => show(i + 1);
      document.addEventListener('keydown', (e) => {
        if (e.key === 'ArrowRight' || e.key === 'PageDown' || e.key === ' ') { show(i + 1); e.preventDefault(); }
        else if (e.key === 'ArrowLeft' || e.key === 'PageUp') { show(i - 1); e.preventDefault(); }
        else if (e.key === 'Home') { show(0); }
        else if (e.key === 'End') { show(slides.length - 1); }
        else if (e.key === 'f' || e.key === 'F') {
          if (!document.fullscreenElement) document.documentElement.requestFullscreen();
          else document.exitFullscreen();
        }
      });
      const hash = parseInt(location.hash.slice(1), 10);
      if (!isNaN(hash)) show(hash - 1);
    </script>
  </body>
</html>
```
