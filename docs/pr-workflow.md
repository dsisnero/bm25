# PR Workflow

## Before Submitting

1. `make check` passes (format + lint + all specs)
2. Commit messages follow `<type>: <summary>` format
3. Parity inventory updated in `plans/inventory/` if applicable

## Review Criteria

- Behavior parity with upstream Rust crate is preserved
- No unnecessary shard dependencies
- All quality gates pass (`make check`)
- New code has corresponding specs
- Any intentional drift from upstream is documented in `plans/inventory/`

## Merge

Squash-merge into `main`. Update `CHANGELOG.md` after merge.
