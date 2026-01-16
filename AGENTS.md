# gdrive-downloader Agent Guidelines

## Build/Lint/Test Commands

### Format and Lint
```bash
./format_and_lint.sh
```
- Runs `shfmt` to format all scripts (4 spaces, bash variant)
- Runs `shellcheck -o all -e SC2312` for linting
- Formats scripts in: `.`, `src/common`

### Merge and Release
```bash
./release.sh
```
Merges and minifies scripts into `release/gdl`

### Run All Tests
```bash
./test.sh
```
Runs integration tests for bash variant with and without --key flag

### Run Single Test
Tests are run via `test.sh` which calls the `_test` function. To run a specific test:
```bash
# Modify test.sh to comment out tests you don't want to run, then:
./test.sh
```

Note: There is no individual test runner - modify test.sh to run specific tests

### CI/CD
The GitHub workflow (.github/workflows/main.yml) runs:
1. Installation tests
2. Format, lint, and release tests
3. Download tests

## Code Style Guidelines

### File Structure
- `src/common/*.sh` - Shared utilities (Bash 4.x+)
- `src/gdl.sh` - Main entry point
- `release/bash/gdl` - Merged bash script

### Formatting (EditorConfig)
- Indent: 4 spaces
- End of line: LF
- Charset: UTF-8
- Trim trailing whitespace: yes
- Insert final newline: yes
- shell_variant: posix (.sh), bash (.bash)
- switch_case_indent: true
- space_redirects: true

### Shebang
```bash
#!/usr/bin/env bash  # All scripts use Bash 4.x+
```

### Shellcheck Directives
```bash
#!/usr/bin/env sh
# shellcheck source=/dev/null        # Top of every sourced script
# shellcheck disable=SC2317          # For unreachable functions
# shellcheck disable=SC2089/SC2090   # For eval usage
```

### Function Naming
All functions use underscore prefix:
```bash
_function_name() { ... }
```
Examples: `_download_file`, `_check_id`, `_api_request`, `_bytes_to_human`

### Variable Naming
Local variables within functions use `_` prefix with function name for scoping:
```bash
_function_name() {
    local_var_function_name="${1:?}"
    another_var="${2:-default}"
}
```

Global exports:
```bash
export API_URL="https://www.googleapis.com"
export DOWNLOADER="curl"
```

### Function Documentation
Standard format:
```bash
###################################################
# Brief description of function purpose
# Required Arguments: 1
#   ${1} = arg1 description
#   ${2} = arg2 description (optional)
# Result: What the function does/returns
# Reference:
#   https://url-to-reference (optional)
###################################################
_function_name() {
    ...
}
```

### Error Handling
- Use `|| return 1` pattern: `command || return 1`
- Mandatory arguments: `var="${1:?Error: Missing argument}"`
- Early return: `[ -z "${var}" ] && return 1`
- Exit codes: Return 0 on success, 1 on error; use `exit 1` for fatal errors
- Use `set -e` in scripts to exit on first error

### String Handling & Redirects
- Always quote variables: `"${variable}"`
- Default values: `"${variable:-default}"`
- Use `printf "%s\n"` for output
- Redirects: `>| file` (clobber), `>> file` (append), `2>| /dev/null 1>&2`

### Code Organization
- Main entry: `src/gdl.sh`
- Common utils: `src/common/common-utils.sh`
- Core: `src/common/drive-utils.sh`, `src/common/download-utils.sh`, `src/common/auth-utils.sh`
- Parser: `src/common/flags.sh`, `src/common/parser.sh`, `src/common/gdl-common.sh`

### Helper Functions (reuse these)
- `_dirname` - Alternative to dirname
- `_bytes_to_human` - Convert bytes to human readable
- `_epoch` - Get epoch seconds
- `_count` - Count lines
- `_assert_regex` - Check regex
- `_set_value` - Set/export values (direct/indirect)
- `_trim` - Remove character from string

### Testing Notes
Tests use real Google Drive IDs. Use `./gdl --skip-internet-check "url_or_id" [flags]`
Test IDs: FILE_ID="14eh2_N3rGeGzUMamk2uyoU_CF9O7YUkA", DOCUMENT_ID="1Dziv2X5_UCMQ2weMI9duSUT6iayMikqRdoftJCwq_vg", FOLDER_ID="1AC0UsKfLZfflIkO7Ork78et5VzIvFSDM"

