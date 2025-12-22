# Commands Reference

Quick reference for Time-Keeper commands.

## Slash Commands

| Command | Description |
|---------|-------------|
| `/quit` | Exit application |
| `/config` | Open visual configuration editor |
| `/help` | Show help viewer |
| `/toggle-toolcall-json` | Toggle raw tool JSON display |

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Enter` | Send message |
| `Ctrl+C` | Cancel AI response |
| `Ctrl+D` | Exit |
| `Escape` | Clear input |
| `↑` / `↓` | Scroll messages |
| `Ctrl+O` | Toggle thinking block |
| Mouse Wheel | Scroll |

## CLI Arguments

```bash
./time-keeper --model qwen3:30b --ollama-host http://localhost:11434
```

| Flag | Description |
|------|-------------|
| `--model` | Override model name |
| `--ollama-host` | Override Ollama server URL |
| `--help` | Show help |

## Tool Permissions

When prompted for tool permission:

| Key | Action |
|-----|--------|
| `a` | Allow once |
| `A` | Allow always (persists) |
| `d` | Deny once |
| `D` | Deny always (persists) |

Policies saved in `~/.config/time-keeper/policies.json`.
