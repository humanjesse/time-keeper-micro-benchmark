# Time-Keeper Benchmark Documentation

Documentation for the Agentic Loop Sustainability Micro-Benchmark.

## Quick Links

- [Main README](../README.md) - Overview, methodology, and quick start
- [CHANGELOG](../CHANGELOG.md) - Version history

## User Guide

- [Installation](user-guide/installation.md) - Building from source
- [Configuration](user-guide/configuration.md) - Provider and model setup
- [Commands](user-guide/commands.md) - CLI and keyboard reference

## Architecture

- [Overview](architecture/overview.md) - How the benchmark harness works
- [Tool Calling](architecture/tool-calling.md) - Timer and memory tools

## Benchmark Tools

| Tool | Purpose |
|------|---------|
| `set_timer` | Schedule notification after N milliseconds |
| `current_time` | Get current timestamp |
| `kv_set` / `kv_get` | Store/retrieve benchmark data |
| `scratchpad_*` | Working memory (optional) |

## Project Structure

```
time-keeper/
├── main.zig           # Entry point
├── app.zig            # Core loop + system prompt (line 349)
├── tools.zig          # Tool definitions
├── tools/             # Tool implementations
│   ├── set_timer.zig
│   ├── current_time.zig
│   └── kv_*.zig
├── ollama.zig         # Ollama API client
├── lmstudio.zig       # LM Studio client
└── docs/              # This documentation
```
