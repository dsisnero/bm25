# Development

## Setup

1. Clone with submodule: `git clone --recurse-submodules git@github.com:dsisnero/bm25.git`
2. If already cloned: `git submodule update --init --recursive`
3. Install dependencies: `shards install`

## Source of Truth

Upstream Rust crate lives at `vendor/bm25` (commit `e7b0e73`). All Crystal code must match upstream behavior.

## Branching

- `main` — release-ready, all gates passing
- Feature branches off `main` prefixed by type: `feat/`, `fix/`, `refactor/`

## Parity Work

Porting inventory lives in `plans/inventory/`. When adding a new module:
1. Port the upstream tests first
2. Implement to match
3. Verify with `make check`
