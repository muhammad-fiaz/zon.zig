---
title: "Module Functions"
description: "Top-level functions in the `zon` module: creation, parsing, file utilities, update checking, and version info."
---

# Module Functions

Top-level functions in the `zon` module.

## Import

```zig
const zon = @import("zon");
```

## Aliases

Many module-level functions have convenience aliases for common use cases:

| Primary Function       | Aliases                                 |
| ---------------------- | --------------------------------------- |
| `create(alloc)`        | `new`, `init`                           |
| `open(alloc, path)`    | `load`, `fromFile`, `openFile`, `parseFile` |
| `parse(alloc, src)`    | `fromSource`, `parseString`             |
| `fromJson(alloc, src)` | `parseJson`                             |
| `fromMap(alloc, map)`  | `initFromMap`                           |
| `fromStruct(alloc, v)` | `initFromStruct`                        |
| `readFile(alloc, path)`| `read`                                  |
| `writeFileAtomic(...)` | `writeAtomic`, `saveAtomic`             |
| `deleteFile(path)`     | `removeFile`                            |
| `moveFile(...)`        | `renameFile`                            |
| `fileExists(path)`     | `hasFile`                               |
| `validate(alloc, src)` | `isValid`, `isZonValid`                 |
| `validateFile(...)`    | `isValidFile`, `isZonFileValid`         |
| `toStruct(doc, T)`     | `unmarshal`                             |

## Struct Conversion

### fromStruct

Create a Document from a Zig struct or value.

```zig
pub fn fromStruct(allocator: Allocator, value: anytype) !Document
```

**Example:**

```zig
const Config = struct { name: []const u8 };
var doc = try zon.fromStruct(allocator, Config{ .name = "app" });
```

### initFromStruct

Alias for `fromStruct`.

```zig
pub fn initFromStruct(allocator: Allocator, value: anytype) !Document
```

## Document Creation

### create

Create an empty ZON document.

```zig
pub fn create(allocator: Allocator) Document
```

**Example:**

```zig
var doc = zon.create(allocator);
defer doc.deinit();

try doc.setString("name", "myapp");
```

### open

Open and parse a ZON file.

```zig
pub fn open(allocator: Allocator, file_path: []const u8) !Document
```

**Example:**

```zig
var doc = try zon.open(allocator, "config.zon");
defer doc.deinit();

const name = doc.getString("name");
```

**Errors:**

- `error.FileNotFound` - File doesn't exist
- `error.UnexpectedToken` - Invalid ZON syntax
- `error.OutOfMemory` - Allocation failed

### parse

Parse ZON from a string.

```zig
pub fn parse(allocator: Allocator, source: []const u8) !Document
```

**Example:**

```zig
const source =
    \\.{
    \\    .name = "myapp",
    \\    .version = "1.0.0",
    \\}
;

var doc = try zon.parse(allocator, source);
defer doc.deinit();
```

**Errors:**

- `error.UnexpectedToken` - Invalid syntax
- `error.InvalidNumber` - Malformed number
- `error.UnterminatedString` - Missing closing quote

## File Utilities

### fileExists

Check if a file exists.

```zig
pub fn fileExists(file_path: []const u8) bool
```

**Example:**

```zig
if (zon.fileExists("config.zon")) {
    var doc = try zon.open(allocator, "config.zon");
    defer doc.deinit();
    // ...
} else {
    std.debug.print("Config not found, using defaults\n", .{});
}
```

### readFile

Read a file into an allocator-owned buffer (caller must `allocator.free` the buffer).

```zig
pub fn readFile(allocator: Allocator, path: []const u8) ![]u8
```

**Example:**

```zig
const contents = try zon.readFile(allocator, "config.zon");
allocator.free(contents);
```

### writeFileAtomic

Write data to a file atomically. This writes to a temporary file and renames it into place to avoid partial writes.

```zig
pub fn writeFileAtomic(allocator: Allocator, path: []const u8, data: []const u8) !void
```

**Example:**

```zig
try zon.writeFileAtomic(allocator, "config.zon", data);
```

### copyFile

Copy a file. Pass `overwrite=true` to replace an existing destination file.

```zig
pub fn copyFile(source_path: []const u8, dest_path: []const u8, overwrite: bool) !void
```

**Example:**

```zig
try zon.copyFile("config.zon", "config.zon.backup", true);
```

