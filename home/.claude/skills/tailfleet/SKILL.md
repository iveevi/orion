---
name: tailfleet
description: Inspect hardware and run programs across the user's Tailscale network (linux nodes, e.g. verso/icaria/renoir/sauron). Use when the user wants to see CPU/GPU/memory/load across their tailnet machines, dispatch/monitor a job routine on remote nodes, sync files to/from nodes, stream job logs, or check what is currently running on the fleet.
---

# tailfleet

A CLI that discovers linux nodes on the user's Tailscale network (`tailscale status`)
and over SSH (passwordless) monitors hardware and dispatches job routines defined in
a per-project `tailfleet.yaml`.

## Invocation

The `tailfleet` shell alias only exists in the user's interactive zsh. From the
bash tool, always invoke:

```
uv run --project ~/tools/tailfleet tailfleet <subcommand> [args]
```

Use `--project` (not `--directory`): job subcommands find `tailfleet.yaml` by
searching upward from the **current directory**, so cwd must stay in the user's
project.

## Subcommands

| command | purpose |
|---|---|
| `status` (default) | one-shot `nvidia-smi`-style fleet table (Node / CPU / Memory / GPU, with CPU+GPU temps, util bar gauges, VRAM). Non-interactive — **safe to run from the bash tool** to read hardware. Flag: `--timeout`. |
| `monitor` | the same table, live-refreshing at the top of the screen. `-`/`+` adjust the refresh rate (shown as `⟳ Ns`), `q` quits. Interactive only — do not run from the bash tool; tell the user to run `tailfleet monitor` themselves. |
| `run <routine>` | push files, then dispatch the routine on its nodes (detached via `setsid`) |
| `ps` | routine × node table: running / exit code / duration |
| `logs <routine>[@<node>] [-f] [-n N]` | tail a routine's log; `@node` required if the routine has multiple nodes |
| `kill <routine>` | TERM the routine's process group on its nodes |
| `sync` | push the `push:` globs to all routine nodes, no dispatch |
| `pull` | fetch the `pull:` globs from all routine nodes back into the project |

## tailfleet.yaml

Lives at the project root (found from cwd upward):

```yaml
workspace: myproj             # remote dir name; defaults to local dir basename
push: [src/**/*.py, pyproject.toml, uv.lock]   # host → nodes
pull: [out/**, logs/*.log]                     # nodes → host

routines:
  train:
    nodes: [verso, icaria]    # or ["*"] = every online linux node
    run: |
      uv sync --frozen
      uv run python train.py --shard $TF_NODE_INDEX/$TF_NODE_COUNT
```

## Conventions and gotchas

- A routine's `run` executes as one `bash -e` script (fail-fast) in the remote
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

## Source

`~/tools/tailfleet/` — uv package: `cli.py` (argparse subcommands), `monitor.py`
(Textual app), `render.py`, `nodes.py` (discovery/SSH), `probes.py`, `parse.py`,
`config.py` (yaml load/validate), `jobs.py` (sync/dispatch/ps/logs/kill).
