## Stack Profile: Python

> Read inline when `TECH_STACK=python`. If the project's `CLAUDE.md` documents
> different commands or paths, the project's `CLAUDE.md` takes precedence.

### Commands

- **Install:** `pip install -r requirements.txt`
- **Unit tests:** `python -m pytest`
- **E2E tests:** `python -m pytest e2e/`
- **Lint only (CI):** `ruff check .`

### Directory conventions

- `src/` — application package(s)
- `src/<package>/` — module code grouped by feature

### Test conventions

- Tests in `tests/`, run with pytest
- Shared fixtures in `tests/conftest.py`
- E2E tests in `e2e/`

### Plan-header tech-stack line

`Python, FastAPI/Django/Flask, SQLAlchemy`
