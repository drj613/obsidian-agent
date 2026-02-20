#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# AGENTS Bootstrap — Generate an LLM-agnostic .agents/ system for Obsidian
# ============================================================================
# Usage: bash agents-bootstrap.sh
# Run from your vault's root directory, or it will use the current directory.
#
# Non-destructive: never overwrites existing files.
# Idempotent: safe to run multiple times.
# Dependencies: bash, cat, mkdir (no external tools needed)
# ============================================================================

VAULT_DIR="${1:-.}"
VAULT_DIR="$(cd "$VAULT_DIR" && pwd)"
AGENTS_DIR="$VAULT_DIR/.agents"

# Colors (disabled if not a terminal)
if [[ -t 1 ]]; then
  BOLD='\033[1m' DIM='\033[2m' GREEN='\033[32m' YELLOW='\033[33m' CYAN='\033[36m' RESET='\033[0m'
else
  BOLD='' DIM='' GREEN='' YELLOW='' CYAN='' RESET=''
fi

created_files=()
skipped_files=()

# Write a file only if it doesn't exist
safe_write() {
  local path="$1"
  local content="$2"
  local dir
  dir="$(dirname "$path")"
  mkdir -p "$dir"
  if [[ -f "$path" ]]; then
    skipped_files+=("$path")
  else
    echo "$content" > "$path"
    created_files+=("$path")
  fi
}

# Prompt with default
ask() {
  local prompt="$1" default="$2" var_name="$3"
  echo -en "${CYAN}${prompt}${RESET}"
  if [[ -n "$default" ]]; then
    echo -en " ${DIM}[${default}]${RESET}"
  fi
  echo -n ": "
  read -r input
  eval "$var_name=\"${input:-$default}\""
}

# Yes/no prompt
ask_yn() {
  local prompt="$1" default="$2" var_name="$3"
  local hint="[Y/n]"
  [[ "$default" == "n" ]] && hint="[y/N]"
  echo -en "${CYAN}${prompt}${RESET} ${DIM}${hint}${RESET}: "
  read -r input
  input="${input:-$default}"
  case "$input" in
    [yY]*) eval "$var_name=y" ;;
    *) eval "$var_name=n" ;;
  esac
}

# Multi-select from options
ask_multi() {
  local prompt="$1" options="$2" var_name="$3"
  echo -e "${CYAN}${prompt}${RESET}"
  echo -e "${DIM}Options: ${options}${RESET}"
  echo -en "Select (comma-separated, or 'all'): "
  read -r input
  if [[ "$input" == "all" ]]; then
    eval "$var_name=\"$options\""
  else
    eval "$var_name=\"$input\""
  fi
}

# ============================================================================
echo -e "${BOLD}AGENTS Bootstrap${RESET}"
echo -e "${DIM}Generating an LLM-agnostic .agents/ system for your Obsidian vault.${RESET}"
echo -e "${DIM}Vault directory: ${VAULT_DIR}${RESET}"
echo ""

# --- 1. Vault Identity ---
echo -e "${BOLD}1. VAULT IDENTITY${RESET}"
ask "Vault name" "my-vault" VAULT_NAME
ask "Brief vault description (one sentence)" "An Obsidian knowledge vault" VAULT_DESC
echo ""

# --- 2. Vault Structure ---
echo -e "${BOLD}2. VAULT STRUCTURE${RESET}"
ask "Content folders (comma-separated)" "Notes,Projects,Reference,Archive" FOLDERS_RAW
IFS=',' read -ra FOLDERS <<< "$FOLDERS_RAW"
# Trim whitespace
for i in "${!FOLDERS[@]}"; do FOLDERS[$i]="$(echo "${FOLDERS[$i]}" | xargs)"; done

ask_yn "Do your folders have index/hub notes?" "y" HAS_INDEXES
if [[ "$HAS_INDEXES" == "y" ]]; then
  ask "Index file name convention" "00 - Index.md" INDEX_NAME
