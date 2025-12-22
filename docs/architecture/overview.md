# Architecture Overview

Time-Keeper is an agentic loop sustainability benchmark harness written in Zig.

## Design Principles

1. **Benchmark Focus**: Tests sustained tool-calling behavior
2. **Non-blocking**: UI remains responsive during long benchmarks
3. **Observable**: Clear visibility into agent behavior
4. **Configurable**: Easy to test different models

## System Architecture

```
┌─────────────────────────────────────────┐
│           Terminal UI (ui.zig)          │
└──────────────────┬──────────────────────┘
                   │
┌──────────────────▼──────────────────────┐
│           App Core (app.zig)            │
│  • Master loop (max 10 iterations)      │
│  • System prompt injection              │
│  • Timer event handling                 │
└────────┬─────────────────┬──────────────┘
         │                 │
    ┌────▼────┐       ┌────▼────┐
    │ Ollama  │       │  Tools  │
    │ Client  │       │ System  │
    └────┬────┘       └────┬────┘
         │                 │
         ▼                 ▼
    ┌─────────┐   ┌────────────────┐
    │ Ollama  │   │ set_timer      │
    │ Server  │   │ current_time   │
    │(external)│  │ kv_set/kv_get  │
    └─────────┘   └────────────────┘
```

## Benchmark System Prompt

The core benchmark is defined in `app.zig:349-355`:

```
You are a time keeper agent. Repeat this cycle forever:
1) set_timer for 30 seconds
2) When timer fires: get_current_time, then kv_set to store it
3) Repeat steps one and two to continue the loop
```

This prompt tests whether models can sustain tool-calling loops indefinitely.

## Master Loop (Core Benchmark Mechanism)

The master loop enables agentic iteration:

```
1. System prompt sent with tools
2. Loop (max 10 iterations):
   a. Call Ollama API with history + tools
   b. Collect response (content + tool_calls)
   c. Add to history
   d. If no tool_calls → break (failure: loop abandoned)
   e. Execute tools → Add results → Continue
3. Timer fires → Inject notification → Continue loop
```

**What the benchmark measures:**
- Does the model call `set_timer` correctly?
- Does it respond to timer notifications with tool calls?
- Does it continue indefinitely or abandon the loop?

## Tool Executor State Machine

```zig
pub const ToolExecutionState = enum {
    idle,              // Waiting
    evaluating_policy, // Checking permissions
    awaiting_permission, // User prompt shown
    executing,         // Running tool
    completed,         // Ready for next iteration
};
```

Non-blocking tick() returns actions: `show_permission_prompt`, `render_requested`, `iteration_complete`.

## Timer Implementation

When `set_timer` executes:
1. System schedules real wall-clock timer
2. After duration, timer notification injected into conversation
3. Master loop auto-continues, prompting agent for response
4. Agent should call `current_time` then `kv_set` then `set_timer`

## Threading Model

**Main Thread:**
- UI rendering
- Input handling
- Timer event processing
- Tool execution

**Streaming Thread:**
- Ollama API communication
- Response chunk parsing
- Thread-safe queue to main thread

## Key Files

| File | Purpose |
|------|---------|
| `app.zig` | Core loop, system prompt (line 349) |
| `tools.zig` | Tool definitions |
| `tools/set_timer.zig` | Timer implementation |
| `tools/current_time.zig` | Timestamp tool |
| `tools/kv_*.zig` | Key-value storage |
| `tool_executor.zig` | Async execution state machine |
| `ollama.zig` | Ollama API client |

## Configuration

- Config: `~/.config/time-keeper/config.json`
- Policies: `~/.config/time-keeper/policies.json`

## See Also

- [Tool Calling](tool-calling.md) - Timer and memory tools
