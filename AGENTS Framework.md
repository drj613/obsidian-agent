---
created: 2026-02-20
category: Technologies
tags: [ai, agents, framework, obsidian, llm]
type: reference
---

# AGENTS Framework for Obsidian Vaults

A reusable framework for setting up LLM-agnostic agent configuration in any Obsidian vault. Drop this into your vault, work through the decision tree, and run the bootstrap script to generate your personalized `.agents/` system.

## What This Is

**AGENTS.md** is an open standard for guiding AI coding agents. It's supported by 60k+ projects and tools including Claude Code, OpenAI Codex, Cursor, Gemini CLI, Zed Agent, GitHub Copilot, Aider, and more. See [agents.md](https://agents.md) for the official spec.

This framework extends the standard with a **`.agents/` directory** that adds:
- **Rules** — hard constraints every agent must follow
- **Personas** — distinct agent roles with specific expertise
- **Commands** — reusable step-by-step workflows
- **Context** — domain knowledge loaded on demand
- **Hooks** — pre/post action checklists for quality control

The root `AGENTS.md` stays lean (~60 lines) so any tool can read it. The `.agents/` directory is progressive enhancement — agents that support file references get deeper context, while simpler tools still work off the root file alone.

---

## Requirements Decision Tree

Work through each section. Write down your answers — they become the inputs for the bootstrap script or manual file creation.

### 1. Vault Identity

> **What is this vault primarily for?**

```
├─ Personal knowledge management (PKM)
│   → Start with: Writer, Librarian personas
│   → Key commands: create-note, organize, review-vault
│
├─ Learning / study
│   → Start with: Writer, Researcher, Domain Specialist personas
│   → Key commands: create-note, research-to-note, review-vault
│   → You'll need: context files per subject area
│   └─ How many subjects?
│       ├─ 1-2 → one Domain Specialist persona with sections
│       └─ 3+ → one Domain Specialist persona with many domain context files
│
├─ Professional / work
│   → Start with: Writer, Executive Assistant, Researcher personas
│   → Key commands: create-note, daily-standup, research-to-note
│   → Consider: Meeting template, project tracking
│   └─ Do you manage projects in this vault?
│       ├─ Yes → add project status tracking (status: active|draft|archived)
│       └─ No → skip status field
│
├─ Creative (writing, music, art, etc.)
│   → Start with: Writer, Boundary Pusher personas
│   → Key commands: create-note, research-to-note
│   → Consider: Looser rules, more creative freedom in formatting
│
└─ Hybrid (multiple purposes)
    → Combine personas from the relevant categories above
    → More folder structure needed to separate concerns
```

**Write down:** Your vault type and selected personas.

---

### 2. Vault Structure

> **Do you have defined folders with clear purposes?**

```
├─ Yes, I have an organized folder structure
│   → List each folder and its purpose:
│   │   Folder: __________ Purpose: __________
│   │   Folder: __________ Purpose: __________
│   │   Folder: __________ Purpose: __________
│   │   (add as many as needed)
│   │
│   └─ Do your folders have index/hub notes?
│       ├─ Yes → what naming convention? (e.g., "00 - Index.md", "INDEX.md", "MOC.md")
│       └─ No → do you want them?
│           ├─ Yes → the bootstrap will create empty indexes
│           └─ No → skip index convention
│
├─ No, but I want to define one now
│   → Common starter structures:
│   │   • By topic: Projects/, Reference/, Journal/, Archive/
│   │   • By area: Work/, Personal/, Learning/, Creative/
│   │   • By PARA: Projects/, Areas/, Resources/, Archive/
│   │   • By Zettelkasten: Fleeting/, Literature/, Permanent/
│   │
│   └─ Pick one or design your own, then fill in the folder list above
│
└─ No, I use a flat vault
    → Skip structure rules entirely
    → The bootstrap will create minimal structure guidance
```

**Write down:** Your folder list with purposes, and index convention (if any).

---

### 3. Conventions

#### Linking

> **How do you link between notes?**

```
├─ Wiki links only: [[Note Name]]
│   → Strict formatting rule: wiki links for internal, markdown for external URLs
│   └─ Do you use display text? [[path|Display Text]]
│       ├─ Yes → include in formatting rules
│       └─ No / not sure → include as optional guidance
│
├─ Markdown links only: [text](path)
│   → Formatting rule enforces markdown style
│
└─ Mixed / no preference
    → Minimal formatting rule, no link enforcement
```

#### Frontmatter

> **Do you use YAML frontmatter in your notes?**

