---
description: Show, change, or drop this session's tailfleet node lease (/lease, /lease <node>, /lease release)
allowed-tools: Bash(uv run --project /home/venki/tools/orion/tailfleet tailfleet lease take:*)
---

!`uv run --project /home/venki/tools/orion/tailfleet tailfleet lease take $ARGUMENTS`

The tailfleet lease state above is authoritative. Use the node leased to this project for any tailfleet routine. Do not run any lease command yourself.
