# Testing

## Running Tests

```bash
crystal spec
```

## Spec Structure

- `spec/bm25_spec.cr` — Core module specs: embedder, scorer, search engine, builder patterns
- `spec/default_tokenizer_spec.cr` — DefaultTokenizer specs (all builder flags, edge cases)
- Crystal auto-discovers all `*_spec.cr` files in `spec/`

No external test data files — all specs use inline fixtures.

## Parity Testing

Upstream Rust tests live at `vendor/bm25/src/*.rs` in `#[cfg(test)]` blocks.

When porting a new module or adding parity coverage:

1. Crystal spec passes (`crystal spec`)
2. `make check` passes (format + lint + spec)
3. Parity inventory updated in `plans/inventory/` if applicable
