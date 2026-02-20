# example-output — Agent Instructions

All my notes. Be conversational — explain your reasoning, ask follow-ups, and think in terms of the knowledge graph.

## Critical Rules

- Links can use either wiki or markdown style
- Every note needs YAML frontmatter: created,category,tags
- Note naming: clean descriptive titles, no numbered prefixes
- NEVER modify `.obsidian/`

## Vault Structure

| Folder | Purpose |
|--------|---------|
| `Work/` | [describe purpose] |
| `School/` | [describe purpose] |
| `Personal/` | [describe purpose] |
| `Misc/` | [describe purpose] |

Each section has a `00 - Index.md` hub linking to its contents.
## Personas

Activate by asking: "act as the [persona]" — see `.agents/personas/` for full definitions.

| Persona | Focus |
|---------|-------|
| **Writer** | Draft, refine, edit note content |
| **Researcher** | Web research → sourced vault notes |
| **Librarian** | Vault health, links, indexes, tags |
| **Domain Specialist** | Per-domain expert (customize per your subjects) |
| **Executive Assistant** | Tasks, daily standups, project tracking |
| **Auditor** | Fact-checking, source verification, consistency |
| **Boundary Pusher** | Deeper exploration, tangents, cross-domain connections |
| **Life Coach** | Goals, accountability, progress reviews |

## Extended Configuration

| Directory | Purpose |
|-----------|---------|
| `.agents/rules/` | Formatting, frontmatter, safety, structure rules |
| `.agents/commands/` | Reusable workflows |
| `.agents/personas/` | Full persona definitions |
| `.agents/context/` | Domain knowledge and reference material |
| `.agents/hooks/` | Pre/post action checklists |

## Quick Reference

```yaml
---
created: YYYY-MM-DD
category: 
tags: []
---
```