### Important: No Comments
Do NOT add comments to code unless absolutely necessary. Function documentation is sufficient.


<!-- CLAVIX:START -->
# Clavix Instructions for Generic Agents

This guide is for agents that can only read documentation (no slash-command support). If your platform supports custom slash commands, use those instead.

---

## ⛔ CLAVIX MODE ENFORCEMENT

**CRITICAL: Know which mode you're in and STOP at the right point.**

**OPTIMIZATION workflows** (NO CODE ALLOWED):
- Improve mode - Prompt optimization only (auto-selects depth)
- Your role: Analyze, optimize, show improved prompt, **STOP**
- ❌ DO NOT implement the prompt's requirements
- ✅ After showing optimized prompt, tell user: "Run `/clavix:implement --latest` to implement"

**PLANNING workflows** (NO CODE ALLOWED):
- Conversational mode, requirement extraction, PRD generation
- Your role: Ask questions, create PRDs/prompts, extract requirements
- ❌ DO NOT implement features during these workflows

**IMPLEMENTATION workflows** (CODE ALLOWED):
- Only after user runs execute/implement commands
- Your role: Write code, execute tasks, implement features
- ✅ DO implement code during these workflows

**If unsure, ASK:** "Should I implement this now, or continue with planning?"

See `.clavix/instructions/core/clavix-mode.md` for complete mode documentation.

---

## 📁 Detailed Workflow Instructions

For complete step-by-step workflows, see `.clavix/instructions/`:

| Workflow | Instruction File | Purpose |
|----------|-----------------|---------|
| **Conversational Mode** | `workflows/start.md` | Natural requirements gathering through discussion |
| **Extract Requirements** | `workflows/summarize.md` | Analyze conversation → mini-PRD + optimized prompts |
| **Prompt Optimization** | `workflows/improve.md` | Intent detection + quality assessment + auto-depth selection |
| **PRD Generation** | `workflows/prd.md` | Socratic questions → full PRD + quick PRD |
| **Mode Boundaries** | `core/clavix-mode.md` | Planning vs implementation distinction |
| **File Operations** | `core/file-operations.md` | File creation patterns |
| **Verification** | `core/verification.md` | Post-implementation verification |

**Troubleshooting:**
- `troubleshooting/jumped-to-implementation.md` - If you started coding during planning
- `troubleshooting/skipped-file-creation.md` - If files weren't created
- `troubleshooting/mode-confusion.md` - When unclear about planning vs implementation

---

## 🔍 Workflow Detection Keywords

| Keywords in User Request | Recommended Workflow | File Reference |
|---------------------------|---------------------|----------------|
| "improve this prompt", "make it better", "optimize" | Improve mode → Auto-depth optimization | `workflows/improve.md` |
| "analyze thoroughly", "edge cases", "alternatives" | Improve mode (--comprehensive) | `workflows/improve.md` |
| "create a PRD", "product requirements" | PRD mode → Socratic questioning | `workflows/prd.md` |
| "let's discuss", "not sure what I want" | Conversational mode → Start gathering | `workflows/start.md` |
| "summarize our conversation" | Extract mode → Analyze thread | `workflows/summarize.md` |
| "refine", "update PRD", "change requirements", "modify prompt" | Refine mode → Update existing content | `workflows/refine.md` |
| "verify", "check my implementation" | Verify mode → Implementation verification | `core/verification.md` |

**When detected:** Reference the corresponding `.clavix/instructions/workflows/{workflow}.md` file.

---

## 📋 Clavix Commands (v5)

### Setup Commands (CLI)
| Command | Purpose |
|---------|---------|
| `clavix init` | Initialize Clavix in a project |
| `clavix update` | Update templates after package update |
| `clavix diagnose` | Check installation health |
| `clavix version` | Show version |

### Workflow Commands (Slash Commands)
All workflows are executed via slash commands that AI agents read and follow:

> **Command Format:** Commands shown with colon (`:`) format. Some tools use hyphen (`-`): Claude Code uses `/clavix:improve`, Cursor uses `/clavix-improve`. Your tool autocompletes the correct format.

| Slash Command | Purpose |
|---------------|---------|
| `/clavix:improve` | Optimize prompts (auto-selects depth) |
| `/clavix:prd` | Generate PRD through guided questions |
| `/clavix:plan` | Create task breakdown from PRD |
| `/clavix:implement` | Execute tasks or prompts (auto-detects source) |
| `/clavix:start` | Begin conversational session |
| `/clavix:summarize` | Extract requirements from conversation |
| `/clavix:refine` | Refine existing PRD or saved prompt |

### Agentic Utilities (Project Management)
These utilities provide structured workflows for project completion:

| Utility | Purpose |
|---------|---------|
| `/clavix:verify` | Check implementation against PRD requirements, run validation |
| `/clavix:archive` | Archive completed work to `.clavix/archive/` for reference |

**Quick start:**
```bash
npm install -g clavix
clavix init
```

**How it works:** Slash commands are markdown templates. When invoked, the agent reads the template and follows its instructions using native tools (Read, Write, Edit, Bash).

---

## 🔄 Standard Workflow

**Clavix follows this progression:**

```
PRD Creation → Task Planning → Implementation → Archive
```

**Detailed steps:**

1. **Planning Phase**
   - Run: `/clavix:prd` or `/clavix:start` → `/clavix:summarize`
   - Output: `.clavix/outputs/{project}/full-prd.md` + `quick-prd.md`
   - Mode: PLANNING

2. **Task Preparation**
   - Run: `/clavix:plan` transforms PRD into curated task list
   - Output: `.clavix/outputs/{project}/tasks.md`
   - Mode: PLANNING (Pre-Implementation)

3. **Implementation Phase**
   - Run: `/clavix:implement`
   - Agent executes tasks systematically
   - Mode: IMPLEMENTATION
   - Agent edits tasks.md directly to mark progress (`- [ ]` → `- [x]`)

4. **Completion**
   - Run: `/clavix:archive`
   - Archives completed work
   - Mode: Management

**Key principle:** Planning workflows create documents. Implementation workflows write code.

---

## 💡 Best Practices for Generic Agents

1. **Always reference instruction files** - Don't recreate workflow steps inline, point to `.clavix/instructions/workflows/`

2. **Respect mode boundaries** - Planning mode = no code, Implementation mode = write code

3. **Use checkpoints** - Follow the CHECKPOINT pattern from instruction files to track progress

4. **Create files explicitly** - Use Write tool for every file, verify with ls, never skip file creation

5. **Ask when unclear** - If mode is ambiguous, ask: "Should I implement or continue planning?"

6. **Track complexity** - Use conversational mode for complex requirements (15+ exchanges, 5+ features, 3+ topics)

7. **Label improvements** - When optimizing prompts, mark changes with [ADDED], [CLARIFIED], [STRUCTURED], [EXPANDED], [SCOPED]

---

## ⚠️ Common Mistakes

### ❌ Jumping to implementation during planning
**Wrong:** User discusses feature → agent generates code immediately

**Right:** User discusses feature → agent asks questions → creates PRD/prompt → asks if ready to implement

### ❌ Skipping file creation
**Wrong:** Display content in chat, don't write files

**Right:** Create directory → Write files → Verify existence → Display paths

### ❌ Recreating workflow instructions inline
**Wrong:** Copy entire fast mode workflow into response

**Right:** Reference `.clavix/instructions/workflows/improve.md` and follow its steps

### ❌ Not using instruction files
**Wrong:** Make up workflow steps or guess at process

**Right:** Read corresponding `.clavix/instructions/workflows/*.md` file and follow exactly

---

**Artifacts stored under `.clavix/`:**
- `.clavix/outputs/<project>/` - PRDs, tasks, prompts
- `.clavix/templates/` - Custom overrides

---

**For complete workflows:** Always reference `.clavix/instructions/workflows/{workflow}.md`

**For troubleshooting:** Check `.clavix/instructions/troubleshooting/`

**For mode clarification:** See `.clavix/instructions/core/clavix-mode.md`

<!-- CLAVIX:END -->
