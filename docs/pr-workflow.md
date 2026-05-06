# PR Workflow

## Before Submitting

Run the standard gates:

```bash
make check
```

For changes touching benchmarks or parity inventory, also run:

```bash
crystal build benchmarks/search.cr --no-codegen
PORT_SOURCE_DIR=vendor/bm25 PORT_LANGUAGE=rust scripts/check_source_parity.sh .
PORT_SOURCE_DIR=vendor/bm25 PORT_LANGUAGE=rust scripts/check_test_parity.sh .
PORT_SOURCE_DIR=vendor/bm25 PORT_LANGUAGE=rust scripts/check_port_inventory.sh .
```

## Review Criteria

- Behavior matches upstream Rust tests, fixtures, and snapshots.
- Any intentional drift is documented in `plans/inventory/`.
- Public API examples in `README.md` still compile conceptually against the current Crystal API.
- `docs/architecture.md` reflects new runtime patterns.
- `docs/testing.md` reflects new fixture or snapshot strategy.
- No unnecessary dependencies are added to `shard.yml`.
- Specs cover new behavior or changed edge cases.

## Commit Style

Use:

```text
<type>: <short summary>
```

Common types:

- `feat`: new ported behavior
- `fix`: behavior correction
- `test`: parity or regression coverage
- `docs`: documentation changes
- `refactor`: structure-only changes
- `chore`: tooling or maintenance

## Merge Expectations

Keep PRs focused. A good PR usually ports one upstream area, fixes one parity bug, or updates one documentation/tooling slice.

Before merge, the inventories should describe the final state of the branch, not the state before the work started.
