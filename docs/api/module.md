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

## Constants

### version

Library version string.

```zig
pub const version: []const u8 = "0.0.4";
```

**Example:**

```zig
std.debug.print("zon.zig {s}\n", .{zon.version});
```

**Output:**

```
zon.zig 0.0.4
```

## Complete Example

```zig
const std = @import("std");
const zon = @import("zon");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
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
zon.zig 0.0.4
Creating new config
Parsed: true
```

**Output (second run):**

```
zon.zig 0.0.4
Found existing config
Parsed: true
```
