<div align="center">

<img width="300" height="300" alt="logo" src="https://github.com/user-attachments/assets/adbba32a-b035-473a-a3a3-3a331dc963f5" />

# zon.zig

<a href="https://muhammad-fiaz.github.io/zon.zig/"><img src="https://img.shields.io/badge/docs-muhammad--fiaz.github.io-blue" alt="Documentation"></a>
<a href="https://ziglang.org/"><img src="https://img.shields.io/badge/Zig-0.15.0+-orange.svg?logo=zig" alt="Zig Version"></a>
<a href="https://github.com/muhammad-fiaz/zon.zig"><img src="https://img.shields.io/github/stars/muhammad-fiaz/zon.zig" alt="GitHub stars"></a>
<a href="https://github.com/muhammad-fiaz/zon.zig/issues"><img src="https://img.shields.io/github/issues/muhammad-fiaz/zon.zig" alt="GitHub issues"></a>
<a href="https://github.com/muhammad-fiaz/zon.zig/pulls"><img src="https://img.shields.io/github/issues-pr/muhammad-fiaz/zon.zig" alt="GitHub pull requests"></a>
<a href="https://github.com/muhammad-fiaz/zon.zig"><img src="https://img.shields.io/github/last-commit/muhammad-fiaz/zon.zig" alt="GitHub last commit"></a>
<a href="https://github.com/muhammad-fiaz/zon.zig"><img src="https://img.shields.io/github/license/muhammad-fiaz/zon.zig" alt="License"></a>
<a href="https://github.com/muhammad-fiaz/zon.zig/actions/workflows/ci.yml"><img src="https://github.com/muhammad-fiaz/zon.zig/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
<img src="https://img.shields.io/badge/platforms-linux%20%7C%20windows%20%7C%20macos-blue" alt="Supported Platforms">
<a href="https://github.com/muhammad-fiaz/zon.zig/actions/workflows/release.yml"><img src="https://github.com/muhammad-fiaz/zon.zig/actions/workflows/release.yml/badge.svg" alt="Release"></a>
<a href="https://github.com/muhammad-fiaz/zon.zig/releases/latest"><img src="https://img.shields.io/github/v/release/muhammad-fiaz/zon.zig?label=Latest%20Release&style=flat-square" alt="Latest Release"></a>
<a href="https://pay.muhammadfiaz.com"><img src="https://img.shields.io/badge/Sponsor-pay.muhammadfiaz.com-ff69b4?style=flat&logo=heart" alt="Sponsor"></a>
<a href="https://github.com/sponsors/muhammad-fiaz"><img src="https://img.shields.io/badge/Sponsor-💖-pink?style=social&logo=github" alt="GitHub Sponsors"></a>
<a href="https://github.com/muhammad-fiaz/zon.zig/releases"><img src="https://img.shields.io/github/downloads/muhammad-fiaz/zon.zig/total?label=Downloads&logo=github" alt="Downloads"></a>
<a href="https://hits.sh/muhammad-fiaz/zon.zig/"><img src="https://hits.sh/muhammad-fiaz/zon.zig.svg?label=Visitors&extraCount=0&color=green" alt="Repo Visitors"></a>

<p><em>A simple, direct Zig library for reading and writing ZON (Zig Object Notation) files.</em></p>

<b>📚 <a href="https://muhammad-fiaz.github.io/zon.zig/">Documentation</a> |
<a href="https://muhammad-fiaz.github.io/zon.zig/api/document">API Reference</a> |
<a href="https://muhammad-fiaz.github.io/zon.zig/guide/getting-started">Quick Start</a> |
<a href="https://muhammad-fiaz.github.io/zon.zig/guide/allocators">Allocators</a> |
<a href="CONTRIBUTING.md">Contributing</a></b>

</div>

---

