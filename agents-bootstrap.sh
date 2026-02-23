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
    printf '%s\n' "$content" > "$path"
    created_files+=("$path")
  fi
}

# Prompt with default (uses existing value on re-entry, < goes back)
ask() {
  local prompt="$1" default="$2" var_name="$3"
  local _prev=""
  eval "_prev=\"\${$var_name:-}\""
  if [[ -n "$_prev" ]]; then default="$_prev"; fi
  echo -en "${CYAN}${prompt}${RESET}"
  if [[ -n "$default" ]]; then
    echo -en " ${DIM}[${default}]${RESET}"
  fi
  echo -n ": "
  read -r input
  if [[ "$input" == "<" ]]; then _GO_BACK=1; return; fi
  printf -v "$var_name" '%s' "${input:-$default}"
}

# Yes/no prompt (uses existing value on re-entry, < goes back)
ask_yn() {
  local prompt="$1" default="$2" var_name="$3"
  local _prev=""
  eval "_prev=\"\${$var_name:-}\""
  if [[ -n "$_prev" ]]; then default="$_prev"; fi
  local hint="[Y/n]"
  if [[ "$default" == "n" ]]; then hint="[y/N]"; fi
  echo -en "${CYAN}${prompt}${RESET} ${DIM}${hint}${RESET}: "
  read -r input
  if [[ "$input" == "<" ]]; then _GO_BACK=1; return; fi
  input="${input:-$default}"
  case "$input" in
    [yY]*) printf -v "$var_name" '%s' "y" ;;
    *) printf -v "$var_name" '%s' "n" ;;
  esac
}

# Interactive checkbox selector
# Usage: ask_checkbox "prompt" RESULT_VAR "key1:Description" "key2:Description" ...
# Returns comma-separated selected keys in RESULT_VAR (empty string if none).
ask_checkbox() {
  local prompt="$1" var_name="$2"
  shift 2
  local items=("$@")
  local count=${#items[@]}
  local keys=() descs=()
  local cursor=0 i

  for item in "${items[@]}"; do
    keys+=("${item%%:*}")
    descs+=("${item#*:}")
  done

  local selected=()
  for ((i=0; i<count; i++)); do selected[$i]=0; done

  # Pre-select from existing value on re-entry
  local _prev=""
  eval "_prev=\"\${$var_name:-}\""
  if [[ -n "$_prev" ]]; then
    local _prev_items
    IFS=',' read -ra _prev_items <<< "$_prev"
    local _p
    for ((i=0; i<count; i++)); do
      for _p in "${_prev_items[@]}"; do
        _p="$(echo "$_p" | xargs)"
        if [[ "$_p" == "${keys[$i]}" ]]; then selected[$i]=1; fi
      done
    done
  fi

  # Non-interactive fallback
  if [[ ! -t 0 ]]; then
    local all_keys
    all_keys="$(IFS=,; echo "${keys[*]}")"
    echo -e "${CYAN}${prompt}${RESET}"
    echo -e "${DIM}Options: ${all_keys}${RESET}"
    echo -n "Select (comma-separated, or 'all'): "
    read -r input
    if [[ "$input" == "all" ]]; then input="$all_keys"; fi
    printf -v "$var_name" '%s' "$input"
    return
  fi

  # Pad key names for alignment
  local max_len=0
  for k in "${keys[@]}"; do
    if [[ ${#k} -gt $max_len ]]; then max_len=${#k}; fi
  done

  # Hide cursor during interaction; restore on exit/interrupt
  tput civis 2>/dev/null || true
  trap 'tput cnorm 2>/dev/null' EXIT INT TERM

  echo -e "${CYAN}${prompt}${RESET}"
  echo -e "${DIM}  ↑/↓ navigate · space toggle · a all · n none · ← back · enter confirm${RESET}"

  # Initial draw
  for ((i=0; i<count; i++)); do
    local mark=" " padded
    if [[ ${selected[$i]} -eq 1 ]]; then mark="x"; fi
    printf -v padded "%-${max_len}s" "${keys[$i]}"
    if [[ $i -eq $cursor ]]; then
      echo -e "  ${BOLD}> [${mark}] ${padded}  ${descs[$i]}${RESET}"
    else
      echo -e "    [${mark}] ${padded}  ${DIM}${descs[$i]}${RESET}"
    fi
  done

  while true; do
    local key=""
    IFS= read -rsn1 key
    case "$key" in
      $'\x1b')
        local seq=""
        read -rsn2 seq
        case "$seq" in
          '[A') if [[ $cursor -gt 0 ]]; then cursor=$((cursor - 1)); fi ;;
          '[B') if [[ $cursor -lt $((count - 1)) ]]; then cursor=$((cursor + 1)); fi ;;
          '[D') _GO_BACK=1; break ;;  # left arrow = back
        esac ;;
      ' ') selected[$cursor]=$(( 1 - ${selected[$cursor]} )) ;;
      a|A) for ((i=0; i<count; i++)); do selected[$i]=1; done ;;
      n|N) for ((i=0; i<count; i++)); do selected[$i]=0; done ;;
      '') break ;;
    esac
    # Redraw: move cursor up count lines, clearing each
    for ((i=0; i<count; i++)); do echo -en "\033[A\033[2K"; done
    for ((i=0; i<count; i++)); do
      local mark=" " padded
      if [[ ${selected[$i]} -eq 1 ]]; then mark="x"; fi
      printf -v padded "%-${max_len}s" "${keys[$i]}"
      if [[ $i -eq $cursor ]]; then
        echo -e "  ${BOLD}> [${mark}] ${padded}  ${descs[$i]}${RESET}"
      else
        echo -e "    [${mark}] ${padded}  ${DIM}${descs[$i]}${RESET}"
      fi
    done
  done

  tput cnorm 2>/dev/null || true
  trap - EXIT INT TERM

  # If going back, don't update the variable
  if [[ ${_GO_BACK:-0} -eq 1 ]]; then return; fi

  # Build comma-separated result
  local result=""
  for ((i=0; i<count; i++)); do
    if [[ ${selected[$i]} -eq 1 ]]; then
      if [[ -n "$result" ]]; then result+=","; fi
      result+="${keys[$i]}"
    fi
  done

  # Print selection summary
  if [[ -n "$result" ]]; then
    echo -e "${DIM}Selected: ${result}${RESET}"
  else
    echo -e "${DIM}(none selected)${RESET}"
  fi

  printf -v "$var_name" '%s' "$result"
}