### moveFile

Move (rename) a file. Pass `overwrite=true` to replace an existing destination.

```zig
pub fn moveFile(old_path: []const u8, new_path: []const u8, overwrite: bool) !void
```

**Example:**

```zig
try zon.moveFile("temp.zon", "config.zon", true);
```

### renameFile

Rename or move a file (alias for `moveFile`).

```zig
pub fn renameFile(old_path: []const u8, new_path: []const u8, overwrite: bool) !void
```

**Example:**

```zig
try zon.renameFile("config.old.zon", "config.zon", true);
```

### deleteFile

Delete a file (alias: `removeFile`).

```zig
pub fn deleteFile(file_path: []const u8) !void
```

**Example:**

```zig
try zon.deleteFile("temp.zon");
```

### loadOrCreate

Loads a ZON file, or creates it with default `content` if it doesn't exist.

```zig
pub fn loadOrCreate(allocator: Allocator, path: []const u8, content: []const u8) !Document
```

**Example:**

```zig
var doc = try zon.loadOrCreate(allocator, "settings.zon", ".{ .theme = .dark }");
```

### movePathInFile

Moves (renames) a key path directly inside a ZON file on disk.

```zig
pub fn movePathInFile(allocator: Allocator, path: []const u8, old_key: []const u8, new_key: []const u8) !void
```

**Example:**

```zig
try zon.movePathInFile(allocator, "config.zon", "db.pass", "db.secret");
```

### copyPathInFile

Copies a key path directly inside a ZON file on disk.

```zig
pub fn copyPathInFile(allocator: Allocator, path: []const u8, src_key: []const u8, dst_key: []const u8) !void
```

**Example:**

```zig
try zon.copyPathInFile(allocator, "config.zon", "template.settings", "user.settings");
```

## Update Checking

### disableUpdateCheck

Disable update notifications.

```zig
pub fn disableUpdateCheck() void
```

**Example:**

```zig
// Disable at startup
zon.disableUpdateCheck();
```

### enableUpdateCheck

Enable update notifications.

```zig
pub fn enableUpdateCheck() void
```

**Example:**

```zig
zon.enableUpdateCheck();
```

### isUpdateCheckEnabled

Check if update notifications are enabled.

```zig
pub fn isUpdateCheckEnabled() bool
```

**Example:**

```zig
if (zon.isUpdateCheckEnabled()) {
    std.debug.print("Update checking is on\n", .{});
}
```

### checkForUpdates

Manually check for updates.

```zig
pub fn checkForUpdates(allocator: Allocator) void
```

**Example:**

```zig
zon.checkForUpdates(allocator);
```

## Validation & Encoding

### validateSemVer

Validate a semantic version string using Zig's built-in `std.SemanticVersion`.

```zig
pub fn validateSemVer(version_str: []const u8) bool
```

**Example:**

```zig
if (zon.validateSemVer("1.2.3")) {
    std.debug.print("Valid semver\n", .{});
}
if (!zon.validateSemVer("not-a-version")) {
    std.debug.print("Invalid semver\n", .{});
}
```

### base64Encode

Encode bytes to a standard base64 string. Caller must free the returned string.

```zig
pub fn base64Encode(allocator: Allocator, data: []const u8) ![]const u8
```

**Example:**

```zig
const encoded = try zon.base64Encode(allocator, "hello world");
defer allocator.free(encoded);
std.debug.print("{s}\n", .{encoded}); // "aGVsbG8gd29ybGQ="
```

### base64Decode

Decode a standard base64 string back to bytes. Caller must free the returned bytes. Returns `error.InvalidBase64` if input is not valid base64.

```zig
pub fn base64Decode(allocator: Allocator, encoded: []const u8) ![]u8
```

**Example:**

```zig
const decoded = try zon.base64Decode(allocator, "aGVsbG8gd29ybGQ=");
defer allocator.free(decoded);
std.debug.print("{s}\n", .{decoded}); // "hello world"
```

## Stringify

### stringify

Stringify a Value tree to ZON source code.

```zig
pub fn stringify(allocator: Allocator, value: *const Value, options: StringifyOptions) StringifyError![]u8
```

### StringifyOptions

```zig
pub const StringifyOptions = struct {
    indent: usize = 4,
    initial_indent: usize = 0,
    quote_keys: bool = false,
    sort_keys: bool = true,
};
```