```
├─ Yes, I have a schema
│   → List your required fields:
│   │   Field: __________ Type: __________ Example: __________
│   │   Field: __________ Type: __________ Example: __________
│   │   (common: created, category, tags, status, type, author)
│   │
│   └─ List optional fields (if any):
│       Field: __________ When used: __________
│
├─ I want to start using frontmatter
│   → Recommended starter schema:
│   │   created: YYYY-MM-DD (when the note was made)
│   │   category: string (matches the folder name)
│   │   tags: [array] (relevant keywords)
│   │
│   └─ Add any of these optional fields?
│       ├─ status: active|draft|archived (for project notes)
│       ├─ type: daily|meeting|project|reference (for template-based notes)
│       ├─ author: string (for multi-author vaults)
│       └─ source: URL (for research notes)
│
└─ No frontmatter
    → Skip frontmatter rules entirely
```

#### Templates

> **Do you use note templates?**

```
├─ Yes
│   → List each template:
│   │   Name: __________ When used: __________ Key sections: __________
│   │   Name: __________ When used: __________ Key sections: __________
│   │
│   └─ Where do templates live? (e.g., _templates/, Templates/)
│
└─ No
    → Skip template context file
```

**Write down:** Your link style, frontmatter fields, and templates.

---

### 4. Safety Boundaries

> **Are there folders or files that should NEVER be modified by an agent?**

```
├─ .obsidian/ (always include this — Obsidian settings are off-limits)
│
├─ Additional protected paths?
│   ├─ Yes → list them: __________
│   └─ No → just .obsidian/
│
└─ Is any content private / gitignored?
    ├─ Yes → which folders? __________ (add to safety rules: never reference in public notes)
    └─ No → skip privacy rules
```

> **What destructive actions need confirmation?**

```
├─ Deleting notes → always confirm (recommended)
├─ Bulk operations → always preview first (recommended)
├─ Git push → always confirm (recommended)
└─ Other: __________
```

**Write down:** Your protected paths, private folders, and confirmation requirements.

---

### 5. Personas

> **What roles do you need?** Check all that apply, then customize.

```
□ Writer / Editor
  └─ What tone should they match? (casual, formal, academic, etc.): __________

□ Researcher
  └─ Any preferred source types? (academic, practical, news, etc.): __________

□ Librarian / Organizer
  └─ What's your biggest vault maintenance pain point? __________

□ Domain Specialist
  └─ List your domains:
      Domain: __________ Expertise level needed: __________
      Domain: __________ Expertise level needed: __________

□ Executive Assistant
  └─ Do you track tasks in daily notes? [Y/N]
  └─ Do you have recurring meetings? [Y/N]

□ Accuracy Auditor
  └─ What content most needs fact-checking? __________

□ Boundary Pusher
  └─ What areas do you want to explore more deeply? __________

□ Life Coach
  └─ What goals are you tracking? __________

□ Custom: __________
  └─ Role description: __________
  └─ Key capabilities: __________
```

**Write down:** Your selected personas with customization notes.

---

### 6. Commands

> **What workflows do you repeat?** Check all that apply.

```
□ create-note — Full note creation with frontmatter, template, index update, related links
  └─ Always needed if you have structure rules

□ review-vault — Health audit checking links, frontmatter, indexes, orphans
  └─ Recommended if you have a Librarian persona

□ organize — Batch cleanup: reindex, cross-link, tag cleanup, frontmatter repair
  └─ Recommended for vaults with 50+ notes

□ research-to-note — Web research → synthesized vault note with sources
  └─ Recommended if you have a Researcher persona

□ daily-standup — Daily note creation + task carry-forward + project status
  └─ Recommended if you have an Executive Assistant persona

□ Custom: __________
  └─ Steps: __________
```

**Write down:** Your selected commands.

---

### 7. Hooks

> **What goes wrong when you're careless?** Check all that apply.

```
□ Inconsistent frontmatter (missing fields, wrong format)
  → Generates: pre-create hook, post-create hook

□ Broken or missing links
  → Generates: post-create hook, vault-health hook

□ Notes not added to indexes
  → Generates: post-create hook

□ Content goes stale without review
  → Generates: audit-lifecycle hook + state/audit-log.md

□ Formatting inconsistencies (wrong link style, etc.)
  → Generates: pre-create hook

□ Nothing specific / I just want basics
  → Generates: minimal pre-create + post-create hooks
```

**Write down:** Your selected hooks.

---

## Architecture Reference

### Directory Structure

