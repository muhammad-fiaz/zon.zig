---
title: "Error Handling"
description: "How zon.zig surfaces parse and runtime errors, including parse errors and allocation failures, and how to handle them."
---

# Error Handling

zon.zig provides safe, predictable error handling that never panics.

## Design Philosophy

zon.zig follows these principles:

1. **Getters return null** - Missing paths or type mismatches return `null`, not errors
2. **Setters can error** - Operations that allocate memory return `!void`
3. **Parsing can error** - Invalid syntax returns parse errors
4. **File ops can error** - File operations return standard I/O errors

## Getter Safety

All getter methods return optionals. They never panic:

```zig
// Returns null if path doesn't exist
const name = doc.getString("name");

// Returns null if type doesn't match
const count = doc.getInt("name"); // null if name is a string

// Safe access with orelse
const host = doc.getString("host") orelse "localhost";
const port = doc.getInt("port") orelse 8080;
const enabled = doc.getBool("enabled") orelse true;
```

## Checking Before Access

### Using exists()

```zig
if (doc.exists("config.port")) {
    const port = doc.getInt("config.port").?;
    // Safe to use port
}
```

### Using getType()

```zig
if (doc.getType("value")) |type_name| {
    if (std.mem.eql(u8, type_name, "string")) {
        const str = doc.getString("value").?;
    } else if (std.mem.eql(u8, type_name, "int")) {
        const num = doc.getInt("value").?;
    }
}
```

## Parse Errors

When parsing ZON, the following errors can occur:

| Error                | Description                          |
| -------------------- | ------------------------------------ |
| `UnexpectedToken`    | Invalid syntax, unexpected character |
| `InvalidNumber`      | Malformed number literal             |
| `InvalidString`      | Malformed string literal             |
| `UnterminatedString` | String without closing quote         |
| `OutOfMemory`        | Memory allocation failed             |

### Handling Parse Errors

```zig
var doc = zon.parse(allocator, source) catch |err| {
    switch (err) {
        error.UnexpectedToken => {
            std.debug.print("Syntax error in ZON\n", .{});
        },
        error.InvalidNumber => {
            std.debug.print("Invalid number format\n", .{});
        },
        error.OutOfMemory => {
            std.debug.print("Out of memory\n", .{});
        },
        else => {
            std.debug.print("Parse error: {}\n", .{err});
        },
    }
    return;
};
defer doc.deinit();
```

## File Errors

File operations can fail:

```zig
var doc = zon.open(allocator, "config.zon") catch |err| {
    switch (err) {
        error.FileNotFound => {
            std.debug.print("Config file not found\n", .{});
        },
        error.AccessDenied => {
            std.debug.print("Permission denied\n", .{});
        },
        else => {
            std.debug.print("Failed to open: {}\n", .{err});
        },
    }
    return;
};
defer doc.deinit();
```

## Setter Errors

Setters can fail due to memory allocation:

```zig
doc.setString("name", "myapp") catch |err| {
    std.debug.print("Failed to set value: {}\n", .{err});
    return;
};

// Or use try
try doc.setString("name", "myapp");
```

## Delete Safety

The `delete` method returns `bool`, indicating if the key existed:

```zig
const deleted = doc.delete("optional_field");
if (deleted) {
    std.debug.print("Field was removed\n", .{});
} else {
    std.debug.print("Field didn't exist\n", .{});
}
```

## Save Errors

Saving can fail:

```zig
doc.saveAs("output.zon") catch |err| {
    switch (err) {
        error.AccessDenied => {
            std.debug.print("Cannot write to file\n", .{});
        },
        error.DiskQuota => {
            std.debug.print("Disk full\n", .{});
        },
        else => {
            std.debug.print("Save failed: {}\n", .{err});
        },
    }
    return;
};
```

## Complete Example

```zig
const std = @import("std");
const zon = @import("zon");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    zon.disableUpdateCheck();

    // Safe file open with fallback
    var doc = zon.open(allocator, "config.zon") catch {
        // Create default config
        var new_doc = zon.create(allocator);
        try new_doc.setString("name", "default");
        try new_doc.setInt("port", 8080);
        try new_doc.saveAs("config.zon");
        return;
    };
    defer doc.deinit();

    // Safe value access with defaults
    const name = doc.getString("name") orelse "unnamed";
    const port = doc.getInt("port") orelse 8080;
    const debug = doc.getBool("debug") orelse false;

    std.debug.print("Config: {s} on port {d} (debug: {})\n", .{name, port, debug});
}
```
