# Project tooling

## Python environment
- Package management: `uv` (`uv add`, `uv run`)
- Never: `pip install`, `uv pip install`, `uv pip` — always `uv add` for deps
- Virtualenv: `uv venv .venv` (create if missing), `uv sync` to install deps
- Run scripts: `uv run python script.py`
