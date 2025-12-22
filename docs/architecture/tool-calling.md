# Tool Calling System

Time-Keeper implements an OpenAI-compatible tool calling system for the benchmark loop.

## Benchmark Tools

### `set_timer`
- **Description:** Schedule a notification after N milliseconds
- **Permission:** Auto-approved
- **Parameters:**
  - `label` (string): Timer identifier
  - `duration` (integer): Milliseconds until notification
- **Returns:** Confirmation message
- **Behavior:** When timer fires, system injects `[TIMER FIRED: {label}] Your timer has expired.`

### `current_time`
- **Description:** Get current date and time
- **Permission:** Auto-approved
- **Returns:** ISO 8601 formatted timestamp
- **Use:** Called after timer fires to get timestamp

### `kv_set`
- **Description:** Store a key-value pair
- **Permission:** Auto-approved
- **Parameters:**
  - `key` (string): Storage key
  - `value` (string): Value to store
- **Returns:** Confirmation message
- **Use:** Store timestamps for benchmark tracking

### `kv_get`
- **Description:** Retrieve a stored value
- **Permission:** Auto-approved
- **Parameters:**
  - `key` (string): Storage key
- **Returns:** Stored value or error if not found

## Memory Tools (Optional)

### `scratchpad_write/read/append/clear`
Working memory for temporary notes.

### `vector_add/search/delete`
Semantic memory with embedding storage.

## Structured Results

All tools return JSON with consistent structure:

```json
{
  "success": true,
  "data": "result data",
  "error_type": "none",
  "metadata": {
    "execution_time_ms": 3,
    "timestamp": 1705680000000
  }
}
```

**Error types:** `none`, `not_found`, `validation_failed`, `io_error`, `internal_error`

## Tool Executor State Machine

Tool execution uses an async state machine:

```
idle → evaluating_policy → awaiting_permission → executing → completed
                               (if needed)
```

**States:**
- `idle` - No pending work
- `evaluating_policy` - Checking permissions
- `awaiting_permission` - User prompt shown
- `executing` - Tool running
- `completed` - Ready for next iteration

The `tick()` method returns actions: `show_permission_prompt`, `render_requested`, `iteration_complete`.

## Multi-Turn Flow

```
1. Model requests tool_calls
2. Tool executor runs each tool
3. Results added to conversation history
4. Auto-continuation triggers next response
5. Model processes results
```

## Tool Call Limits

- **Per iteration:** Max 15 tool calls
- **Per message:** Max 10 iterations

## Ollama API Format

Tools sent in OpenAI-compatible format:

```json
{
  "model": "qwen3:30b",
  "messages": [...],
  "stream": true,
  "tools": [
    {
      "type": "function",
      "function": {
        "name": "set_timer",
        "description": "Schedule notification",
        "parameters": {
          "type": "object",
          "properties": {
            "label": {"type": "string"},
            "duration": {"type": "integer"}
          },
          "required": ["label", "duration"]
        }
      }
    }
  ]
}
```

## Model Compatibility

Tool calling works with:
- Llama 3.1+
- Qwen 2.5+
- Mistral models with function calling
- Any model supporting OpenAI tool format
