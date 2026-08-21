# Agent Guide For pharo-image-fs

`pharo-image-fs` is the Pharo image-side backend for projecting a live image as
a filesystem.

The Go mount daemon lives in
[`pharo-image-fs-daemon`](https://github.com/Evref-BL/pharo-image-fs-daemon).

## Rules

- Preserve unrelated local changes.
- Put Pharo packages under `src/`.
- Keep Pharo authoritative for source projection, parsing, compilation,
  transactional writes, Tonel export/sync, and critique feedback.
- Do not implement FUSE or daemon filesystem callbacks in this repository.
- Keep ordinary code editing exposed through the mounted filesystem model.
- Do not add fallback edit tools such as `resource_write`, `resource_search`, or
  `resource_patch`.
- Prefer one narrow daemon-to-Pharo projection protocol over multiple parallel
  APIs.
- When possible, validate Pharo behavior in a disposable live image before
  claiming runtime behavior.