else
  INDEX_NAME=""
fi
echo ""

# --- 3. Conventions ---
echo -e "${BOLD}3. CONVENTIONS${RESET}"
echo -e "${DIM}Link style:${RESET}"
echo "  1) Wiki links only [[Note Name]]"
echo "  2) Markdown links only [text](path)"
echo "  3) Mixed / no preference"
echo -n "Choose (1/2/3): "
read -r LINK_STYLE
LINK_STYLE="${LINK_STYLE:-1}"

ask_yn "Use YAML frontmatter?" "y" USE_FRONTMATTER
if [[ "$USE_FRONTMATTER" == "y" ]]; then
  ask "Required frontmatter fields (comma-separated)" "created,category,tags" FM_FIELDS_RAW
  ask "Optional frontmatter fields (comma-separated, or none)" "status,type" FM_OPT_RAW
fi

ask_yn "Use note templates?" "y" USE_TEMPLATES
if [[ "$USE_TEMPLATES" == "y" ]]; then
  ask "Template folder path" "_templates" TEMPLATE_DIR
  ask "Template names (comma-separated)" "Daily,Project,Reference" TEMPLATES_RAW
fi
echo ""

# --- 4. Safety ---
echo -e "${BOLD}4. SAFETY BOUNDARIES${RESET}"
ask "Protected paths (comma-separated, .obsidian/ is always included)" ".obsidian/" PROTECTED_RAW
ask "Private/gitignored folders (comma-separated, or none)" "none" PRIVATE_RAW
echo ""

# --- 5. Personas ---
echo -e "${BOLD}5. PERSONAS${RESET}"
ask_multi "Which personas do you want?" "writer,researcher,librarian,domain-specialist,executive-assistant,auditor,boundary-pusher,life-coach" PERSONAS_RAW
IFS=',' read -ra PERSONAS <<< "$PERSONAS_RAW"
for i in "${!PERSONAS[@]}"; do PERSONAS[$i]="$(echo "${PERSONAS[$i]}" | xargs)"; done

# Domain specialist domains
DOMAINS_RAW=""
for p in "${PERSONAS[@]}"; do
  if [[ "$p" == "domain-specialist" ]]; then
    ask "Domain specialist areas (comma-separated)" "General" DOMAINS_RAW
  fi
done
echo ""

# --- 6. Commands ---
echo -e "${BOLD}6. COMMANDS${RESET}"
ask_multi "Which commands do you want?" "create-note,review-vault,organize,research-to-note,daily-standup" COMMANDS_RAW
IFS=',' read -ra COMMANDS <<< "$COMMANDS_RAW"
for i in "${!COMMANDS[@]}"; do COMMANDS[$i]="$(echo "${COMMANDS[$i]}" | xargs)"; done
echo ""

# --- 7. Hooks ---
echo -e "${BOLD}7. HOOKS${RESET}"
ask_multi "Which hooks do you want?" "pre-create,pre-edit,post-create,vault-health" HOOKS_RAW
IFS=',' read -ra HOOKS <<< "$HOOKS_RAW"
for i in "${!HOOKS[@]}"; do HOOKS[$i]="$(echo "${HOOKS[$i]}" | xargs)"; done
echo ""

# ============================================================================
# GENERATE FILES
# ============================================================================
echo -e "${BOLD}Generating files...${RESET}"
echo ""

# --- Build folder table for AGENTS.md ---
FOLDER_TABLE=""
for folder in "${FOLDERS[@]}"; do
  FOLDER_TABLE+="| \`${folder}/\` | [describe purpose] |
"
done

# --- Build persona table ---
PERSONA_TABLE=""
for p in "${PERSONAS[@]}"; do
  case "$p" in
    writer) PERSONA_TABLE+="| **Writer** | Draft, refine, edit note content |
" ;;
    researcher) PERSONA_TABLE+="| **Researcher** | Web research → sourced vault notes |
