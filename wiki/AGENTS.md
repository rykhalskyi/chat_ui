# Wiki — chat_ui_3

Project knowledge base in `wiki/`. Read `wiki/index.md` first to find pages.
Full conventions: `wiki/SCHEMA.md` (read on demand only).

- Work item → one page in `pages/tickets/<slug>.md` with `## Spec`, `## Plan`,
  `## Outcome`.
- History lives in git; never add `## Updates` sections or dates to entries.
- Decisions: one line in `decisions.md` via `node scripts/wiki.mjs decision "..."`.
- Never hand-edit `index.md`; regenerate with `node scripts/wiki.mjs index`.
- Append activity with `node scripts/wiki.mjs log <action> "<description>"`.
- Links are relative markdown links, never wikilinks.
- Frontmatter: `created`, `type`, `status`, `summary` only.
