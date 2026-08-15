---
name: tailfleet
description: Inspect hardware and run programs across the user's Tailscale network (linux nodes). Use when the user wants to see CPU/GPU/memory/load across their tailnet machines, dispatch/monitor a job routine on remote nodes, sync files to/from nodes, stream job logs, or check what is currently running on the fleet.
---

# tailfleet

A CLI that discovers linux nodes on the user's Tailscale network (`tailscale status`)
and over SSH (passwordless) monitors hardware and dispatches job routines defined in
a per-project `tailfleet.yaml`.

## Invocation

The `tailfleet` shell alias only exists in the user's interactive zsh. From the
bash tool, always invoke:

```
uv run --project ~/tools/orion/tailfleet tailfleet <subcommand> [args]
```

Use `--project` (not `--directory`): job subcommands find `tailfleet.yaml` by
searching upward from the **current directory**, so cwd must stay in the user's
project.

## Subcommands

| command | purpose |
|---|---|
| `status` (default) | one-shot `nvidia-smi`-style fleet table (Node / CPU / Memory / GPU, with CPU+GPU temps, util bar gauges, VRAM). Non-interactive — **safe to run from the bash tool** to read hardware. Flag: `--timeout`. |
| `monitor` | the same table, live-refreshing at the top of the screen. `-`/`+` adjust the refresh rate (shown as `⟳ Ns`), `q` quits. Interactive only — do not run from the bash tool; tell the user to run `tailfleet monitor` themselves. |
| `run <routine>` | push files (`--prune` to also delete stale remote files), then dispatch the routine on its nodes (detached via `setsid`). `--wait` blocks until it exits, `--tail N` then prints the last N log lines, `--timeout S` gives up. |
| `wait <routine>` | block until the routine leaves `running` on every node; exits `0` only if all nodes exited `0`, else the first nonzero code, `124` on `--timeout`, `3` if stale. Blocks remotely over one SSH per node, so it is not a client polling loop. |
| `ps` | routine × node table: running / exit code / duration |
| `jobs [-a]` | fleet-wide job table across **every** node and workspace, ignoring cwd/config. Running-only unless `-a`. Safe to run from the bash tool. |
| `logs <routine>[@<node>] [-f] [-n N]` | tail a routine's log; `@node` required if the routine has multiple nodes |
| `kill <routine>` | TERM the routine's process group on its nodes |
| `lease [list]` | which node each session holds, by codename. `take`/`release` are the user's via `/lease`; never run them. |
| `sync` | push the `push:` globs to all routine nodes, no dispatch. `--prune` also deletes remote files matching a push glob that the current push did not send. |
| `pull` | fetch the `pull:` globs from all routine nodes back into the project |

## tailfleet.yaml

Lives at the project root (found from cwd upward):

```yaml
workspace: myproj             # remote dir name; defaults to local dir basename
push: [src/**/*.py, pyproject.toml, uv.lock]   # host → nodes
pull: [out/**, logs/*.log]                     # nodes → host

routines:
  train:
    nodes: [node-a, node-b]   # or ["*"] = every online linux node
    run: |
      uv sync --frozen
      uv run python train.py --shard $TF_NODE_INDEX/$TF_NODE_COUNT
```

## Waiting on a dispatch

`run` returns as soon as the routine is dispatched; results only appear later in `logs`. **Do not
poll with a shell `until ...; do sleep; done` loop** — that blocks the whole turn and the user sees
nothing for as long as the job takes. Two correct options:

- `tailfleet run <routine> --wait --tail 40` as a **backgrounded** Bash call
  (`run_in_background: true`), so the turn ends and you are re-invoked when it finishes.
- Dispatch with a plain `run`, tell the user it is running, and check `tailfleet logs` on a later
  turn.

Use `--wait` in the foreground only when the routine is known to be short.

## Which node to use

Nothing is leased by default. Every turn a `UserPromptSubmit` hook states this session's node, or
says none is leased. Write routine `nodes:` as that node and do not ask which machine to use.

**If no node is leased, run nothing on the fleet** — say so and let the user run `/lease <node>`.
**Never take, move, or release a lease yourself**, even when asked; point them at `/lease`. A lease
is `~/.tailfleet/leases/<node>` holding the session id and a codename (`pine`, `marlin`) that
identifies the session in `status`, `monitor` and the statusline; it expires after 8h idle. One
session per node: `take` refuses a node another session holds.

## Conventions and gotchas

- A routine's `run` executes as one `bash -eo pipefail` script (fail-fast; `pipefail` so a `cmd | grep` routine still reports the real exit code, which `wait` depends on) in the remote
  workspace dir; it survives SSH disconnects. `run:` may also be a YAML list of
  strings (joined by newlines).
- Injected env per node: `TF_NODE`, `TF_ROUTINE`, `TF_NODE_INDEX`, `TF_NODE_COUNT`
  — use index/count for data-parallel sharding.
- A routine already running on a node refuses to redispatch (exit 3, "already
  running"); `kill` it first. `run` on N nodes dispatches to all of them.
- Sync is delete-free `rsync` both ways; globs support `**`. Push expands globs
  locally, pull expands them on the node. Only files are synced, never deleted.
- Remote layout: `~/.tailfleet/work/<workspace>/` mirrors pushed files; run state
  in `.tf/` inside it (`<routine>.sh/.pid/.start/.exit/.log`). Liveness is by
  process group (`pgrep -g`), not launcher PID.
- `ps` state `stale` = process group died without writing an exit marker.
- Commands are non-login `bash -s` over SSH; interactive-only PATH entries from a
  node's `.bashrc` are absent. Use absolute paths or set PATH inside `run:`.
- Nodes must be online in `tailscale status` to be targeted; offline/unknown
  names are a hard error.
- **Sync never deletes, so a remote workspace drifts.** The remote tree is the union of every push
  ever made: files deleted from the repo, or no longer matching a glob, stay on the node and can
  fail a run in ways that do not reproduce locally (pytest collecting deleted test files is the
  classic). **When remote failures do not reproduce locally, suspect the remote tree before the
  code**, and run `tailfleet sync --prune`. On this fleet that took a run from 39 failures to 2.
- `--prune` is scoped to the push globs, so a routine's remote `.venv` and outputs are safe, and it
  skips globs with no local match so gitignored datasets are not deleted when you run from a
  checkout that lacks them. It is still destructive: prefer `sync --prune` where you can read the
  output over `run --prune`.

## Source

`~/tools/orion/tailfleet/` — uv package: `cli.py` (argparse subcommands), `monitor.py`
(Textual app), `render.py`, `nodes.py` (discovery/SSH), `probes.py`, `parse.py`,
`config.py` (yaml load/validate), `jobs.py` (sync/dispatch/ps/logs/wait/kill).