# Section header for a given step number
_show_header() {
  case $1 in
    1|2)
      echo -e "\n${BOLD}1. VAULT IDENTITY${RESET}"
      echo -e "${DIM}These become the header of your root AGENTS.md — the first thing any LLM${RESET}"
      echo -e "${DIM}reads when it opens your vault. A clear name and description help the agent${RESET}"
      echo -e "${DIM}understand what this vault is for and set the right tone.${RESET}" ;;
    3|4|5)
      echo -e "\n${BOLD}2. VAULT STRUCTURE${RESET}"
      echo -e "${DIM}Your folder layout becomes the agent's mental map of where things go.${RESET}"
      echo -e "${DIM}List the top-level folders where content lives. Index/hub notes are optional${RESET}"
      echo -e "${DIM}navigation files (e.g. '00 - Index.md') that link to everything in a folder.${RESET}" ;;
    6)
      echo -e "\n${BOLD}3. CONVENTIONS${RESET}"
      echo -e "${DIM}These rules ensure the agent writes notes that look and feel like yours.${RESET}"
      echo -e "${DIM}Consistent linking, frontmatter, and templates prevent cleanup work later.${RESET}" ;;
    7|8|9)
      echo -e "\n${DIM}Frontmatter is the YAML metadata block at the top of each note (between --- markers).${RESET}"
      echo -e "${DIM}It gives agents structured info about each note — category, tags, dates, status —${RESET}"
      echo -e "${DIM}so they can organize, filter, and validate without reading the full content.${RESET}" ;;
    10|11|12)
      echo -e "\n${DIM}Templates are starter files the agent uses when creating new notes. Each template${RESET}"
      echo -e "${DIM}pre-fills frontmatter and section headings for a specific note type, so the agent${RESET}"
      echo -e "${DIM}produces consistent structure without you having to specify it every time.${RESET}" ;;
    13|14)
      echo -e "\n${BOLD}4. SAFETY BOUNDARIES${RESET}"
      echo -e "${DIM}Protected paths are off-limits — the agent will never modify them.${RESET}"
      echo -e "${DIM}Private folders won't be referenced in notes or shared content.${RESET}" ;;
    15|16)
      echo -e "\n${BOLD}5. PERSONAS${RESET}"
      echo -e "${DIM}Personas are distinct agent roles you activate by saying 'act as the [persona]'.${RESET}"
      echo -e "${DIM}Each one has its own expertise, tone, and rules. Pick what fits your workflow —${RESET}"
      echo -e "${DIM}you can always add more later by creating files in .agents/personas/.${RESET}" ;;
    17)
      echo -e "\n${BOLD}6. COMMANDS${RESET}"
      echo -e "${DIM}Commands are reusable step-by-step workflows the agent follows when you invoke${RESET}"
      echo -e "${DIM}them by name (e.g. 'run create-note'). They chain together rules, hooks, and${RESET}"
      echo -e "${DIM}personas into repeatable processes.${RESET}" ;;
    18)
      echo -e "\n${BOLD}7. HOOKS${RESET}"
      echo -e "${DIM}Hooks are quality checklists the agent runs before or after actions — like${RESET}"
      echo -e "${DIM}verifying frontmatter before creating a note, or checking links afterward.${RESET}"
      echo -e "${DIM}They catch mistakes before they compound.${RESET}" ;;
  esac
}

