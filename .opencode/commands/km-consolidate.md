---
description: Consolidate and audit the wiki for contradictions, orphan pages, missing concepts, outdated claims, and broken concept links
---

## Standard Mode (Default)

Read every file in .project-memory/wiki/. Find: contradictions between pages, orphan pages with no inbound links, concepts mentioned repeatedly but with no dedicated page, claims that seem outdated based on newer files, and broken concept links between documents. Write a health report to .project-memory/wiki/lint-report.md with specific fixes.

At the end, list every file you touched.

---

## Incremental Mode: `incremental`

If the argument `incremental` was passed:

### Phase 1 — Identify Today's Archives

1. Scan `.project-memory/raw-sources/archives/` for files with today's timestamp (format: `YYYYMMDDTHHMMSSZ_*`).
2. For each archived file found, locate its corresponding summary in `.project-memory/wiki/summaries/` (filename matches the original source name with `.md` extension).
3. Collect all today's summaries into a list.

### Phase 2 — Verify Summary → Concept Links

For each today's summary (parallel):
1. **Extract concept references:** Scan the summary's "Related Concepts" section and extract all referenced concept pages.
2. **Verify concept pages exist:** For each concept link, verify the target concept page exists in `.project-memory/wiki/concepts/`.
3. **Verify reverse links:** For each concept referenced, check if that concept page links back to this summary in its "Related Summaries" section.
4. **Report missing links:** If a concept page does NOT link back to this summary, flag it as a missing reverse link.
5. **Report broken links:** If a concept page referenced in the summary does NOT exist, flag it as a broken link.

### Phase 3 — Verify Concept-to-Concept Links

Scan all concept pages in `.project-memory/wiki/concepts/` for cross-references (e.g., `[[other-concept]]` syntax or markdown links to other concepts). For each cross-reference found (parallel):
1. Verify the target concept page exists.
2. Verify bidirectional linking: if concept A links to concept B, check if concept B links back to concept A.
3. Report missing backlinks.

### Phase 4 — Generate Incremental Report

Write a report to `.project-memory/wiki/lint-report-incremental.md` with:
- **Today's summaries processed:** Count and file list
- **Summary → Concept links status:** 
  - ✓ Valid (concept exists + reverse link exists)
  - ⚠️ Needs backlink (concept exists but summary not mentioned in concept)
  - ✗ Broken (concept does not exist)
- **Concept → Concept links status:**
  - ✓ Bidirectional (A→B and B→A)
  - ⚠️ Unidirectional (A→B but not B→A)
  - ✗ Broken (target concept missing)
- **Suggested fixes:** For each issue, provide exact file location and suggested link addition.

---

At the end, list every file you touched.
