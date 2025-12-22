# Configuration

Time-Keeper configuration options.

## Config File

Location: `~/.config/time-keeper/config.json`

Created automatically on first run.

## Essential Settings

```json
{
  "provider": "ollama",
  "ollama_host": "http://localhost:11434",
  "model": "qwen3:30b",
  "num_ctx": 128000
}
```

## Provider Selection

### Ollama (Default)

```json
{
  "provider": "ollama",
  "ollama_host": "http://localhost:11434",
  "model": "qwen3:30b"
}
```

Setup:
```bash
ollama pull qwen3:30b
ollama serve
```

### LM Studio

```json
{
  "provider": "lmstudio",
  "lmstudio_host": "http://localhost:1234",
  "model": "qwen2.5-coder-7b"
}
```

Note: Context size must be set in LM Studio UI.

## All Options

| Option | Default | Description |
|--------|---------|-------------|
| `provider` | `"ollama"` | `"ollama"` or `"lmstudio"` |
| `model` | `"qwen3:30b"` | Model name |
| `ollama_host` | `"http://localhost:11434"` | Ollama server URL |
| `lmstudio_host` | `"http://localhost:1234"` | LM Studio server URL |
| `num_ctx` | `128000` | Context window size |
| `num_predict` | `8192` | Max tokens to generate |
| `model_keep_alive` | `"15m"` | Keep model loaded (Ollama) |
| `enable_thinking` | `true` | Show thinking blocks |

## CLI Overrides

```bash
./time-keeper --model llama3.2:70b --ollama-host http://localhost:11434
```

CLI arguments override config file settings.

## Permission Policies

Stored in: `~/.config/time-keeper/policies.json`

When approving tool permissions with "Remember", policies persist here.

## Interactive Editor

Type `/config` to open visual editor. Navigate with Tab, save with Ctrl+S.

## Troubleshooting

**Ollama not connecting:**
```bash
curl http://localhost:11434/api/tags  # Verify Ollama running
```

**Model not found:**
```bash
ollama list   # See available models
ollama pull qwen3:30b  # Pull model
```