A **document-based** ZON (Zig Object Notation) library for Zig, designed for configuration file editing, dynamic access, and data manipulation. Unlike [`std.zon`](https://codeberg.org/ziglang/zig/src/branch/master/lib/std/zon) which parses ZON into typed structures, zon.zig maintains an in-memory document tree that you can query, modify, and serialize.

**If you find `zon.zig` useful, please give it a star!**

---

<details>
<summary><strong>🔄 zon.zig vs std.zon</strong> (click to expand)</summary>

| Feature            | zon.zig                           | std.zon                          |
| ------------------ | --------------------------------- | -------------------------------- |
| **Approach**       | Document-based (DOM tree)         | Type-based (deserialization)     |
| **Best For**       | Config editing, dynamic access    | Type-safe parsing into structs   |
| **Modification**   | **Full read/write/edit/merge**    | Read-only (serialize separately) |
| **Path Access**    | **Dot notation (`"db.host"`)**    | Direct field access              |
| **Dependencies**   | Custom parser (No Ast dependency) | Uses `std.zig.Ast`, `Zoir`       |
| **Stability**      | Independent of compiler internals | Tied to Zig compiler API         |
| **Special Values** | **NaN, Inf, -Inf support**        | Limited in some Zig versions     |

**Use zon.zig when:**

- You need to edit and save configuration files programmatically.
- The structure isn't known at compile time or varies.
- You want advanced features like **Deep Merge**, **Find & Replace**, and **Deep Equality**.
- You need a lightweight parser that doesn't pull in `std.zig.Ast`.

**Use std.zon when:**

- You know the structure at compile time and want static type safety.
- You're using `@import` for compile-time ZON values.

</details>

---

<details>
<summary><strong>Features of zon.zig</strong> (click to expand)</summary>

| Feature | Description |
| :--- | :--- |
| [Simple API](guide/basic-usage) | Clean `open`, `get`, `set`, `delete`, `save` interface |
| [Path-Based Access](guide/nested-paths) | Use dot notation like `"dependencies.foo.path"` |
| [Auto-Create Objects](guide/nested-paths) | Missing intermediate paths are created automatically |
| [Type-Safe Getters](api/document) | `getString`, `getBool`, `getInt`, `getFloat`, `getNumber` |
| [No Panics](guide/error-handling) | Missing paths return `null`, type mismatches return `null` |
| [Custom Parser](api/module) | Does NOT depend on `std.zig.Ast` or compiler internals |
| [Pretty Print](guide/pretty-print) | Formatted output with configurable indentation |
| [Find & Replace](guide/find-replace) | Search and replace values throughout the document |
| [Array Operations](guide/arrays) | Get length, elements, append to arrays |
| [Merge & Clone](guide/merge-clone) | Shallow & Deep Merge, Combine documents, Deep copy |
| [Deep Equality](guide/merge-clone) | Deeply compare two ZON documents or values |
| [Multi-line Strings](guide/writing) | Full support for multi-line backslash syntax (`\\`) |
| [Special Floats](guide/reading) | Support for `inf`, `-inf`, and `nan` values |
| [Cross-Platform](guide/installation) | Windows, Linux, macOS (32-bit and 64-bit) |
| [Zero Dependencies](guide/installation) | Built entirely on the Zig standard library |
| [High Performance](guide/basic-usage) | Efficient parsing and serialization |
| [File Operations](guide/file-operations) | Delete, copy, rename, check existence |
| [Update Checker](api/module) | Optional automatic update checking |
| [Memory Flexibility](guide/allocators) | Full support for GPA, Arena, and custom allocators |
| [JSON Interop](api/module) | Import from and Export to standard JSON |
| [Object Iterators](guide/reading) | Programmatic iteration over key-value pairs |
| [Flatten & Expand](guide/nested-paths) | Convert nested ZON to flat dot-notation maps |
| [Integrity Suite](guide/file-operations) | Stable Hashing (Order-independent) & Checksums |
| [Recursive Search](guide/find-replace) | Find keys anywhere (`find`, `findAll`) |
| [File Key Utils](guide/file-operations) | Move/Copy keys directly in files without full parsing |
| [Runtime Structs](guide/runtime-structs) | Convert ZON documents to Zig structs (`toStruct`) |
| [Struct to ZON](guide/runtime-structs) | Create/Update Documents from Zig Structs (`initFromStruct`) |
| [Smart Stringify](guide/writing) | Intelligent key quoting (ZON-compliant unquoted keys) |
| [Diagnostic Errors](guide/error-handling) | High-quality syntax error reporting with line/column |

</details>

---

<details>
<summary><strong>Prerequisites & Supported Platforms</strong> (click to expand)</summary>

<br>

## Prerequisites

| Requirement          | Version                   | Notes                                                      |
| -------------------- | ------------------------- | ---------------------------------------------------------- |
| **Zig**              | 0.15.0+                   | Download from [ziglang.org](https://ziglang.org/download/) |
| **Operating System** | Windows 10+, Linux, macOS | Cross-platform support                                     |

---

## Supported Platforms

| Platform         | 32-bit | 64-bit    | ARM                        | Status       |
| ---------------- | ------ | --------- | -------------------------- | ------------ |
| **Windows**      | ✅ x86 | ✅ x86_64 | -                          | Full support |
| **Linux**        | ✅ x86 | ✅ x86_64 | ✅ aarch64                 | Full support |
| **macOS**        | ✅ x86 | ✅ x86_64 | ✅ aarch64 (Apple Silicon) | Full support |
| **Freestanding** | ✅ x86 | ✅ x86_64 | ✅ aarch64, arm, riscv64   | Full support |

</details>

---

## Installation

```bash
zig fetch --save https://github.com/muhammad-fiaz/zon.zig/archive/refs/tags/0.0.4.tar.gz
```

or

for Nightly Installation, use this

```bash
zig fetch --save git+https://github.com/muhammad-fiaz/zon.zig.git
```

Then in your `build.zig`:

```zig
const zon_dep = b.dependency("zon", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("zon", zon_dep.module("zon"));
```

---

## Quick Start

```zig
const std = @import("std");
const zon = @import("zon");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Optional: Disable update checking
    zon.disableUpdateCheck();

    // Create a new ZON document
    var doc = zon.create(allocator);
    defer doc.deinit();

    // Set values
    try doc.setString("name", "myapp");
    try doc.setBool("private", true);
    try doc.setInt("port", 8080);

    // Nested paths - auto-creates intermediate objects
    try doc.setString("dependencies.http.path", "../http");

    // Read values
    std.debug.print("Name: {s}\n", .{doc.getString("name").?});

    // Save to file
    try doc.saveAs("config.zon");
}
```

---

## Supported ZON Syntax

zon.zig fully supports the `build.zig.zon` format:

```zig
.{
    .name = .zon,                        // Identifier as value
    .version = "0.0.4",                  // String
    .fingerprint = 0xee480fa30d50cbf6,   // Multi-bit hex handled as i128
    .minimum_zig_version = "0.15.0",
    .paths = .{                          // Array of strings
        "build.zig",
        "build.zig.zon",
        "src",
        "examples",
        "README.md",
        "LICENSE",
    },
    .dependencies = .{                    // Nested objects
        .http = .{
            .url = "https://example.com",
            .hash = "abc123",
        },
    },
}
```

---

## Examples

### Parse build.zig.zon

```zig
const source =
    \\.{
    \\    .name = .my_package,
    \\    .version = "0.1.0",
    \\    .paths = .{
    \\        "build.zig",
    \\        "src",
    \\    },
    \\}
;

var doc = try zon.parse(allocator, source);
defer doc.deinit();

// Read identifier value
const name = doc.getString("name"); // "my_package"

// Read array
const paths_len = doc.arrayLen("paths"); // 2
const first_path = doc.getArrayString("paths", 0); // "build.zig"
```

### Find and Replace

```zig
var doc = zon.create(allocator);
defer doc.deinit();

try doc.setString("host1", "localhost");
try doc.setString("host2", "localhost");
try doc.setString("host3", "192.168.1.1");

// Find all paths containing "localhost"
const found = try doc.findString("localhost");
defer allocator.free(found);
// found.len == 2

// Replace all occurrences
const count = try doc.replaceAll("localhost", "production.example.com");
// count == 2

// Replace first occurrence only
const replaced = try doc.replaceFirst("old", "new");

// Replace last occurrence only
const replaced_last = try doc.replaceLast("old", "new");
```

### Array Operations

```zig
// Create array and append
try doc.setArray("items");
try doc.appendToArray("items", "first");
try doc.appendToArray("items", "second");
try doc.appendIntToArray("numbers", 42);

// Read array
const len = doc.arrayLen("items"); // 2
const elem = doc.getArrayString("items", 0); // "first"
```

### Pretty Print

```zig
// Default 4-space indentation
const output = try doc.toString();

// Custom indentation
const two_space = try doc.toPrettyString(2);

// Compact (no indentation)
const compact = try doc.toCompactString();
```

### Merge and Clone

```zig
var base = zon.create(allocator);
try base.setString("name", "app");
try base.setInt("port", 8080);

var override = zon.create(allocator);
try override.setInt("port", 9000);
try override.setBool("debug", true);

// Merge override into base
try base.merge(&override); // Shallow merge
try base.mergeRecursive(&override); // Deep merge (merges nested objects)
// base now has port=9000, debug=true

// Deep equality
if (base.eql(&override)) { ... }

// Deep clone
var copy = try base.clone();
defer copy.deinit();
```

---

## API Reference

### Module Functions

| Function                                      | Description                                |
| --------------------------------------------- | ------------------------------------------ |
| `zon.open(allocator, path)`                   | Open existing ZON file                     |
| `zon.create(allocator)`                       | Create new empty document                  |
| `zon.parse(allocator, source)`                | Parse ZON from string                      |
| `zon.readFile(allocator, path)`               | Read file into allocator-owned buffer      |
| `zon.writeFileAtomic(allocator, path, data)`  | Write data atomically (tmp + rename)       |
| `zon.copyFile(source, dest, overwrite: bool)` | Copy a file (with optional overwrite)      |
| `zon.moveFile(old, new, overwrite: bool)`     | Move/rename file (with optional overwrite) |
| `zon.deleteFile(path)`                        | Delete a ZON file                          |
| `zon.fileExists(path)`                        | Check if file exists                       |
| `zon.disableUpdateCheck()`                    | Disable update checking                    |

### Document Methods - Getters

| Method              | Description                 |
| ------------------- | --------------------------- |
| `getString(path)`   | Get string value or null    |
| `getBool(path)`     | Get bool value or null      |
| `getInt(path)`      | Get integer value or null   |
| `getUint(path)`     | Get u64 value or null       |
| `getFloat(path)`    | Get float value or null     |
| `getNumber(path)`   | Get number as float or null |
| `toBool(path)`      | Coerce value to boolean     |
| `isNull(path)`      | Check if value is null      |
| `isNan(path)`       | Check if value is NaN       |
| `isInf(path)`       | Check if value is Inf       |
| `exists(path)`      | Check if path exists        |
| `getType(path)`     | Get base type name          |
| `getTypeName(path)` | Get precise type name       |
| `toStruct(T)`       | **Convert to Zig struct T** |
| `initFromStruct(T)` | **Create Document from Struct** |

### Document Methods - Setters

| Method                   | Description       |
| ------------------------ | ----------------- |
| `setString(path, value)` | Set string value  |
| `setBool(path, value)`   | Set bool value    |
| `setInt(path, value)`    | Set integer value |
| `setFloat(path, value)`  | Set float value   |
| `setNull(path)`          | Set value to null |
| `setObject(path)`        | Set empty object  |
| `setArray(path)`         | Set empty array   |
| `setFromStruct(path,v)`  | Set object from Zig struct |

### Document Methods - Array Operations

| Method                                      | Description            |
| ------------------------------------------- | ---------------------- |
| `arrayLen(path)`                            | Get array length       |
| `getArrayString(path, index)`               | Get string at index    |
| `getArrayElement(path, index)`              | Get element at index   |
| `getArrayBool(path, index)`                 | Get boolean element    |
| `appendToArray(path, value)`                | Append string to array |
| `appendIntToArray(path, value)`             | Append int to array    |
| `insertStringIntoArray(path, index, value)` | Insert string          |
| `insertIntIntoArray(path, index, value)`    | Insert integer         |
| `removeFromArray(path, index)`              | Remove from array      |
| `popFromArray(path)`                        | Remove last element    |
| `shiftArray(path)`                          | Remove first element   |
| `unshiftArray(path, value)`                 | Prepend to array       |
| `indexOf(path, value)`                      | Find string index      |
| `countAt(path)`                             | Count items/keys       |

### Document Methods - Find & Replace

| Method                        | Description                  |
| ----------------------------- | ---------------------------- |
| `findString(needle)`          | Find paths containing string |
| `findExact(needle)`           | Find paths with exact match  |
| `replaceAll(find, replace)`   | Replace all occurrences      |
| `replaceFirst(find, replace)` | Replace first occurrence     |
| `replaceLast(find, replace)`  | Replace last occurrence      |

### Document Methods - Other

| Method                       | Description                                                                 |
| ---------------------------- | --------------------------------------------------------------------------- |
| `delete(path)`               | Delete key, returns true if existed                                         |
| `clear()`                    | Clear all data                                                              |
| `count()`                    | Get number of root keys                                                     |
| `keys()`                     | Get all root keys                                                           |
| `merge(other)`               | Merge another document                                                      |
| `clone()`                    | Create a deep copy                                                          |
| `save()`                     | Save to original file path                                                  |
| `saveAs(path)`               | Save to specified path                                                      |
| `saveAsAtomic(path)`         | Atomically save to specified path (temporary file + rename)                 |
| `saveWithBackup(backup_ext)` | Save and create a backup of the previous file using the extension           |
| `saveIfChanged()`            | Only write when contents differ (normalizes trailing newline; returns bool) |
| `toString()`                 | Get formatted ZON string                                                    |
| `toCompactString()`          | Get compact ZON string                                                      |
| `toPrettyString(indent)`     | Get ZON with custom indent                                                  |
| `reload()`                   | Reload from disk (discarding changes)                       |
| `hasChangedOnDisk()`         | Check if file changed on disk                               |
| `deleteFileOnDisk()`         | Delete the associated file                                  |
| `renameFileOnDisk(new)`      | Rename the associated file                                  |
| `deinit()`                   | Free all resources                                                          |
| `close()`                    | Alias for `deinit()`                                                        |

---

## Examples Directory

The `examples/` directory contains comprehensive examples:

- **basic.zig** - Core operations and getting started
- **package_manifest.zig** - Parsing build.zig.zon format
- **find_replace.zig** - Find and replace operations
- **arrays.zig** - Array operations
- **pretty_print.zig** - Pretty printing with different indentation
- **merge_clone.zig** - Merging and cloning documents
- **config_management.zig** - Configuration file management
- **file_operations.zig** - Atomic writes, backups, and file helpers
- **identifier_values.zig** - Identifier value parsing and usage
- **nested_creation.zig** - Creating deeply nested structures
- **error_handling.zig** - Examples of parse and file error handling

### File helpers and utilities

Added file helpers for safer file operations:

- `zon.readFile(path, allocator)` - Read file contents into allocator-managed buffer
- `zon.writeFileAtomic(path, contents)` - Atomically write using a temporary file + rename
- `zon.copyFile(src, dest, overwrite)` - Copy file with optional overwrite
- `zon.moveFile(src, dest, overwrite)` - Move/rename file with optional overwrite
- `Document.saveAsAtomic(path)` - Save a document atomically
- `Document.saveWithBackup(path)` - Save and create a `.bak` backup of the previous file
- `Document.saveIfChanged()` - Only write when contents differ (normalizes trailing newline; returns `true` if a write occurred)

---

## Building

```bash
# Run tests
zig build test

# Build library
zig build

# Run example
zig build example

# Format code
zig fmt src/ examples/
```

---

## Documentation

Full documentation: **https://muhammad-fiaz.github.io/zon.zig/**

---

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md).

---

## License

MIT License - see [LICENSE](LICENSE).

---

## Links

- **Documentation**: https://muhammad-fiaz.github.io/zon.zig/
- **Repository**: https://github.com/muhammad-fiaz/zon.zig
- **Issues**: https://github.com/muhammad-fiaz/zon.zig/issues
- **Releases**: https://github.com/muhammad-fiaz/zon.zig/releases
