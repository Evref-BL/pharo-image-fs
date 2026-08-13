# Agent Guide For pharo-image-fs

`pharo-image-fs` contains two implementation surfaces:

- `go/`: the Go filesystem mount daemon;
- `pharo/`: the Pharo backend for live-image projection semantics.

## Rules

- Keep ordinary code editing exposed through the mounted filesystem model.
- Do not add fallback edit tools such as `resource_write`, `resource_search`, or
  `resource_patch`.
- Keep the Go daemon dumb about Pharo code. It handles mount lifecycle,
  filesystem callbacks, protocol transport, timeouts, and generic errors.
- Keep Pharo authoritative for source projection, parsing, compilation,
  transactional writes, Tonel export/sync, and critique feedback.
- Prefer one narrow daemon-to-Pharo projection protocol over multiple parallel
  APIs.

## Go

- Run Go commands from `go/`.
- Keep executable entry points under `go/cmd/`.
- Use `go/pkg/` for reusable daemon packages until there is a concrete need for
  Go's `internal/` visibility restriction.
- Run `go test ./...` before committing Go changes.

## Pharo

- Put Pharo packages under `pharo/src/`.
- Use the Pharo backend for image-side semantics only; do not implement FUSE in
  Pharo.
- When possible, validate Pharo behavior in a disposable live image before
  claiming runtime behavior.

