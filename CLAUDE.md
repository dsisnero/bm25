# bm25

Crystal port of the Rust `Michael-JB/bm25` BM25 search/ranking crate.

## Commands

```bash
# Install dependencies
shards install

# Format
crystal tool format --check src spec

# Lint
ameba src spec

# Test
crystal spec

# Run all gates (format + lint + test)
make check
```

## Documentation

| Document | Description |
|----------|-------------|
| [Architecture](docs/architecture.md) | Module structure and data flow |
| [Development](docs/development.md) | Dev setup, submodule, branching |
| [Coding Guidelines](docs/coding-guidelines.md) | Style, naming, conventions |
| [Testing](docs/testing.md) | Spec structure and parity testing |
| [PR Workflow](docs/pr-workflow.md) | PR lifecycle and review criteria |

## Principles

1. **Behavior parity** — Crystal port matches Rust upstream behavior exactly; no simplifications.
2. **Zero-warning gates** — All commits pass `crystal spec`, `ameba`, and `crystal tool format`.
3. **Documented drift** — Any intentional divergence from upstream is documented in the parity inventory under `plans/inventory/`.
4. **Test-first porting** — Upstream tests are ported alongside code; behavior verified before refactoring.

## Commit Style

```
<type>: <short summary>

<optional body>
```

Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`. Reference upstream parity items where applicable.

## Conventions

- `Tokenizer` is an abstract class (not module) — `DefaultTokenizer < Tokenizer`.
- `Embedder(D,T)` requires explicit `TokenEmbedder(D)` instance — no unsafe defaults.
- Builder pattern is mutating (`self` return) not consuming (Crystal ownership model).
- All temp files go in `./temp/` (in `.gitignore`, excluded from lint/format).