" ;;
    librarian) PERSONA_TABLE+="| **Librarian** | Vault health, links, indexes, tags |
" ;;
    domain-specialist) PERSONA_TABLE+="| **Domain Specialist** | Per-domain expert (customize per your subjects) |
" ;;
    executive-assistant) PERSONA_TABLE+="| **Executive Assistant** | Tasks, daily standups, project tracking |
" ;;
    auditor) PERSONA_TABLE+="| **Auditor** | Fact-checking, source verification, consistency |
" ;;
    boundary-pusher) PERSONA_TABLE+="| **Boundary Pusher** | Deeper exploration, tangents, cross-domain connections |
" ;;
    life-coach) PERSONA_TABLE+="| **Life Coach** | Goals, accountability, progress reviews |
" ;;
    *) PERSONA_TABLE+="| **${p}** | [describe focus] |
" ;;
  esac
done

# --- Link convention text ---
case "$LINK_STYLE" in
  1) LINK_RULE="Use \`[[wiki links]]\` for internal references — NEVER markdown \`[]()\`" ;;
  2) LINK_RULE="Use markdown links \`[text](path)\` for all references" ;;
  *) LINK_RULE="Links can use either wiki or markdown style" ;;
esac

# --- Frontmatter quick ref ---
FM_QUICK=""
if [[ "$USE_FRONTMATTER" == "y" ]]; then
  FM_QUICK="## Quick Reference

