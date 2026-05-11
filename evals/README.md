# Eval Suite — github-lifecycle Plugin

## Eval Files

| File | Type | Commands Tested | Test Cases |
|------|------|----------------|------------|
| `trigger-evals.json` | Trigger accuracy | All 10 commands | 22 scenarios |
| `validate-env-evals.json` | Execution | `/validate-env` | 2 scenarios |
| `next-evals.json` | Execution | `/next` | 3 scenarios |
| `quick-fix-evals.json` | Execution | `/quick-fix` | 2 scenarios |
| `staging-release-evals.json` | Execution | `/staging`, `/release` | 3 scenarios |
| `hotfix-evals.json` | Execution | `/hotfix` | 2 scenarios |
| `commit-evals.json` | Execution | `/commit` | 6 scenarios |
| `init-project-evals.json` | Execution | `/init-project` | 2 scenarios |
| `decision-evals.json` | Execution | `/decision` | 3 scenarios |
| `compress-decisions-evals.json` | Execution | `/compress-decisions` | 2 scenarios |
| `quick-fix-adr-evals.json` | Execution | `/quick-fix` (ADR awareness) | 1 scenario |
| `hotfix-adr-evals.json` | Execution | `/hotfix` (ADR awareness) | 2 scenarios |
| `adr-bash-smoke-test.sh` | Bash smoke | ADR bash snippets | 14 assertions |

## Running Evals

### Trigger Evals (test command selection accuracy)

Use the skill-creator plugin:
```
/skill-creator run trigger evals for validate-env using evals/trigger-evals.json
```

### Execution Evals (test command behavior)

Use the skill-creator plugin:
```
/skill-creator run evals for validate-env using evals/validate-env-evals.json
```

### Bash Smoke Tests (test ADR bash snippets)

```bash
bash evals/adr-bash-smoke-test.sh
```

### Full Benchmark

Run all evals and aggregate:
```
/skill-creator benchmark all commands using evals/
```

## Metrics to Track

| Metric | Target | How to Measure |
|--------|--------|---------------|
| Trigger accuracy | >90% | Trigger evals — correct command invoked |
| State management | 100% | Every command reads/writes .state.md |
| Config portability | 100% | All commands use .env.claude, not hardcoded |
| Commit hygiene | 100% | No AI attribution in any commit |
| Track completion | >80% | Full track runs without manual intervention |
| GitHub integration | >70% | `gh` CLI calls triggered and monitored correctly |

## ADR Path Convention

All ADR files live at `docs/decisions/` (relative to the consuming project root).
The compressed index is at `docs/decisions/INDEX.md`.

Example paths used in evals:
- `docs/decisions/0000-template.md`
- `docs/decisions/INDEX.md`
- `docs/decisions/0001-adopt-tailwind-v4.md`

## Eval Schedule

- After modifying any command: run its execution eval
- After modifying command descriptions: run trigger evals
- Weekly: full benchmark run to detect drift
