## Stack Profile: .NET

> Read inline when `TECH_STACK=dotnet`. If the project's `CLAUDE.md` documents
> different commands or paths, the project's `CLAUDE.md` takes precedence.

### Commands

- **Install:** `dotnet restore`
- **Build:** `dotnet build`
- **Tests:** `dotnet test`
- **Lint only (CI):** `dotnet format --verify-no-changes`

### Directory conventions

- `Controllers/` — API controllers
- `Models/` — domain models and DTOs
- `Services/` — business logic
- `Data/` — DbContext, migrations, repositories

### Test conventions

- Test projects named `<Project>.Tests`
- Unit tests with xUnit or NUnit (match the project's existing choice)
- Integration/E2E tests in a dedicated `<Project>.IntegrationTests` project

### Plan-header tech-stack line

`.NET, ASP.NET Core, Entity Framework, C#`
