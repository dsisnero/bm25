# Testing

## Running Tests

```bash
crystal spec
```

## Spec Structure

- `spec/bm25_spec.cr` — core module specs (embedder, scorer, search engine)
- `spec/*_spec.cr` — module-specific specs (e.g. `default_tokenizer_spec.cr`)
- Crystal auto-discovers all `*_spec.cr` files in `spec/`

## Parity Testing

Upstream Rust tests live at `vendor/bm25/tests/` and `vendor/bm25/src/*.rs` (inline `#[cfg(test)]` blocks).

When adding a ported module, verify:
1. Crystal spec passes
2. Equivalent Rust tests still pass (`cd vendor/bm25 && cargo test`)
3. `make check` passes (format + lint + spec)
