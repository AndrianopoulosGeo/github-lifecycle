## Project Context & Reference Guide

### Configuration
- All lifecycle commands read from `.env.claude` at the repo root
- Tech stack: `{{TECH_STACK}}` | Deploy target: `{{DEPLOY_TARGET}}`
- GitHub: `https://github.com/{{GITHUB_ORG}}/{{GITHUB_REPO}}`

### Project Documentation (docs/)
The `/docs folder` is the single source of truth for developer knowledge. **Always check relevant sections before implementing.**

| Section | File | When to check |
|---------|------|--------------|
| Architecture | `docs/architecture.md` | Before adding components, changing data flow, or making structural decisions |
| API Reference | `docs/api-reference.md` | Before adding/modifying API endpoints |
| Data Model | `docs/data-model.md` | Before changing database schema, adding entities, or modifying relationships |
| Services | `docs/services.md` | Before adding background jobs, integrations, or external service calls |
| Testing | `docs/testing.md` | Before writing tests — follow documented patterns, runners, and conventions |
| Deployment | `docs/deployment.md` | Before changing CI/CD, Docker, or deployment configuration |
| Configuration | `docs/configuration.md` | Before adding environment variables or config files |
| Conventions | `docs/conventions.md` | Before writing any code — follow naming, style, and commit conventions |

### Where to Look Up Context

| Need | Where to look |
|------|--------------|
| **Data models & relationships** | `docs/data-model.md` — ER diagrams, entity definitions, migration patterns |
| **Architecture & patterns** | `docs/architecture.md` — layer diagrams, component hierarchy, data flow |
| **API contracts** | `docs/api-reference.md` — endpoints, request/response schemas, auth |
| **Best practices** | `docs/conventions.md` — coding standards, naming rules, git workflow |
| **How to test** | `docs/testing.md` — test structure, mocking patterns, E2E setup |
| **How to deploy** | `docs/deployment.md` — pipeline stages, environment config, rollback |
| **Project decisions** | `docs/decisions/` — Architecture Decision Records (if they exist) |

### Required Plugins & MCP Servers
- **context7** MCP server — always use `resolve-library-id` + `query-docs` to fetch up-to-date library documentation before implementing with any framework or library. Never rely on training data for API signatures.

### Rules
- When implementing features, ALWAYS check the relevant docs section first
- When making architectural decisions, update `docs/architecture.md`
- After adding API endpoints, update `docs/api-reference.md`
- After changing database schema, update `docs/data-model.md`
- After modifying tests, update `docs/testing.md`
- After adding environment variables, update `docs/configuration.md`
- Keep docs sections in sync — run `/wiki review` to check accuracy
