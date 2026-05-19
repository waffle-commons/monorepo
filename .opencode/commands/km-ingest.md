---
description: Ingest new raw source files (or a URL) and update the wiki
---

## URL input (optional)

If a URL was passed as an argument to this command:
1. Fetch the URL content using WebFetch (markdown format).
2. Derive a filename from the URL: take the last path segment, strip query strings and fragments, convert to lowercase kebab-case, and append `.md` (e.g. `https://example.com/my-great-article` → `my-great-article.md`). If the path segment is empty or uninformative (e.g. `/`, `index.html`), derive the name from the hostname instead.
3. Write the fetched content to `.project-memory/raw-sources/<derived-filename>`.
4. Proceed with the file-processing steps below, treating this newly written file as the source file to ingest.

If no URL was passed, skip this section and go directly to the file-processing steps.

## File processing

Read every file directly inside .project-memory/raw-sources/ (ignore the archives/ subdirectory) that does not yet have a corresponding summary in .project-memory/wiki/summaries/. Collect all new files into a list, then execute the following phases **in order**. Within each phase, process all items in **parallel** (launch multiple agents or tool calls simultaneously).

### Phase 1 — Read all sources (parallel)

For every new file, read it and extract the key ideas. Hold the extracted content in memory for Phase 2.

### Phase 2 — Write all summaries (parallel)

For every new file, simultaneously:
1. Determine the archived filename: prefix the original filename with the current UTC timestamp in the format `YYYYMMDDTHHMMSSZ` followed by an underscore (e.g. `20260508T143000Z_my-article.txt`). Use a single timestamp for all files in this run.
2. Write a summary page to `.project-memory/wiki/summaries/` named after the original source file (using .md extension). In the summary, set the source reference to `.project-memory/raw-sources/archives/<YYYYMMDD>/<timestamped-filename>` where `<YYYYMMDD>` is the date portion of the timestamp (e.g. `20260508`). If the content was fetched from a URL, also include the original URL as **Original URL**.
3. Move the source file into `.project-memory/raw-sources/archives/<YYYYMMDD>/` using the timestamped filename, where `<YYYYMMDD>` is the date portion of the timestamp (e.g. `.project-memory/raw-sources/archives/20260508/`). Create both the archives directory and the date subdirectory if they do not exist.

Do not proceed to Phase 3 until all summaries are written and all source files are archived.

### Phase 3 — Update .project-memory/wiki/index.md

Add a link row for each new summary to `.project-memory/wiki/index.md` (Summaries table). Do all additions in a single edit pass.

### Phase 4 — Update concept pages (parallel)

Now that all summaries exist, evaluate concept updates in parallel:

For each new summary:
- Check every existing concept page in `.project-memory/wiki/concepts/` and update any that are relevant.
- If the new data introduces a concept that has no dedicated page yet, create one in `.project-memory/wiki/concepts/`.

After all concept pages are updated, add any new concept pages to the Concepts table in `.project-memory/wiki/index.md` in a single edit pass.

### Phase 5 — Backfill summary "Related Concepts" sections (parallel)

Now that all concept pages are final (updated and newly created), revisit every new summary in parallel and update its **Related Concepts** section to reflect the complete set of relevant concepts — including any concepts that were created in Phase 4 after the summary was first written. Each summary should link to every concept page that is meaningfully related to its content.

Do not proceed to Phase 6 until all summaries are updated.

### Phase 6 — Rebuild knowledge graph

Run: `npx tsx scripts/build-graph.ts`

This incrementally updates `.project-memory/graph-wiki.json` — only changed wiki nodes are reprocessed. Code nodes remain in `graphify-out/graph.json` (managed separately by `/km-ingest-code`).

---

At the end, list every file you touched.
