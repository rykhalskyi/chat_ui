# Wiki Schema

Full conventions for this project wiki. The always-loaded summary is `AGENTS.md`;
this file is the detail reference.

## Goals

- Token-lean: git is the change history; the wiki stores current knowledge and
  decisions only.
- One page per work item; expensive ceremony replaced by `scripts/wiki.mjs`.

## Token discipline

1. **Git is the history.** No `## Updates` sections, no "Created <date>" in index
   entries, no restating superseded content. Use `git log -p wiki/pages/<file>`.
2. **One page per work item by default** with `## Spec`, `## Plan`, `## Outcome`.
   Separate `specs/` + `plans/` only for large/ambiguous epics shared by tickets.
3. **Decisions get a one-liner** in `decisions.md`; reference the id (`D-07`) from the
   ticket instead of restating rationale.
4. **Minimal frontmatter:** `created`, `type`, `status`, `summary`. No `tags`, no
   `related`.
5. **Never hand-edit `index.md`.** Regenerate with `node scripts/wiki.mjs index`.
   Append `log.md` / `decisions.md` via the script.
6. **`AGENTS.md` stays short.** Detail goes here.
7. **Batch writes** at the end of a work session.

## Layout

```
wiki/
├── AGENTS.md      # short, always-loaded summary
├── SCHEMA.md      # this file
├── index.md       # generated catalog — never edit by hand
├── log.md         # append-only activity log
├── decisions.md   # append-only decision record (ADR-lite)
└── pages/
    ├── project-overview.md
    ├── build-deploy.md
    ├── debugging.md          # optional
    ├── epics/                # optional
    ├── tickets/              # default artifact per work item
    ├── specs/                # large/ambiguous epics only
    ├── plans/                # large/ambiguous epics only
    └── research/             # investigations
```

## Frontmatter

```yaml
---
created: YYYY-MM-DD
type: overview | build-deploy | epic | ticket | spec | plan | research
status: proposed | in-progress | implemented | superseded   # when meaningful
summary: One-line description used to build index.md
---
```

- `created` never changes after creation.
- `summary` is required so the index can be built without reading page bodies.
- Do not add `tags` or `related`.

## Links (clickable in VS Code)

Relative markdown links only — never wikilinks. Paths relative to the linking file:

| From | To | Link |
|---|---|---|
| `wiki/index.md` | any page | `pages/<folder>/<slug>.md` |
| `pages/<sub>/x.md` | `pages/<other>/y.md` | `../<other>/y.md` |
| `pages/<sub>/x.md` | `pages/root-page.md` | `../root-page.md` |
| `pages/root-page.md` | `pages/<folder>/y.md` | `<folder>/y.md` |

## Slugs

- Tickets: `<ticket-id>-<brief>` (e.g. `ticket-15-localization-infra`,
  `issue-11-dual-price`). Brief = 2-4 lowercase hyphenated words.
- Specs and plans share one `<feature-slug>`.
- Research: natural lowercase hyphenated topic.

## Page templates

### Ticket

```markdown
# T<n> — <Title>

Part of the [epic](../epics/<slug>.md).   # if applicable

## Spec
What and why: requirements, scope, design decisions, constraints.

## Plan
Ordered steps, files to create/modify, migrations, tests, risks.

## Outcome
What shipped, deviations, files changed.
```

### Spec (large epics only)

Requirements, scope, decisions, constraints. Link to the matching plan and tickets.

### Plan (large epics only)

Ordered steps, files, migrations, tests, risks. Link to the spec and tickets.

### Research

Context, findings, conclusions, recommended actions.

## Operations

- **Init:** create structure; populate overview and build-deploy; copy
  `scripts/wiki.mjs`; create `log.md`; run `index`.
- **Ticket:** write the ticket page, run `index`, then
  `log ticket "<title>"`.
- **Spec/Plan:** write pages, cross-link, run `index`, `log spec|plan "<name>"`.
- **Research:** write page, run `index`, `log research "<topic>"`.
- **Decision:** `node scripts/wiki.mjs decision "<decision> — because <reason>"` →
  appends `- [YYYY-MM-DD] D-nn — ...` to `decisions.md`.
- **Index:** `node scripts/wiki.mjs index`.
- **Log:** `node scripts/wiki.mjs log <action> "<description>"` (actions: init,
  ticket, spec, plan, research, update, decision).
- **Lint:** `node scripts/wiki.mjs lint` — checks missing frontmatter, dangling
  relative links, pages absent from the index.
- **Update:** edit the page directly; regenerate the index if the summary changed;
  `log update "<page> — <note>"`.

## Migration from `.design-specs`

If `.design-specs/` or `.opencode/plans/` appear later, migrate them into
`pages/specs/` and `pages/plans/` (preserving mtime as `created`), run `index`, log
each migration, and do not delete originals unless asked.