```
your-vault/
├── AGENTS.md                    # Root entry point (lean, ~60 lines)
└── .agents/
    ├── rules/                   # Hard rules — always in effect
    │   ├── formatting.md        # Link style, naming, attachments
    │   ├── frontmatter.md       # YAML schema and validation
    │   ├── safety.md            # Protected paths, privacy, destructive ops
    │   └── structure.md         # Folder purposes, indexes, note placement
    ├── commands/                # Reusable workflows
    │   ├── create-note.md       # Note creation pipeline
    │   └── ...                  # One file per command
    ├── personas/                # Agent roles
    │   ├── writer.md            # Each persona defines role, capabilities, constraints
    │   └── ...                  # One file per persona
    ├── context/                 # Domain knowledge (loaded on demand)
    │   ├── vault-structure.md   # Canonical folder reference
    │   ├── templates.md         # Template schemas
    │   └── domain-*.md          # Per-domain knowledge
    ├── hooks/                   # Pre/post action checklists
    │   ├── pre-create.md        # Before creating a note
    │   ├── post-create.md       # After creating a note
    │   └── ...                  # One file per hook
    └── state/                   # Mutable state (optional)
        └── audit-log.md         # Updated by the agent, not by you
```

### How the Layers Connect

```
User request
  → AGENTS.md (root — critical rules, persona directory)
    → Persona activated (e.g., writer.md)
      → Persona loads relevant rules (formatting.md, safety.md)
      → Persona loads relevant context (domain-music.md)
      → Command invoked (create-note.md)
        → Command references hooks (pre-create.md → do work → post-create.md)
```

### Design Principles

1. **Progressive disclosure** — The root file is self-sufficient for simple tasks. Deeper files loaded only when needed.
2. **Persona → Rules → Context layering** — Each persona references specific rules and loads context on demand.
3. **Markdown-only** — No YAML schemas, no JSON configs. Every LLM reads plain Markdown.
4. **The root file is king** — Tools that only read `AGENTS.md` still get enough to work correctly.

### Context Budget

Keep files lean to avoid wasting the LLM's attention:
- Root AGENTS.md: ~60 lines
- Each rule file: 25-40 lines
- Each persona: 35-50 lines
- Each command: 30-50 lines
- Each context file: 40-75 lines
- Each hook: 15-30 lines

Worst case (persona + domain context + command + hooks): ~250-300 lines total. Well within any model's effective range.

---

## File Templates

### Rule File Template

```markdown
# [Rule Name] Rules

[Brief description of what this rule covers.]

## [Section 1]

- Rule 1
- Rule 2

## [Section 2]

| Item | Value | Description |
|------|-------|-------------|
| ... | ... | ... |
```

### Command File Template

```markdown
# Command: [Name]

[One-line description.]

**Best used with:** [Persona name] persona

## Inputs

- **[input1]** — description
- **[input2]** — (optional) description

## Steps

1. **[Step name]** — description. Reference: `.agents/rules/[relevant-rule].md`
2. **[Step name]** — description. Reference: `.agents/hooks/[relevant-hook].md`
3. ...

## Output

[What the command produces.]
```

### Persona File Template

```markdown
# Persona: [Name]

> Rules: `.agents/rules/formatting.md`, `.agents/rules/safety.md`

## Role

You are [role description for this vault].

## Capabilities

- Capability 1
- Capability 2
- Capability 3

## Constraints

- Constraint 1
- Constraint 2

## Personality

- Trait 1
- Trait 2

## Workflows

- When [doing X], follow `.agents/commands/[command].md`
- When [doing Y], check `.agents/hooks/[hook].md` first
```

### Context File Template

```markdown
# [Domain] Context

## User Profile

- Relevant background about the user in this domain

## Existing Vault Content

- `path/to/note.md` — brief description
- `path/to/note.md` — brief description

## When Assisting

- Domain-specific guidance for the agent
- What to reference, what to avoid
```

### Hook File Template

```markdown
# [Pre/Post]-[Action] Checklist

[When to run this checklist.]

## [Category]
- [ ] Check item 1
- [ ] Check item 2

## [Category]
- [ ] Check item 3
- [ ] Check item 4
```

### Root AGENTS.md Template

