# Testing

## Main Commands

Run all specs:

```bash
crystal spec
```

Run the standard project gate:

```bash
make check
```

Run individual checks:

```bash
crystal tool format --check src spec
ameba src spec
crystal spec
```

The benchmark file is not part of `make check`; type-check it explicitly:

```bash
crystal build benchmarks/search.cr --no-codegen
```

## Spec Layout

| Path | Purpose |
|---|---|
| `spec/bm25_spec.cr` | Embedder, scorer, search engine, builders, custom tokenizer/embedder behavior, and upstream embedder/search snapshots. |
| `spec/default_tokenizer_spec.cr` | Default tokenizer behavior, tokenizer builder flags, English/German snapshots, and Detect parity. |
| `spec/recipe_loader_spec.cr` | Port of upstream `src/test_data_loader.rs` tests. |
| `spec/support/recipe_loader.cr` | Shared spec helper for reading upstream recipe CSV fixtures. |
| `spec/spec_helper.cr` | Crystal spec bootstrap and `src/bm25` require. |

## Upstream Fixtures

Specs intentionally read upstream data from the checked-out Rust submodule:

- `vendor/bm25/data/recipes_en.csv`
- `vendor/bm25/data/recipes_de.csv`
- `vendor/bm25/snapshots/*.snap`

Do not copy these fixtures into `spec/` unless there is a specific reason. Keeping reads pointed at `vendor/bm25` makes parity drift easier to detect.

## Snapshot Strategy

The Crystal specs parse upstream `insta` snapshot files and compare:

- token arrays from `DefaultTokenizer`
- sparse embeddings from `Embedder`
- ordered search results from `SearchEngine`

Floating point comparisons use a small tolerance because Crystal and Rust formatting/rounding can differ even when the underlying behavior is equivalent.

## Parity Inventory Checks

Run these when touching ported behavior or inventory:

```bash
PORT_SOURCE_DIR=vendor/bm25 PORT_LANGUAGE=rust scripts/check_source_parity.sh .
PORT_SOURCE_DIR=vendor/bm25 PORT_LANGUAGE=rust scripts/check_test_parity.sh .
PORT_SOURCE_DIR=vendor/bm25 PORT_LANGUAGE=rust scripts/check_port_inventory.sh .
```

The source parity file tracks discovered upstream API/source items. The test parity file tracks upstream Rust tests. The port inventory aggregates both.

## Adding Or Changing Tests

1. Find the upstream test or behavior in `vendor/bm25`.
2. Prefer a Crystal spec with the same behavior and similar name.
3. Use upstream CSV/snapshot fixtures when upstream does.
4. Add focused regression specs for Crystal-specific edge cases only when they protect parity behavior.
5. Update `plans/inventory/rust_test_parity.tsv`.
6. Run specs and parity checks.

## Expected Current Coverage

The current suite covers:

- tokenizer flags and edge cases
- English and German tokenizer snapshots
- Detect mode for English and German recipe datasets
- embedder BM25 weighting and snapshot output
- scorer IDF/matching behavior
- search engine CRUD and snapshot output
- custom tokenizer and custom token embedder extension points
- upstream recipe loader helper behavior
- `NoDefaultTokenizer` sentinel behavior
