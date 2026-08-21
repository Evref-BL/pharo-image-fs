# Agent Guide For Projects Using pharo-image-fs

Use the mounted `pharo-image-fs` projection as the normal Pharo code editing
surface.

## Workflow

- Read and search code under `/tonel` with normal filesystem tools such as
  `rg`, `find`, `sed`, and editors.
- Edit only Tonel code files under `/tonel/<package>/`.
- Treat successful writes as applied to the live Pharo image and exported back
  to source by Pharo.
- If a write fails, inspect `/errors/latest.txt`.
- Inspect Pharo critique feedback under `/critiques`.

## Boundaries

- `/tonel` is the only edit surface.
- `/critiques` is read-only and contains only actual Pharo critiques.
- `/errors` is read-only operational feedback for failed projection writes.
- Use MCP tools, when available, for semantic operations such as refactorings,
  running tests, running broad critique checks, and repository operations.

Do not manually reconcile image state and Tonel state after edits through the
mount; the projection write is transactional and Pharo owns that synchronization.
