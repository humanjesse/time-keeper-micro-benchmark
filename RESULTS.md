# Benchmark Results

Community-contributed benchmark results for Time-Keeper agentic loop sustainability testing.

## Results Table

| Model | Provider | Loops | Duration (s) | Avg/Loop (s) | Status |
|-------|----------|-------|--------------|--------------|--------|
| mistralai/ministral-3-14b-reasoning | LM Studio | 10 | 786 | ~79 | Sustained |
| openai/gpt-oss-20b | LM Studio | 3 | 196 | ~65 | Limited |

### Status Legend

- **Sustained** - Model maintained consistent looping behavior (10+ loops)
- **Limited** - Model completed fewer loops but remained functional
- **Failed** - Model exhibited failure modes (hallucination, loop abandonment)

## Key Findings

- The 14B reasoning model (ministral-3-14b-reasoning) sustained 10 loops reliably
- The 20B model (gpt-oss-20b) only managed 3 loops before stopping
- Parameter count does not predict loop sustainability

## Contributing Results

We welcome community benchmark contributions! Please include:

1. **Model name and version** (as shown in provider)
2. **Provider** (Ollama, LM Studio, etc.)
3. **Number of loops completed**
4. **Total benchmark duration**
5. **Failure mode** (if applicable)
6. **Hardware specs** (optional but helpful)

### Submitting Results

1. Run the benchmark: `zig build run`, then `/benchmark` + `start`
2. Let it run for desired duration/cycles
3. Exit benchmark mode with `/benchmark`
4. Find your results in `~/.config/time-keeper/benchmark_results_*.json`
5. Submit a PR adding your JSON to `results/` and updating this table

### JSON Format

```json
{
  "session_id": "20251222_143000",
  "model": "model-name",
  "benchmark_duration_seconds": 300.50,
  "metrics": {
    "set_timer_calls": 10,
    "kv_set_calls": 10,
    "get_current_time_calls": 10,
    "complete_loops": 10
  },
  "timestamps": {
    "session_start": 1734881400000,
    "session_end": 1734881700500
  }
}
```

## Raw Data

All benchmark JSON files are stored in the [`results/`](results/) directory for reproducibility.
