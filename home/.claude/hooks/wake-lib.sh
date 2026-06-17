#!/bin/sh
# Shared helpers for the wake follow-mode hooks.
# Resolves the git toplevel (activation gate) and the centralized state dir.
# Sourced by wake-mark and wake-diff; never run directly.

wake_resolve() {
	# Mode B headless patcher runs set this so its sessions don't clobber the
	# Mode A baseline or waste work on the diff report.
	[ -n "$WAKE_DISABLE" ] && return 1
	# Activation gate: only operate inside a git repo. Use the toplevel as the
	# snapshot scope so launching CC in a subdir still tracks the whole repo.
	wake_root=$(git -C "${CLAUDE_PROJECT_DIR:-$PWD}" rev-parse --show-toplevel 2>/dev/null) || return 1
	[ -n "$wake_root" ] || return 1
	wake_key=$(printf %s "$wake_root" | sha1sum | cut -c1-16)
	wake_state="$HOME/.claude/wake/$wake_key"
	wake_base="$wake_state/base"
	wake_index="$wake_state/index"
	mkdir -p "$wake_state" || return 1
	return 0
}

# Snapshot the working tree into the private wake index (respects .gitignore,
# never touches the real index or HEAD) and echo the resulting tree hash.
wake_snapshot_tree() {
	GIT_INDEX_FILE="$wake_index" git -C "$wake_root" add -A 2>/dev/null
	GIT_INDEX_FILE="$wake_index" git -C "$wake_root" write-tree 2>/dev/null
}
