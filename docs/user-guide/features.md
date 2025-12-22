# Benchmark Features

Core features of the Time-Keeper agentic loop sustainability benchmark.

## The Agentic Loop

**What it tests:** Can an LLM agent reliably execute tool calls in a loop indefinitely?

**The benchmark loop:**
```
1. Agent calls set_timer(duration=30000)
2. [30 seconds pass]
3. Timer fires → system notification injected
4. Agent calls current_time()
5. Agent calls kv_set() to store timestamp
6. Agent calls set_timer() again
7. [Repeat forever]
```

**Success criteria:**
- 50+ cycles without failure
- No hallucinated tool calls (text instead of actual tool_calls)
- No loop abandonment
- Timing drift < 10%

**Failure modes detected:**

| Failure | Description |
|---------|-------------|
| Hallucination | Model generates text claiming to call tools, but `finish_reason: "stop"` instead of `"tool_calls"` |
| Abandonment | Model stops looping despite instructions |
| Drift | Model loses track of timing intervals |

## Benchmark Tools

### Core Tools

| Tool | Purpose |
|------|---------|
| `set_timer` | Schedule notification after N milliseconds |
| `current_time` | Get current timestamp |
| `kv_set` / `kv_get` | Key-value storage for timestamps |

### Memory Tools (Optional)

| Tool | Purpose |
|------|---------|
| `scratchpad_write/read/clear` | Temporary working memory |
| `vector_add/search` | Semantic memory storage |

### Timer Behavior

When `set_timer` fires, the system injects a notification:
```
[TIMER FIRED: cycle_1] Your timer has expired.
```

The benchmark then auto-continues, prompting the agent for its next action.

## Master Loop Architecture

The benchmark harness supports multi-step tool execution:

- **Max 10 iterations** per user message
- **Max 15 tool calls** per iteration
- **Auto-continuation** after tool results
- **Timer event injection** for async notifications

This enables indefinite looping when the agent correctly chains tool calls.

## Permission System

Tools have risk levels:

| Level | Tools | Approval |
|-------|-------|----------|
| Safe | `current_time`, `kv_*`, `scratchpad_*` | Auto-approved |
| Medium | `set_timer`, `vector_*` | Configurable |

Policies persist in `~/.config/time-keeper/policies.json`.

## Running a Benchmark

1. Start with target model: `./time-keeper --model qwen3:30b`
2. The system prompt automatically instructs the loop behavior
3. Observe: Does the agent call tools or generate text?
4. Count successful cycles before failure
5. Note failure mode if applicable

## Structured Tool Results

All tools return structured JSON:
```json
{
  "success": true,
  "data": "...",
  "error_type": "none",
  "metadata": {
    "execution_time_ms": 3,
    "timestamp": 1705680000000
  }
}
```

This enables the agent to detect and handle errors programmatically.

## Platform Support

- **Linux** x86_64 (tested)
- **macOS** (should work)
- **Windows** not supported
