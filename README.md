# obsidian-agent

A reusable, LLM-agnostic agent configuration framework for Obsidian vaults. Drop it into any vault, run the interactive bootstrap script, and get a complete `.agents/` system that works with Claude Code, Cursor, GitHub Copilot, Gemini CLI, Zed Agent, Aider, and any other tool that supports the [AGENTS.md](https://agents.md) standard.

## Why

LLM tools are increasingly useful for managing knowledge bases, but each vault has different structure, conventions, and needs. This framework bridges the gap: you answer a few questions about your vault, and it generates a modular agent configuration tailored to how you work.

The root `AGENTS.md` stays lean (~60 lines) so any tool can read it. The `.agents/` directory is progressive enhancement — agents that support file references get deeper context, while simpler tools still work off the root file alone.

## Quick Start

```bash
# From your vault's root directory
bash /path/to/agents-bootstrap.sh

# Or specify the vault path
bash agents-bootstrap.sh /path/to/your/vault
```

The script walks you through 7 decision categories:

1. **Vault Identity** — name, description, type (PKM, learning, professional, creative)
2. **Vault Structure** — folder layout, index conventions
3. **Conventions** — link style (wiki vs markdown), frontmatter schema, templates
4. **Safety Boundaries** — protected paths, private folders, confirmation requirements
5. **Personas** — which agent roles to enable
6. **Commands** — which workflows to generate
7. **Hooks** — pre/post action checklists

Then it generates your complete `.agents/` system. Non-destructive (never overwrites existing files), idempotent (safe to run multiple times).

## What Gets Generated

```
your-vault/
├── AGENTS.md                  # Root entry point (~60 lines)
└── .agents/
    ├── rules/
    │   ├── formatting.md      # Link style, naming, markdown standards
    │   ├── frontmatter.md     # YAML schema, required/optional fields
    │   ├── safety.md          # Protected paths, destructive op confirmation
    │   └── structure.md       # Folder purposes, index conventions
    ├── personas/              # Agent roles (pick what fits)
    │   ├── writer.md
    │   ├── researcher.md
    │   ├── librarian.md
    │   ├── domain-specialist.md
    │   ├── executive-assistant.md
    │   ├── auditor.md
    │   ├── boundary-pusher.md
    │   └── life-coach.md
    ├── commands/              # Step-by-step workflows
    │   ├── create-note.md
    │   ├── review-vault.md
    │   ├── organize.md
    │   ├── research-to-note.md
    │   └── daily-standup.md
    ├── context/               # Domain knowledge, vault structure ref
    └── hooks/                 # Pre/post action checklists
```

## Built-in Personas

| Persona | Role |
|---|---|
| **Writer/Editor** | Draft, refine, and edit content |
| **Researcher** | Web research synthesized into sourced notes |
| **Librarian/Organizer** | Vault health, links, indexes, organization |
| **Domain Specialist** | Per-domain expertise (customizable) |
| **Executive Assistant** | Task tracking, standups, project management |
| **Accuracy Auditor** | Fact-checking, source verification, consistency |
| **Boundary Pusher** | Cross-domain connections, deeper exploration |
| **Life Coach** | Goals, accountability, progress reviews |

## Built-in Commands

| Command | What It Does |
|---|---|
| `create-note` | End-to-end note creation with frontmatter and index updates |
| `review-vault` | Comprehensive vault health audit |
| `organize` | Batch cleanup: reindex, cross-link, tag cleanup, frontmatter repair |
| `research-to-note` | Web research pipeline with source verification |
| `daily-standup` | Morning check-in with task carry-forward and project status |

## Design Principles

- **Markdown-only** — no YAML schemas or JSON configs; every LLM reads plain Markdown
- **Progressive disclosure** — root file is self-sufficient; deeper files load on demand
- **Lean context budget** — minimal file sizes to avoid wasting LLM attention (~250-300 lines worst case)
- **Root file is king** — tools reading only `AGENTS.md` still function correctly

## Optional Extensions

The framework documentation (`AGENTS Framework.md`) covers additional modules:

- **Morning Check-In** — automated daily standup via launchd/cron
- **Audit Lifecycle** — staleness tracking with configurable thresholds
- **Git Hooks** — pre-commit validation for frontmatter and links
- **MCP Integration** — Model Context Protocol for vault-specific tools
- **Multi-Vault Sync** — cross-vault references without leaking private content

## Requirements

- Bash shell
- `cat`, `mkdir` (standard Unix utilities)
- That's it. No external dependencies.

## License

MIT
