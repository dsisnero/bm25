# Development

## Setup

Clone with the upstream Rust submodule:

```bash
git clone --recurse-submodules git@github.com:dsisnero/bm25.git
cd bm25
shards install
```

If the repository is already cloned:

```bash
git submodule update --init --recursive
shards install
```

## Source Of Truth

The upstream Rust crate lives in `vendor/bm25`. Treat it as the behavioral source of truth for API shape, edge cases, fixtures, and snapshots.

Important upstream paths:

- `vendor/bm25/src/*.rs`: Rust implementation and unit tests
- `vendor/bm25/data/*.csv`: recipe datasets used by upstream tests and benchmarks
- `vendor/bm25/snapshots/*.snap`: upstream snapshot outputs
- `vendor/bm25/benches/*.rs`: upstream benchmark structure

Crystal code can be idiomatic where language mechanics differ, but observable behavior should stay aligned with the upstream tests unless drift is explicitly documented in `plans/inventory/`.

## Commands

Install dependencies:

```bash
shards install
```

Format check:

```bash
crystal tool format --check src spec
```

Lint:

```bash
ameba src spec
```

Specs:

```bash
crystal spec
```

Main gate:

```bash
make check
```

Benchmark type-check:

```bash
crystal build benchmarks/search.cr --no-codegen
```

Run the ported search benchmark:

```bash
crystal run benchmarks/search.cr
```

For local Crystal cache isolation, use:

```bash
CRYSTAL_CACHE_DIR=$PWD/.crystal-cache crystal spec
```

## Parity Checks

The repo includes reusable inventory checks:

```bash
PORT_SOURCE_DIR=vendor/bm25 PORT_LANGUAGE=rust scripts/check_source_parity.sh .
PORT_SOURCE_DIR=vendor/bm25 PORT_LANGUAGE=rust scripts/check_test_parity.sh .
PORT_SOURCE_DIR=vendor/bm25 PORT_LANGUAGE=rust scripts/check_port_inventory.sh .
```

Expected current state:

- source parity tracks all discovered Rust API/source items
- test parity tracks all discovered upstream Rust tests
- port inventory aggregates source and test items
- no `missing`, `skipped`, `pending`, or `in_progress` rows remain

## Porting Workflow

1. Locate the upstream source or test in `vendor/bm25`.
2. Add or update a Crystal spec that captures upstream behavior.
3. Implement the behavior in `src/bm25`.
4. Compare against upstream CSV fixtures or snapshots where available.
5. Update `plans/inventory/*.tsv`.
6. Run format, lint, specs, and the relevant parity checks.

## Current Crystal Patterns

- All runtime types are under `Bm25`.
- `Tokenizer` is an abstract class; custom tokenizers subclass it.
- `TokenEmbedder(D)` is a module included by structs or classes that produce embedding indices.
- Builders mutate internal state and return `self`.
- Builder factories require an explicit token embedder instance.
- `LanguageMode` is represented as a struct with either a fixed language or Detect mode.
- Rust feature-gated `NoDefaultTokenizer` is represented as a sentinel type.

## Branching

Use short-lived branches off `main`. Keep changes focused around one parity slice, bug fix, or documentation update.

Recommended commit types:

- `feat`: new ported behavior
- `fix`: behavior correction
- `test`: parity or regression coverage
- `docs`: documentation changes
- `refactor`: structure changes without behavior change
- `chore`: tooling or maintenance
