#!/bin/bash
# Installs Claude Code skills on macOS or Linux. On a Mac, double-click setup.command instead.
# On Windows, double-click setup.bat.
# Safe to run again: anything already in place is skipped, existing repos are pulled.

# ---- Configuration --------------------------------------------------------
# One line per skill: skill name | repo URL | folder that holds the clone
SKILLS=(
  "rubydai-godot-bonus-skill|https://github.com/rubydai-dev/Rubydai-godot-bonus-skill.git|$HOME/Desktop/Godot game projects"
)

# Lines that must be in ~/.claude/CLAUDE.md: skill name | line.
# A line is skipped if the file already mentions `skill name` in backticks.
CLAUDE_MD_LINES=(
  "rubydai-godot-bonus-skill|- In every Godot project (one with a project.godot file), always use the \`rubydai-godot-bonus-skill\` skill."
)
# ---------------------------------------------------------------------------

SKILLS_DIR="$HOME/.claude/skills"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"
ERRORS=0

ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; }
fail() { printf '  \033[31m✗\033[0m %s\n' "$1"; ERRORS=$((ERRORS + 1)); }

finish() {
  echo
  if [ "$ERRORS" -eq 0 ]; then
    echo "Done. Start a new Claude Code session and type / to see the skills."
  else
    echo "$ERRORS error(s); see the ✗ lines above."
  fi
  exit "$ERRORS"
}

echo "== Tools =="
if [ "$(uname)" = "Darwin" ] && ! xcode-select -p >/dev/null 2>&1; then
  # On macOS, /usr/bin/git exists even before the Command Line Tools are installed, so check those instead.
  warn "Command Line Tools (git) are missing. Opening the installer..."
  xcode-select --install 2>/dev/null
  fail "Once the Command Line Tools are installed, run this again."
  finish
fi
if ! command -v git >/dev/null 2>&1; then
  if command -v apt-get >/dev/null 2>&1; then hint="sudo apt-get install git"
  elif command -v dnf >/dev/null 2>&1; then hint="sudo dnf install git"
  elif command -v pacman >/dev/null 2>&1; then hint="sudo pacman -S git"
  elif command -v zypper >/dev/null 2>&1; then hint="sudo zypper install git"
  else hint="your package manager"
  fi
  fail "git is missing. Install it with: $hint, then run this again."
  finish
fi
ok "git $(git --version | awk '{print $3}')"

if command -v claude >/dev/null 2>&1; then
  ok "Claude Code is installed"
else
  warn "The claude command wasn't found. Skills are installed anyway; remember to install Claude Code."
fi

echo
echo "== Skills =="
mkdir -p "$SKILLS_DIR"
for entry in "${SKILLS[@]}"; do
  IFS='|' read -r name url parent <<< "$entry"
  repo="$parent/$name"
  link="$SKILLS_DIR/$name"
  echo "$name"

  if [ -d "$repo/.git" ]; then
    if git -C "$repo" pull --ff-only -q; then
      ok "Pulled: $repo"
    else
      fail "Couldn't pull (uncommitted changes or a diverged branch?): $repo"
    fi
  elif [ -e "$repo" ]; then
    fail "$repo exists but isn't a git repo; skipped."
    continue
  else
    mkdir -p "$parent"
    if git clone -q "$url" "$repo"; then
      ok "Cloned into $repo"
    else
      fail "Couldn't clone $url (a private repo needs a GitHub login)."
      continue
    fi
  fi

  if [ -L "$link" ]; then
    if [ "$(readlink "$link")" = "$repo" ]; then
      ok "Symlink is correct: $link"
    else
      fail "$link points to $(readlink "$link"), not $repo. Delete that symlink and run again."
    fi
  elif [ -e "$link" ]; then
    fail "$link exists and isn't a symlink; skipped."
  else
    ln -s "$repo" "$link" && ok "Created symlink: $link"
  fi
done

echo
echo "== ~/.claude/CLAUDE.md =="
touch "$CLAUDE_MD"
for entry in "${CLAUDE_MD_LINES[@]}"; do
  skill="${entry%%|*}"
  line="${entry#*|}"
  if grep -qF -- "\`$skill\`" "$CLAUDE_MD"; then
    ok "Already mentions $skill"
  else
    # Add a newline first if the file doesn't end with one
    [ -s "$CLAUDE_MD" ] && [ "$(tail -c1 "$CLAUDE_MD")" != "" ] && echo >> "$CLAUDE_MD"
    echo "$line" >> "$CLAUDE_MD"
    ok "Added: $line"
  fi
done

finish
