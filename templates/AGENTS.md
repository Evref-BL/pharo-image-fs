# Agent Guide For Projects Using pharo-image-fs

Use the mounted `pharo-image-fs` projection as the normal Pharo code editing
surface.

## Workflow

- Read and search code under `/tonel` with normal filesystem tools such as
  `rg`, `find`, `sed`, and editors.
- Edit only Tonel code files under `/tonel/<package>/`. In them, a method's
  body is enclosed in `[ ]`; only the class definition and the method
  categories use `{ }`.
- Treat successful writes as applied to the live Pharo image and exported back
  to source by Pharo.
- A write the image refuses fails, and the file keeps the image's version;
  your tool may say only that it could not write. Read `/errors/latest.txt`:
  it names the method and the line to fix.
- Rename or move a class with `mv` of its `.class.st` file, into another
  package too: the image renames or moves the class, and what refers to it
  follows. A copy of it written into another package is refused.
- Deleting a `.class.st` file removes the class from the image. Never delete
  one because the write of its copy failed: the class goes with it.
- On macOS, copy a file onto the mount with `cp -X`: the mount keeps no
  extended attributes.
- Inspect Pharo critique feedback under `/critiques`.
- Commit in `/repositories/<name>`, the Git checkout writes are exported to,
  not in your own project; `/repositories/<name>.repository.json` lists the
  packages it holds.

## Boundaries

- `/tonel` is the only edit surface.
- `/critiques` is read-only and contains only actual Pharo critiques.
- `/errors` is read-only operational feedback for failed projection writes.
- Use MCP tools, when available, for semantic operations such as refactorings,
  running tests, running broad critique checks, and repository operations.

Do not manually reconcile image state and Tonel state after edits through the
mount; the projection write is transactional and Pharo owns that synchronization.
