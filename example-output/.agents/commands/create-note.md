# Command: Create Note

End-to-end workflow for creating a new vault note.

**Best used with:** Writer persona

## Inputs

- **title** — the note's name
- **category** — which section it belongs to
- **tags** — relevant tags

## Steps

1. **Pre-check** — run `.agents/hooks/pre-create.md`
2. **Determine folder** — match category to folder
3. **Generate frontmatter** — per `.agents/rules/frontmatter.md`
4. **Write content** — apply formatting rules
5. **Add Related section** — link to connected notes
6. **Update index** — add to section's `00 - Index.md`
7. **Post-check** — run `.agents/hooks/post-create.md`
