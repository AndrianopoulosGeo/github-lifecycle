## Stack Profile: Next.js

> Read inline when `TECH_STACK=nextjs`. If the project's `CLAUDE.md` documents
> different commands or paths, the project's `CLAUDE.md` takes precedence.

### Commands

- **Install:** `npm install`
- **Build / typecheck / lint:** `npm run build && npm run lint && npx tsc --noEmit`
- **Unit + E2E tests:** `npm test && npm run test:e2e`
- **Lint only (CI):** `npm run lint`

### Directory conventions

- `src/app/` — routes and pages
- `src/components/sections/` — page section components
- `src/components/ui/` — UI primitives
- `src/components/layout/` — layout components
- `src/lib/` — utilities, constants, types
- `src/hooks/` — custom hooks

### Test conventions

- Unit tests: `src/__tests__/`, run with Vitest
- E2E tests: `e2e/`, run with Playwright
- Mocking patterns: `src/__tests__/setup.tsx`

### Plan-header tech-stack line

`Next.js, React, Tailwind CSS, TypeScript`