\`\`\`yaml
---"
  IFS=',' read -ra FM_FIELDS <<< "$FM_FIELDS_RAW"
  for f in "${FM_FIELDS[@]}"; do
    f="$(echo "$f" | xargs)"
    case "$f" in
      created) FM_QUICK+="
created: YYYY-MM-DD" ;;
      tags) FM_QUICK+="
tags: []" ;;
      *) FM_QUICK+="
${f}: " ;;
    esac
  done
  FM_QUICK+="
---
\`\`\`"
fi

INDEX_SECTION_BRIEF=""
if [[ -n "$INDEX_NAME" ]]; then
  INDEX_SECTION_BRIEF="Each section has a \`${INDEX_NAME}\` hub linking to its contents."
fi

# === ROOT AGENTS.md ===
safe_write "$VAULT_DIR/AGENTS.md" "# ${VAULT_NAME} — Agent Instructions

${VAULT_DESC}. Be conversational — explain your reasoning, ask follow-ups, and think in terms of the knowledge graph.

## Critical Rules

- ${LINK_RULE}
- Every note needs YAML frontmatter: ${FM_FIELDS_RAW:-created, category, tags}
- Note naming: clean descriptive titles, no numbered prefixes
- NEVER modify \`.obsidian/\`

## Vault Structure

| Folder | Purpose |
|--------|---------|
${FOLDER_TABLE}
${INDEX_SECTION_BRIEF}
## Personas

Activate by asking: \"act as the [persona]\" — see \`.agents/personas/\` for full definitions.

| Persona | Focus |
|---------|-------|
${PERSONA_TABLE}
## Extended Configuration

| Directory | Purpose |
|-----------|---------|
| \`.agents/rules/\` | Formatting, frontmatter, safety, structure rules |
| \`.agents/commands/\` | Reusable workflows |
| \`.agents/personas/\` | Full persona definitions |
| \`.agents/context/\` | Domain knowledge and reference material |
| \`.agents/hooks/\` | Pre/post action checklists |

${FM_QUICK}"

# === RULES ===

# formatting.md
LINK_DETAIL=""
case "$LINK_STYLE" in
  1) LINK_DETAIL="- Use \`[[wiki links]]\` for ALL internal references — never markdown \`[]()\`
- Display text: \`[[path/to/file|Display Text]]\`
- Embed attachments: \`![[_attachments/Category/file.png]]\`
- External URLs are the only exception where markdown links are acceptable" ;;
  2) LINK_DETAIL="- Use markdown links \`[text](path)\` for all references
- Embed images with standard markdown: \`![alt](path/to/image.png)\`" ;;
  *) LINK_DETAIL="- Either wiki links \`[[Note]]\` or markdown links \`[text](path)\` are acceptable
- Be consistent within a single note" ;;
esac

safe_write "$AGENTS_DIR/rules/formatting.md" "# Formatting Rules

## Links

${LINK_DETAIL}

## Note Naming

- Clean, descriptive titles
- No numbered prefixes
- No special characters that break links

## Markdown Conventions

- Use \`#\` headings in descending order
- Use \`-\` for unordered lists
- Use \`- [ ]\` for task items
- All content files are \`.md\`"

# frontmatter.md
if [[ "$USE_FRONTMATTER" == "y" ]]; then
  FM_TABLE=""
  IFS=',' read -ra FM_FIELDS <<< "$FM_FIELDS_RAW"
  for f in "${FM_FIELDS[@]}"; do
    f="$(echo "$f" | xargs)"
    FM_TABLE+="| \`${f}\` | required | [describe] |
"
  done
  if [[ -n "$FM_OPT_RAW" && "$FM_OPT_RAW" != "none" ]]; then
    IFS=',' read -ra FM_OPT <<< "$FM_OPT_RAW"
    for f in "${FM_OPT[@]}"; do
      f="$(echo "$f" | xargs)"
      FM_TABLE+="| \`${f}\` | optional | [describe] |
"
    done
  fi

  safe_write "$AGENTS_DIR/rules/frontmatter.md" "# Frontmatter Rules

Every note (except indexes and templates) MUST have YAML frontmatter.

## Fields

| Field | Required? | Description |
|-------|-----------|-------------|
${FM_TABLE}
## Validation

- All required fields must be present
- \`tags\` must be an array (even if empty \`[]\`)
- \`created\` must be a valid date (YYYY-MM-DD)"
fi

# safety.md
PROTECTED_LIST="- \`.obsidian/\` — NEVER modify"
if [[ -n "$PROTECTED_RAW" && "$PROTECTED_RAW" != ".obsidian/" ]]; then
  IFS=',' read -ra PROTECTED <<< "$PROTECTED_RAW"
  for p in "${PROTECTED[@]}"; do
    p="$(echo "$p" | xargs)"
    [[ "$p" == ".obsidian/" ]] && continue
    PROTECTED_LIST+="
- \`${p}\` — protected"
  done
fi

PRIVATE_LIST=""
if [[ -n "$PRIVATE_RAW" && "$PRIVATE_RAW" != "none" ]]; then
  IFS=',' read -ra PRIVATE <<< "$PRIVATE_RAW"
  for p in "${PRIVATE[@]}"; do
    p="$(echo "$p" | xargs)"
    PRIVATE_LIST+="
- \`${p}/\` — private, never reference in public notes"
  done
fi

safe_write "$AGENTS_DIR/rules/safety.md" "# Safety Rules

## Protected Paths

${PROTECTED_LIST}

## Privacy
${PRIVATE_LIST:-
No private folders configured.}

## Destructive Operations

- Never delete notes without explicit user confirmation
- Never bulk-delete without showing a preview first
- Always confirm before git push"

# structure.md
STRUCT_TABLE=""
for folder in "${FOLDERS[@]}"; do
  STRUCT_TABLE+="| \`${folder}/\` | [purpose] | [category value] |
"
done

INDEX_SECTION=""
if [[ -n "$INDEX_NAME" ]]; then
  INDEX_SECTION="## Index Convention

Every content section has a \`${INDEX_NAME}\` hub linking to its contents.
When creating a note, always add it to its section's index.

"
fi

safe_write "$AGENTS_DIR/rules/structure.md" "# Vault Structure Rules

## Folders

| Folder | Purpose | Category |
|--------|---------|----------|
${STRUCT_TABLE}
${INDEX_SECTION}## Cross-Referencing

- Every note should include a \`**Related:**\` section with links to connected notes
- Think in terms of the knowledge graph — what connects to what"

# === CONTEXT ===
FOLDER_CONTEXT_TABLE=""
for f in "${FOLDERS[@]}"; do
  FOLDER_CONTEXT_TABLE+="| \`${f}/\` | [describe] | |
"
done

TEMPLATE_ROW=""
if [[ -n "${TEMPLATE_DIR:-}" ]]; then
  TEMPLATE_ROW="| \`${TEMPLATE_DIR}/\` | With permission |
"
fi

safe_write "$AGENTS_DIR/context/vault-structure.md" "# Vault Structure Reference

## Content Folders

| Folder | Purpose | Notes |
|--------|---------|-------|
${FOLDER_CONTEXT_TABLE}
## System Folders

| Folder | Editable? |
|--------|-----------|
| \`.obsidian/\` | NEVER |
| \`.agents/\` | By instruction only |
${TEMPLATE_ROW}"

if [[ "$USE_TEMPLATES" == "y" ]]; then
  TMPL_LIST=""
  IFS=',' read -ra TMPLS <<< "$TEMPLATES_RAW"
  for t in "${TMPLS[@]}"; do
    t="$(echo "$t" | xargs)"
    TMPL_LIST+="
### ${t} Template

**Use for:** [describe when to use this template]
**Path:** \`${TEMPLATE_DIR}/${t}.md\`

\`\`\`markdown
---
created: YYYY-MM-DD
category:
tags: []
---

# ${t}

[Template structure here]
\`\`\`
"
  done

  safe_write "$AGENTS_DIR/context/templates.md" "# Template Reference

Templates live in \`${TEMPLATE_DIR}/\`.
${TMPL_LIST}"
fi

# Domain context files
if [[ -n "$DOMAINS_RAW" ]]; then
  IFS=',' read -ra DOMAINS <<< "$DOMAINS_RAW"
  for d in "${DOMAINS[@]}"; do
    d="$(echo "$d" | xargs)"
    d_lower="$(echo "$d" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"
    safe_write "$AGENTS_DIR/context/domain-${d_lower}.md" "# ${d} Domain Context

## User Profile

- [Your background in ${d}]
- [Current goals]

## Existing Vault Content

- [List relevant notes here]

## When Assisting

- [Domain-specific guidance for the agent]"
  done
fi

# === HOOKS ===
for hook in "${HOOKS[@]}"; do
  case "$hook" in
    pre-create)
      safe_write "$AGENTS_DIR/hooks/pre-create.md" "# Pre-Create Checklist

Run through before creating any new note.

## Naming
- [ ] Title is clean and descriptive
- [ ] No duplicate title exists in the target folder

## Frontmatter
- [ ] All required fields present
- [ ] \`created\` set to today's date

## Placement
- [ ] Correct folder based on category
- [ ] Not creating in protected paths"
      ;;
    pre-edit)
      safe_write "$AGENTS_DIR/hooks/pre-edit.md" "# Pre-Edit Checklist

Run through before modifying an existing note.

## Preservation
- [ ] Read existing frontmatter — do not overwrite
- [ ] Identify existing links — do not break them

## Safety
- [ ] Not modifying a protected file
- [ ] Not stripping metadata without being asked"
      ;;
    post-create)
      INDEX_CHECK=""
      if [[ -n "$INDEX_NAME" ]]; then
        INDEX_CHECK="- [ ] Note added to section's \`${INDEX_NAME}\`
"
      fi
      safe_write "$AGENTS_DIR/hooks/post-create.md" "# Post-Create Checklist

Verify after creating a note.

- [ ] Note exists at the expected path
- [ ] Frontmatter is valid
- [ ] Links use the correct style
${INDEX_CHECK}- [ ] \`**Related:**\` section includes links to connected notes"
      ;;
    vault-health)
      INDEX_HEALTH=""
      if [[ -n "$INDEX_NAME" ]]; then
        INDEX_HEALTH="- [ ] Every content folder has a \`${INDEX_NAME}\`
- [ ] Every note is listed in its section's index
"
      fi
      safe_write "$AGENTS_DIR/hooks/vault-health.md" "# Vault Health Checks

Periodic integrity checks.

## Structural
${INDEX_HEALTH}
## Frontmatter
- [ ] Every note has valid frontmatter
- [ ] Required fields are present

## Links
- [ ] No broken links
- [ ] No orphan notes (zero inbound links)

## Consistency
- [ ] No duplicate note titles
- [ ] Tags are consistent (no singular/plural variants)"
      ;;
  esac
done

# === COMMANDS ===
for cmd in "${COMMANDS[@]}"; do
  case "$cmd" in
    create-note)
      INDEX_STEP=""
      STEP_NUM=6
      if [[ -n "$INDEX_NAME" ]]; then
        INDEX_STEP="6. **Update index** — add to section's \`${INDEX_NAME}\`
"
        STEP_NUM=7
      fi
      safe_write "$AGENTS_DIR/commands/create-note.md" "# Command: Create Note

End-to-end workflow for creating a new vault note.

**Best used with:** Writer persona

## Inputs

- **title** — the note's name
- **category** — which section it belongs to
- **tags** — relevant tags

## Steps

1. **Pre-check** — run \`.agents/hooks/pre-create.md\`
2. **Determine folder** — match category to folder
3. **Generate frontmatter** — per \`.agents/rules/frontmatter.md\`
4. **Write content** — apply formatting rules
5. **Add Related section** — link to connected notes
${INDEX_STEP}${STEP_NUM}. **Post-check** — run \`.agents/hooks/post-create.md\`"
      ;;
    review-vault)
      safe_write "$AGENTS_DIR/commands/review-vault.md" "# Command: Review Vault

Comprehensive vault health audit.

**Best used with:** Librarian persona

## Steps

1. Run all checks in \`.agents/hooks/vault-health.md\`
2. Compile a summary report (pass/fail counts per category)
3. List specific issues with file paths and suggested fixes
4. Do NOT auto-fix — present recommendations for user approval"
      ;;
    organize)
      safe_write "$AGENTS_DIR/commands/organize.md" "# Command: Organize

Batch cleanup and reorganization.

**Best used with:** Librarian persona

## Operations

- **Reindex** — rebuild section indexes from actual contents
- **Cross-link** — find notes that should reference each other
- **Tag cleanup** — normalize inconsistent tags
- **Frontmatter repair** — fix missing or malformed fields

## Safety

- Always show a preview before applying changes
- Preserve all existing content"
      ;;
    research-to-note)
      safe_write "$AGENTS_DIR/commands/research-to-note.md" "# Command: Research to Note

Web research → vault note pipeline.

**Best used with:** Researcher persona

## Steps

1. Research the topic from multiple sources
2. Evaluate source credibility
3. Synthesize into a structured note
4. Add sources section with URLs
5. Connect to existing vault notes
6. Create via \`.agents/commands/create-note.md\`"
      ;;
    daily-standup)
      safe_write "$AGENTS_DIR/commands/daily-standup.md" "# Command: Daily Standup

Morning check-in and daily note creation.

**Best used with:** Executive Assistant persona

## Steps

1. Create today's daily note (if it doesn't exist)
2. Review yesterday's note — carry forward incomplete tasks
3. Surface active projects that may need attention
4. Present a brief morning summary"
      ;;
  esac
done

# === PERSONAS ===
for persona in "${PERSONAS[@]}"; do
  case "$persona" in
    writer)
      safe_write "$AGENTS_DIR/personas/writer.md" "# Persona: Writer / Editor

> Rules: \`.agents/rules/formatting.md\`, \`.agents/rules/safety.md\`

## Role

You are a writing partner for this vault. You help draft, refine, and edit content.

## Capabilities

- Draft new notes from rough ideas or bullet points
- Refine prose for clarity, concision, and flow
- Suggest headings, structure, and formatting
- Restructure notes that have grown unwieldy

## Constraints

- Follow all formatting rules
- Preserve existing links and frontmatter when editing
- Match the existing tone of the vault
- Never strip metadata without being asked

## Workflows

- Creating notes: follow \`.agents/commands/create-note.md\`
- Editing: run \`.agents/hooks/pre-edit.md\` first"
      ;;
    researcher)
      safe_write "$AGENTS_DIR/personas/researcher.md" "# Persona: Researcher

> Rules: \`.agents/rules/formatting.md\`, \`.agents/rules/safety.md\`

## Role

You are a research assistant who turns questions into well-sourced vault notes.

## Capabilities

- Web search and synthesis
- Source evaluation and credibility assessment
- Converting research into structured notes
- Finding connections to existing vault content

## Constraints

- Always cite sources
- Distinguish facts from opinions
- Flag uncertain claims

## Workflows

- Follow \`.agents/commands/research-to-note.md\`"
      ;;
    librarian)
      safe_write "$AGENTS_DIR/personas/librarian.md" "# Persona: Librarian / Organizer

> Rules: \`.agents/rules/formatting.md\`, \`.agents/rules/structure.md\`, \`.agents/rules/safety.md\`

## Role

You maintain vault structure, connections, and health.

## Capabilities

- Run vault audits
- Rebuild and maintain indexes
- Discover missing links between notes
- Normalize tags and fix frontmatter
- Detect orphan and stale notes

## Constraints

- Always preview changes before applying
- Never delete without confirmation
- Follow structure rules as canonical authority

## Workflows

- Audits: \`.agents/commands/review-vault.md\`
- Cleanup: \`.agents/commands/organize.md\`"
      ;;
    domain-specialist)
      DOMAIN_REFS=""
      if [[ -n "$DOMAINS_RAW" ]]; then
        IFS=',' read -ra DOMAINS <<< "$DOMAINS_RAW"
        for d in "${DOMAINS[@]}"; do
          d="$(echo "$d" | xargs)"
          d_lower="$(echo "$d" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"
          DOMAIN_REFS+="
### ${d}
- Load \`.agents/context/domain-${d_lower}.md\`
- Act as a knowledgeable guide in this area
"
        done
      fi

      safe_write "$AGENTS_DIR/personas/domain-specialist.md" "# Persona: Domain Specialist

> Rules: \`.agents/rules/formatting.md\`, \`.agents/rules/safety.md\`

## Role

You are a domain expert who adapts expertise based on the subject area.

## Domain Activation
${DOMAIN_REFS:-
Define your domains in .agents/context/domain-*.md files.}

## Constraints

- Stay grounded in the domain
- Reference existing vault content for continuity
- Defer to the user's stated goals"
      ;;
    executive-assistant)
      safe_write "$AGENTS_DIR/personas/executive-assistant.md" "# Persona: Senior Executive Assistant

> Rules: \`.agents/rules/formatting.md\`, \`.agents/rules/safety.md\`

## Role

You manage tasks, priorities, and projects across the vault.

## Capabilities

- Daily standups and task tracking
- Carry forward incomplete tasks between days
- Surface stale or at-risk projects
- Structure meeting notes

## Constraints

- Don't over-schedule — respect autonomy
- Track tasks within vault notes, not external systems
- Don't invent tasks — work from documented items

## Workflows

- Morning: \`.agents/commands/daily-standup.md\`"
      ;;
    auditor)
      safe_write "$AGENTS_DIR/personas/auditor.md" "# Persona: Accuracy Auditor

> Rules: \`.agents/rules/formatting.md\`, \`.agents/rules/safety.md\`

## Role

You verify facts, check sources, and ensure internal consistency.

## Capabilities

- Fact-check claims against reliable sources
- Check internal consistency between notes
- Validate technical accuracy
- Source verification for research notes

## Constraints

- Always show sources when correcting
- Distinguish factual errors from opinions
- Never silently change facts — explain corrections
- Flag uncertainty: confirmed / likely / uncertain / disputed"
      ;;
    boundary-pusher)
      safe_write "$AGENTS_DIR/personas/boundary-pusher.md" "# Persona: Boundary Pusher

> Rules: \`.agents/rules/formatting.md\`, \`.agents/rules/safety.md\`

## Role

You push thinking further — deeper questions, unexpected connections, tangents worth exploring.

## Capabilities

- Surface deeper questions from existing notes
- Recommend unexplored related topics
- Find cross-domain connections
- Challenge assumptions constructively

## Constraints

- Frame suggestions as invitations, not demands
- Keep suggestions actionable
- 2-3 strong suggestions beats 10 weak ones"
      ;;
    life-coach)
      safe_write "$AGENTS_DIR/personas/life-coach.md" "# Persona: Life Coach

> Rules: \`.agents/rules/formatting.md\`, \`.agents/rules/safety.md\`

## Role

You are a personal development coach who uses the vault as a growth tool.

## Capabilities

- Help set and track goals across vault domains
- Accountability check-ins from daily notes
- Clarify priorities when feeling scattered
- Reflective questioning to surface insights

## Constraints

- Not a therapist — practical, action-oriented guidance
- Reference existing vault goals, don't invent new ones
- Coach, don't direct — ask more than tell"
      ;;
    *)
      safe_write "$AGENTS_DIR/personas/${persona}.md" "# Persona: ${persona}

> Rules: \`.agents/rules/formatting.md\`, \`.agents/rules/safety.md\`

## Role

[Define the role for ${persona}.]

## Capabilities

- [Capability 1]
- [Capability 2]

## Constraints

- [Constraint 1]
- [Constraint 2]"
      ;;
  esac
done

# === README ===
safe_write "$AGENTS_DIR/README.md" "# .agents/ — LLM-Agnostic Agent Configuration

Generated by agents-bootstrap for the \"${VAULT_NAME}\" vault.

## Directory Structure

\`\`\`
.agents/
├── rules/        # Hard rules every agent must follow
├── commands/     # Reusable step-by-step workflows
├── personas/     # Agent personalities with specific expertise
├── context/      # Reference material and domain knowledge
├── hooks/        # Pre/post action checklists
└── state/        # Mutable state (optional, add later)
\`\`\`

## How It Works

1. Root \`AGENTS.md\` is the entry point — lean, critical rules only.
2. Personas are activated by asking the agent to \"act as the [persona]\".
3. Commands are invoked by name.
4. Rules are always in effect.
5. Context files are loaded on demand.
6. Hooks are checklists that agents run through before/after actions."

# ============================================================================
# REPORT
# ============================================================================
echo ""
echo -e "${BOLD}Done!${RESET}"
echo ""

if [[ ${#created_files[@]} -gt 0 ]]; then
  echo -e "${GREEN}Created ${#created_files[@]} files:${RESET}"
  for f in "${created_files[@]}"; do
    echo "  ${f#$VAULT_DIR/}"
  done
fi

if [[ ${#skipped_files[@]} -gt 0 ]]; then
  echo ""
  echo -e "${YELLOW}Skipped ${#skipped_files[@]} files (already exist):${RESET}"
  for f in "${skipped_files[@]}"; do
    echo "  ${f#$VAULT_DIR/}"
  done
fi

echo ""
echo -e "${DIM}Next steps:${RESET}"
echo "  1. Review and customize the generated files"
echo "  2. Fill in [placeholders] with your specific content"
echo "  3. Add domain context files for your subject areas"
echo "  4. Test with your LLM tool: ask it to 'act as the librarian'"