```markdown
# [Vault Name] — Agent Instructions

You are an assistant for this Obsidian vault. [Brief personality/approach guidance.]

## Critical Rules

- [Rule 1 — the most important constraint]
- [Rule 2 — linking convention]
- [Rule 3 — frontmatter requirement]
- [Rule 4 — what's off-limits]

## Vault Structure

| Folder | Purpose |
|--------|---------|
| `Folder1/` | Description |
| `Folder2/` | Description |

[Index convention note if applicable.]

## Personas

Activate by asking: "act as the [persona]"

| Persona | Focus |
|---------|-------|
| **Name** | One-line description |

## Extended Configuration

| Directory | Purpose |
|-----------|---------|
| `.agents/rules/` | [rules summary] |
| `.agents/commands/` | [commands summary] |
| `.agents/personas/` | [personas summary] |
| `.agents/context/` | [context summary] |
| `.agents/hooks/` | [hooks summary] |

## Quick Reference

[Frontmatter template or other frequently-needed snippet.]
```

---

## Optional Modules

These extend the core system. Add them only if you need them.

### Morning Check-In

**What it adds:** `bin/morning-checkin` script + `bin/setup-schedule` for launchd (macOS) / cron (Linux)

**When you need it:** You want a daily automated standup that creates your daily note, carries forward tasks, and flags stale projects — all via your LLM CLI.

**How to add:**
1. Create `.agents/bin/morning-checkin` — a bash script that detects your LLM CLI (`claude`, `codex`, `gemini`) and sends the Executive Assistant persona a daily-standup prompt
2. Create `.agents/bin/setup-schedule` — installs a daily launchd plist or cron entry
3. `chmod +x .agents/bin/*`
4. Run `setup-schedule --time 07:00` to install

**Requires:** Executive Assistant persona + daily-standup command.

### Audit Lifecycle

**What it adds:** `hooks/audit-lifecycle.md` + `state/audit-log.md`

**When you need it:** You want staleness tracking — automatically flagging notes that haven't been touched in a while based on their type (active projects decay fast, reference notes decay slowly).

**How to add:**
1. Create `.agents/hooks/audit-lifecycle.md` — defines staleness thresholds per note type and scoring rules
2. Create `.agents/state/audit-log.md` — empty scaffold for tracking audit history
3. Reference from Librarian persona and review-vault command

**Staleness thresholds (customize these):**

| Note Type | Threshold |
|-----------|-----------|
| Daily/meeting notes | Never stale (they're snapshots) |
| Active projects | 14 days |
| Draft projects | 30 days |
| Reference notes | 90 days |
| General notes | 60 days |

### Git Hooks (Pre-Commit Validation)

**What it adds:** `.git/hooks/pre-commit` or a script in `.agents/bin/`

**When you need it:** You want automated validation on every git commit — checking frontmatter, broken links, or formatting before code enters the repo.

**How to add:**
1. Create `.agents/bin/validate-vault` — a bash script that checks frontmatter YAML validity, scans for broken wiki links, and verifies index completeness
2. Symlink or copy to `.git/hooks/pre-commit`
3. The script exits non-zero on failures, blocking the commit

**Example checks:**
- All `.md` files have valid YAML frontmatter
- No broken `[[wiki links]]` (target file exists)
- Every note in a section folder appears in its index

### MCP Integration

**What it adds:** `.mcp.json` configuration file

**When you need it:** You use tools that support the Model Context Protocol (Claude Desktop, JetBrains, VS Code) and want to expose vault-specific tools to the LLM.

**How to add:**
1. Create `.mcp.json` at vault root with server definitions
2. Configure servers for vault-specific operations (e.g., a local search server, a template applier)

### Multi-Vault Sync

**What it adds:** Cross-vault reference patterns in context files

**When you need it:** You maintain multiple Obsidian vaults (e.g., personal + work) and want agents to understand the relationships without leaking private content.

**How to add:**
1. Add a `context/related-vaults.md` file listing other vaults and their purposes
2. Define which information can flow between vaults (e.g., "reference Technologies/ notes from work vault, but never expose Work/ content")
3. Each vault gets its own independent `.agents/` system

---

## Bootstrap Script

A companion script automates the initial setup. See [[agents-bootstrap.sh]] in this folder.

**Usage:**

```bash
# Interactive mode (prompts for each decision)
bash agents-bootstrap.sh

# Run from your vault's root directory
cd /path/to/your/vault
bash /path/to/agents-bootstrap.sh
```

The script:
1. Asks you the key questions from the decision tree above
2. Creates the `.agents/` directory structure
3. Generates starter files based on your answers
4. Creates the root `AGENTS.md`
5. Reports everything it created

It is **non-destructive** — it will never overwrite existing files. Safe to run multiple times.

---

**Related:**
- [[Agentic RAG]] — how agents retrieve and generate context
- [[agents-bootstrap.sh]] — the companion bootstrap script
