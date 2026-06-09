# Project tooling

## Python environment
- Package management: `uv` (`uv add`, `uv run`, never `pip install` directly)
- Virtualenv: `uv venv .venv` (create if missing), `uv sync` to install deps
- Run scripts: `uv run python script.py`