- `indent` — Number of spaces per indent level (default `4`)
- `initial_indent` — Starting indent level in spaces (default `0`)
- `quote_keys` — Always quote object keys, even valid identifiers (default `false`)
- `sort_keys` — Sort object keys alphabetically (default `true`)

### stringifyJson

Stringify a Value tree to JSON.

```zig
pub fn stringifyJson(allocator: Allocator, value: *const Value) StringifyError![]u8
```

## Validation

### validate

Check if a ZON source string is syntactically valid.

```zig
pub fn validate(allocator: Allocator, source: []const u8) bool
```

**Example:**
```zig
if (zon.validate(allocator, source)) {
    std.debug.print("Valid ZON\n", .{});
}
```

### validateFile

Check if a ZON file is syntactically valid.

```zig
pub fn validateFile(allocator: Allocator, path: []const u8) bool
```

**Example:**
```zig
if (zon.validateFile(allocator, "config.zon")) {
    std.debug.print("Valid ZON file\n", .{});
}
```

## Formatting

### format

Re-format a ZON source string with canonical indentation.

```zig
pub fn format(allocator: Allocator, source: []const u8) ![]u8
```

**Example:**
```zig
const formatted = try zon.format(allocator, source);
defer allocator.free(formatted);
```

### formatFile

Re-format a ZON file in-place with canonical indentation.

```zig
pub fn formatFile(allocator: Allocator, path: []const u8) !void
```

**Example:**
```zig
try zon.formatFile(allocator, "config.zon");
```

## JSON Interop

### fromJson

Create a Document from a JSON string.

```zig
pub fn fromJson(allocator: Allocator, json: []const u8) !Document
```

**Example:**
```zig
var doc = try zon.fromJson(allocator, `{"name": "app", "port": 80}`);
defer doc.deinit();
```

### fromMap

Create a Document from a Zig `std.StringHashMap` or any `anytype` container.

```zig
pub fn fromMap(allocator: Allocator, map: anytype) !Document
```

**Example:**
```zig
var map = std.StringHashMap(Value).init(allocator);
try map.put("key", .{ .string = "value" });
var doc = try zon.fromMap(allocator, map);
defer doc.deinit();
```

## Struct Conversion (Document to Struct)

### toStruct

Convert a Document directly to a Zig struct.

```zig
pub fn toStruct(doc: *const Document, comptime T: type) !T
```

**Example:**
```zig
const Config = struct {
    name: []const u8,
    port: u16,
    debug: bool,
};

var doc = try zon.parse(allocator, source);
defer doc.deinit();

const cfg = try zon.toStruct(&doc, Config);
std.debug.print("{s} on port {d}\n", .{ cfg.name, cfg.port });
```

## Constants

### version

Library version string.

```zig
pub const version: []const u8 = "0.0.5";
```

**Example:**

```zig
std.debug.print("zon.zig {s}\n", .{zon.version});
```

**Output:**

```
zon.zig 0.0.5
```

## Complete Example

```zig
const std = @import("std");
const zon = @import("zon");

pub fn main() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Disable update notifications
    zon.disableUpdateCheck();

    // Print version
    std.debug.print("zon.zig {s}\n", .{zon.version});

    // Check if config exists
    if (zon.fileExists("config.zon")) {
        std.debug.print("Found existing config\n", .{});

        // Backup before modifying
        try zon.copyFile("config.zon", "config.zon.backup");

        // Open and modify
        var doc = try zon.open(allocator, "config.zon");
        defer doc.deinit();

        try doc.setString("modified", "true");
        try doc.save();
    } else {
        std.debug.print("Creating new config\n", .{});

        // Create new
        var doc = zon.create(allocator);
        defer doc.deinit();

        try doc.setIdentifier("name", "myapp");
        try doc.setString("version", "1.0.0");
        try doc.saveAs("config.zon");
    }

    // Parse from string
    const source = ".{ .test = true }";
    var parsed = try zon.parse(allocator, source);
    defer parsed.deinit();

    std.debug.print("Parsed: {}\n", .{parsed.getBool("test").?});
}
```

**Output (first run):**

```
zon.zig 0.0.5
Creating new config
Parsed: true
```

**Output (second run):**

```
zon.zig 0.0.5
Found existing config
Parsed: true
```


