# PR Workflow

## Before Submitting

1. `make check` passes (format + lint + all specs)
2. Upstream Rust tests still pass (`cd vendor/bm25 && cargo test`)
3. Commit messages follow `<type>: <summary>` format
4. Parity inventory updated in `plans/inventory/` if applicable

## Review Criteria

- Behavior parity with upstream is preserved
- No unnecessary external dependencies
- All quality gates pass
- New code has corresponding specs
- Any drift from upstream is documented

## Merge

Squash-merge into `main`. Update `CHANGELOG.md` after merge.
