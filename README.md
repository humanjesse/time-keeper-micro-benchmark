# Time-Keeper

**Agentic Loop Sustainability Micro-Benchmark** - A focused benchmark for testing LLM agents' ability to maintain reliable tool-calling loops over extended periods.

## Overview

Time-Keeper tests a single, critical capability: **can an agent reliably loop forever?**

The benchmark asks agents to set timers, wait for them to fire, log the time, and repeat. Simple in concept, but this test has revealed surprising differences in model capabilities—parameter count doesn't predict loop reliability.

**Key findings so far:**
- Some smaller models (14B params) sustain loops better than larger ones (20B+)
- A failure mode where models "know what to do" but generate text instead of tool calls
- Distinguishes between understanding vs. reliable execution over time

## Quick Start

### Prerequisites

- **Zig** (0.15.2 or later)
- **LLM Provider**: Either **Ollama** or **LM Studio** running locally
- Any ANSI-compatible terminal

### Installation

```bash
# Using Ollama
ollama pull qwen3:30b
ollama serve

# Build and run
zig build
./zig-out/bin/time-keeper
```

## What It Tests

Time-Keeper measures **agentic loop sustainability**—the ability to:

1. Execute tool calls reliably (not just generate text about them)
2. Respond to asynchronous timer notifications
3. Maintain coherent behavior over hundreds/thousands of cycles
4. Continue looping indefinitely without degradation

### The Core Loop

```
Agent: set_timer(label="cycle_1", duration=30000)
[30 seconds pass]
[TIMER FIRED: cycle_1] Your timer has expired.
Agent: current_time() -> logs the time
Agent: set_timer(label="cycle_2", duration=30000)
[repeat forever]
```

### Failure Modes Detected

| Failure Type | Description |
|--------------|-------------|
| **Hallucination without action** | Model generates text claiming to call tools, but returns `finish_reason: "stop"` instead of `"tool_calls"` |
| **Loop abandonment** | Model stops after N iterations despite instructions to continue |
| **Timing drift** | Model loses track of intended intervals |

## Architecture

Time-Keeper provides:

- **Sliding context window** - Configurable token budget with automatic pruning
- **Real-time timers** - `set_timer` tool with true wall-clock delays
- **Event-driven notifications** - System messages when timers fire
- **Memory tools** - Scratchpad, key-value store, vector database (optional)

### Available Tools

| Tool | Purpose |
|------|---------|
| `set_timer` | Schedule a notification after N milliseconds |
| `current_time` | Get the current timestamp |
| `kv_set/kv_get` | Key-value store for structured data |
| `scratchpad_*` | Temporary notes and working memory |
| `vector_*` | Semantic search over stored information |

## Configuration

Config: `~/.config/time-keeper/config.json`

```json
{
  "provider": "ollama",
  "ollama_host": "http://localhost:11434",
  "model": "qwen3:30b"
}
```

**CLI options:** `--model`, `--ollama-host`, `--help`

## Benchmarking Methodology

### Pass/Fail Criteria

A model **passes** if it sustains 50+ cycles without:
- Hallucinating tool calls (text output instead of actual tool_calls)
- Abandoning the loop
- Significant timing drift (>10% variance)

### Running a Benchmark

1. Start the benchmark with your target model
2. Let it run for the desired duration/cycles
3. Monitor for failure modes in the output
4. Record: cycles completed, failure type (if any), average loop time

### Contributing Results

We welcome community-contributed benchmark results. Please include:
- Model name and version
- Provider (Ollama, LM Studio, etc.)
- Number of cycles before failure (or "sustained N cycles")
- Failure mode if applicable
- Hardware specs (optional but helpful)

## Why This Matters

Most benchmarks test **single-shot reasoning** or **knowledge retrieval**. Time-Keeper tests something different: **sustained agentic execution**.

If you're building agents that need to:
- Run background tasks reliably
- Maintain long-running operations
- Execute scheduled workflows

...then this benchmark measures a capability you care about.

## Platform Support

Linux (tested on x86_64), macOS. Windows not supported.

## Documentation

See [docs/](docs/) for detailed documentation.

## License

MIT License

---

*Time-Keeper is a micro-benchmark for evaluating agentic loop sustainability in LLM agents.*