# Map step to section group (for header display)
_section_of() {
  case $1 in
    1|2) echo 1 ;; 3|4|5) echo 2 ;; 6) echo 3 ;; 7|8|9) echo 4 ;;
    10|11|12) echo 5 ;; 13|14) echo 6 ;; 15|16) echo 7 ;;
    17) echo 8 ;; 18) echo 9 ;;
  esac
}

# ============================================================================
# MAIN WIZARD LOOP — one step per prompt, < to go back
# ============================================================================
#
# Steps:
#  1  Vault name                          (always)
#  2  Vault description                   (always)
#  3  Content folders                     (always)
#  4  Index hub notes? y/n                (always)
#  5  Index file name                     (if HAS_INDEXES=y)
#  6  Link style 1/2/3                    (always)
#  7  Use frontmatter? y/n               (always)
#  8  Required frontmatter fields         (if USE_FRONTMATTER=y)
#  9  Optional frontmatter fields         (if USE_FRONTMATTER=y)
# 10  Use templates? y/n                  (always)
# 11  Template folder path                (if USE_TEMPLATES=y)
# 12  Template names                      (if USE_TEMPLATES=y)
# 13  Protected paths                     (always)
# 14  Private folders                     (always)
# 15  Personas checkbox                   (always)
# 16  Domain specialist areas             (if domain-specialist selected)
# 17  Commands checkbox                   (always)
# 18  Hooks checkbox                      (always)

echo -e "${BOLD}AGENTS Bootstrap${RESET}"
echo -e "${DIM}Generating an LLM-agnostic .agents/ system for your Obsidian vault.${RESET}"
echo -e "${DIM}Vault directory: ${VAULT_DIR}${RESET}"
echo -e "${DIM}Type < at any prompt to go back.${RESET}"

_GO_BACK=0
_step=1
_dir=1        # 1=forward, -1=backward
_prev_sec=0

while [[ $_step -ge 1 && $_step -le 18 ]]; do
  _GO_BACK=0
  _skip=0
  _retry=0

  # Show section header when entering a new section group
  _cur_sec=$(_section_of $_step)
  if [[ $_cur_sec -ne $_prev_sec ]]; then
    _show_header $_step
    _prev_sec=$_cur_sec
  fi

  case $_step in
    1)  ask "Vault name" "my-vault" VAULT_NAME ;;
    2)  ask "Brief vault description (one sentence)" "An Obsidian knowledge vault" VAULT_DESC ;;
    3)  ask "Content folders (comma-separated)" "Notes,Projects,Reference,Archive" FOLDERS_RAW ;;
    4)  ask_yn "Should your folders have index/hub notes?" "y" HAS_INDEXES ;;
    5)  if [[ "${HAS_INDEXES:-n}" != "y" ]]; then INDEX_NAME=""; _skip=1
        else ask "Index file name convention" "00 - Index.md" INDEX_NAME; fi ;;
    6)  echo -e "${DIM}Link style:${RESET}"
        echo "  1) Wiki links only [[Note Name]]"
        echo "  2) Markdown links only [text](path)"
        echo "  3) Mixed / no preference"
        echo -en "Choose (1/2/3) ${DIM}[${LINK_STYLE:-1}]${RESET}: "
        read -r _ls_input
        if [[ "$_ls_input" == "<" ]]; then _GO_BACK=1
        elif [[ -z "$_ls_input" ]]; then LINK_STYLE="${LINK_STYLE:-1}"
        elif [[ "$_ls_input" =~ ^[123]$ ]]; then LINK_STYLE="$_ls_input"
        else echo -e "${YELLOW}Invalid choice — enter 1, 2, or 3${RESET}"; _retry=1; fi ;;
    7)  ask_yn "Use YAML frontmatter?" "y" USE_FRONTMATTER ;;
    8)  if [[ "${USE_FRONTMATTER:-n}" != "y" ]]; then _skip=1
        else echo -e "${DIM}Required fields must be present on every note. Optional fields are used when relevant.${RESET}"
             ask "Required frontmatter fields (comma-separated)" "created,category,tags" FM_FIELDS_RAW; fi ;;
    9)  if [[ "${USE_FRONTMATTER:-n}" != "y" ]]; then _skip=1
        else ask "Optional frontmatter fields (comma-separated, or none)" "status,type" FM_OPT_RAW; fi ;;
    10) ask_yn "Use note templates?" "y" USE_TEMPLATES ;;
    11) if [[ "${USE_TEMPLATES:-n}" != "y" ]]; then _skip=1
        else ask "Template folder path" "_templates" TEMPLATE_DIR; fi ;;
    12) if [[ "${USE_TEMPLATES:-n}" != "y" ]]; then _skip=1
        else ask "Template names (comma-separated)" "Daily,Project,Reference" TEMPLATES_RAW; fi ;;
    13) ask "Protected paths (comma-separated, .obsidian/ is always included)" ".obsidian/" PROTECTED_RAW ;;
    14) ask "Private/gitignored folders (comma-separated, or none)" "none" PRIVATE_RAW ;;
    15) ask_checkbox "Which personas do you want?" PERSONAS_RAW \
          "writer:Draft, refine, edit content" \
          "researcher:Web research → sourced notes" \
          "librarian:Vault health, links, indexes" \
          "domain-specialist:Per-domain expertise" \
          "executive-assistant:Tasks, standups, projects" \
          "auditor:Fact-checking, consistency" \
          "boundary-pusher:Cross-domain connections" \
          "life-coach:Goals, accountability" ;;
    16) if [[ "${PERSONAS_RAW:-}" != *"domain-specialist"* ]]; then _skip=1
        else ask "Domain specialist areas (comma-separated)" "General" DOMAINS_RAW; fi ;;
    17) ask_checkbox "Which commands do you want?" COMMANDS_RAW \
          "create-note:End-to-end note creation workflow" \
          "review-vault:Comprehensive vault health audit" \
          "organize:Batch cleanup and reorganization" \
          "research-to-note:Web research → vault note pipeline" \
          "daily-standup:Morning check-in and task carry-forward" ;;
    18) ask_checkbox "Which hooks do you want?" HOOKS_RAW \
          "pre-create:Check naming, frontmatter, placement before creating" \
          "pre-edit:Preserve links and metadata before modifying" \
          "post-create:Verify path, frontmatter, links after creating" \
          "vault-health:Periodic integrity and consistency checks" ;;
  esac

  # Navigate: retry, back, skip, or forward
  if [[ $_retry -eq 1 ]]; then
    : # stay on current step
  elif [[ $_GO_BACK -eq 1 ]]; then
    _dir=-1
    _step=$((_step + _dir))
  elif [[ $_skip -eq 1 ]]; then
    _step=$((_step + _dir))
  else
    _dir=1
    _step=$((_step + 1))
  fi

  if [[ $_step -lt 1 ]]; then _step=1; fi
