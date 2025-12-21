---
title: "File Operations"
description: "Examples for atomic writes, conditional saves, backups, and common file helpers provided by zon.zig."
---

# File Operations

zon.zig includes convenience helpers for safely reading and writing files.

## Examples

### Atomic write

Use `doc.saveAsAtomic(path)` to write the document to a temporary file and atomically rename it into place (avoids partial writes):

```zig
try doc.saveAsAtomic("config.zon");
```

### Save with backup

Create a backup of the previous file before saving:

```zig
try doc.saveWithBackup(".bak");
```

### Save only if changed

Avoid touching files if contents are identical:

```zig
const written = try doc.saveIfChanged(); // returns true when a write occurred
```

### Read and write helpers

- `zon.readFile(allocator, path)` reads a file into an allocator-owned buffer.
- `zon.writeFileAtomic(allocator, path, data)` writes atomically (tmp + rename).
- `zon.copyFile(src, dst, overwrite)` copies with optional overwrite.
- `zon.moveFile(old, new, overwrite)` moves with optional overwrite.

### Parsing from files / tokenizing files

- `zon.parseFile(allocator, path)` parses a ZON file directly.
- `tokenizer.loadSourceFromFile(allocator, path)` loads raw source for tokenization.

---

These helpers are useful for configuration workflows where safe, atomic updates and backups are important.