done
echo ""

# Post-process arrays for file generation (guard empty strings to produce empty arrays)
if [[ -n "${FOLDERS_RAW:-}" ]]; then
  IFS=',' read -ra FOLDERS <<< "$FOLDERS_RAW"
  for i in "${!FOLDERS[@]}"; do FOLDERS[$i]="$(echo "${FOLDERS[$i]}" | xargs)"; done
else
  FOLDERS=()
fi

if [[ -n "${PERSONAS_RAW:-}" ]]; then
  IFS=',' read -ra PERSONAS <<< "$PERSONAS_RAW"
  for i in "${!PERSONAS[@]}"; do PERSONAS[$i]="$(echo "${PERSONAS[$i]}" | xargs)"; done
else
  PERSONAS=()
fi

if [[ -n "${COMMANDS_RAW:-}" ]]; then
  IFS=',' read -ra COMMANDS <<< "$COMMANDS_RAW"
  for i in "${!COMMANDS[@]}"; do COMMANDS[$i]="$(echo "${COMMANDS[$i]}" | xargs)"; done
else
  COMMANDS=()
fi

if [[ -n "${HOOKS_RAW:-}" ]]; then
  IFS=',' read -ra HOOKS <<< "$HOOKS_RAW"
  for i in "${!HOOKS[@]}"; do HOOKS[$i]="$(echo "${HOOKS[$i]}" | xargs)"; done
else
  HOOKS=()
fi

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
  INDEX_SECTION_BRIEF="Each section has a \`${INDEX_NAME}\` hub linking to its contents.

"
fi

# Normalize frontmatter fields display (ensure spaces after commas)
FM_FIELDS_DISPLAY="${FM_FIELDS_RAW:-created, category, tags}"
FM_FIELDS_DISPLAY="$(echo "$FM_FIELDS_DISPLAY" | sed 's/,\([^ ]\)/, \1/g')"

# === ROOT AGENTS.md ===
safe_write "$VAULT_DIR/AGENTS.md" "# ${VAULT_NAME} — Agent Instructions

${VAULT_DESC}. Be conversational — explain your reasoning, ask follow-ups, and think in terms of the knowledge graph.

## Critical Rules

- ${LINK_RULE}
- Every note needs YAML frontmatter: ${FM_FIELDS_DISPLAY}
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
