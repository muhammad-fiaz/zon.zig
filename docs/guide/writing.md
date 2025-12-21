---
title: "Writing Files"
description: "Saving documents to disk and writing with custom formatting options and path handling."
---

# Writing Files

Comprehensive guide to creating and writing ZON files.

## Create a Document

```zig
const std = @import("std");
const zon = @import("zon");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    zon.disableUpdateCheck();

    var doc = zon.create(allocator);
    defer doc.close(); // semantic alias for deinit()

    // Add data...

    try doc.saveAs("output.zon");
}
```

## Setting Values

### String Values

```zig
try doc.setString("name", "myapp");
try doc.setString("version", "1.0.0");
try doc.setString("description", "My awesome app");
```

**Output:**

```zig
.{
    .description = "My awesome app",
    .name = "myapp",
    .version = "1.0.0",
}
```

### Identifier Values

Use `setIdentifier` for `.name = .value` syntax (common in build.zig.zon):

```zig
try doc.setIdentifier("name", "my_package");
```

**Output:**

```zig
.{
    .name = .my_package,
}
```

### Boolean Values

```zig
try doc.setBool("enabled", true);
try doc.setBool("debug", false);
try doc.setBool("ssl", true);
```

**Output:**

```zig
.{
    .debug = false,
    .enabled = true,
    .ssl = true,
}
```

### Integer Values

```zig
try doc.setInt("port", 8080);
try doc.setInt("max_connections", 100);
try doc.setInt("timeout_ms", 30000);
```

**Output:**

```zig
.{
    .max_connections = 100,
    .port = 8080,
    .timeout_ms = 30000,
}
```

### Large Hex Values (Fingerprints)

```zig
const fingerprint: u64 = 0xee480fa30d50cbf6;
try doc.setInt("fingerprint", @intCast(fingerprint));
```

```zig
.{
    .fingerprint = 0xee480fa30d50cbf6,
}
```

### Float Values

```zig
try doc.setFloat("rate", 0.05);
try doc.setFloat("pi", 3.14159);
```

**Output:**

```zig
.{
    .pi = 3.14159,
    .rate = 0.05,
}
```

### Null Values

```zig
try doc.setNull("password");
try doc.setNull("optional_field");
```

**Output:**

```zig
.{
    .optional_field = null,
    .password = null,
}
```

## Nested Structures

Intermediate objects are auto-created:

```zig
try doc.setString("server.host", "0.0.0.0");
try doc.setInt("server.port", 8080);
try doc.setBool("server.ssl.enabled", true);
try doc.setString("server.ssl.cert", "/etc/ssl/cert.pem");
try doc.setInt("server.ssl.port", 443);
```

**Output:**

```zig
.{
    .server = .{
        .host = "0.0.0.0",
        .port = 8080,
        .ssl = .{
            .cert = "/etc/ssl/cert.pem",
            .enabled = true,
            .port = 443,
        },
    },
}
```

## Arrays

### Create Empty Array

```zig
try doc.setArray("paths");
```

### Append Strings

```zig
try doc.setArray("paths");
try doc.appendToArray("paths", "build.zig");
try doc.appendToArray("paths", "build.zig.zon");
try doc.appendToArray("paths", "src");
```

**Output:**

```zig
.{
    .paths = .{
        "build.zig",
        "build.zig.zon",
        "src",
    },
}
```

### Append Other Types

```zig
try doc.setArray("numbers");
try doc.appendIntToArray("numbers", 10);
try doc.appendIntToArray("numbers", 20);
try doc.appendIntToArray("numbers", 30);

try doc.setArray("rates");
try doc.appendFloatToArray("rates", 0.1);
try doc.appendFloatToArray("rates", 0.2);

try doc.setArray("flags");
try doc.appendBoolToArray("flags", true);
try doc.appendBoolToArray("flags", false);
```

**Output:**

```zig
.{
    .flags = .{
        true,
        false,
    },
    .numbers = .{
        10,
        20,
        30,
    },
    .rates = .{
        0.1,
        0.2,
    },
}
```

## Modifying Values

### Update Existing Value

```zig
try doc.setString("version", "1.0.0");
// Later...
try doc.setString("version", "2.0.0"); // Overwrites
```

### Delete Key

```zig
try doc.setString("temp", "value");
_ = doc.delete("temp"); // Returns true if existed
```

### Clear All

```zig
doc.clear(); // Removes all data
```

## Output Formatting

### Default (4-space indent)

```zig
const output = try doc.toString();
defer allocator.free(output);
std.debug.print("{s}\n", .{output});
```

### Custom Indent

```zig
// 2-space
const two = try doc.toPrettyString(2);
defer allocator.free(two);

// 8-space
const eight = try doc.toPrettyString(8);
defer allocator.free(eight);
```

### Compact (no indent)

```zig
const compact = try doc.toCompactString();
defer allocator.free(compact);
```

**Compact Output:**

```zig
.{
.name = "myapp",
.port = 8080,
}
```

## Saving Files

### Save to New Path

```zig
try doc.saveAs("config.zon");
```

### Save to Original Path

```zig
var doc = try zon.open(allocator, "config.zon");
defer doc.deinit();

try doc.setString("version", "2.0.0");
try doc.save(); // Saves back to config.zon
```

## File Utilities

### Copy File

```zig
try zon.copyFile("config.zon", "config.zon.backup");
```

### Rename File

```zig
try zon.renameFile("old.zon", "new.zon");
```

### Delete File

```zig
try zon.deleteFile("temp.zon");
```

### Check Exists

```zig
if (zon.fileExists("config.zon")) {
    std.debug.print("File exists\n", .{});
}
```

## Complete Example: build.zig.zon

```zig
const std = @import("std");
const zon = @import("zon");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    zon.disableUpdateCheck();

    var doc = zon.create(allocator);
    defer doc.deinit();

    // Package info
    try doc.setIdentifier("name", "my_package");
    try doc.setString("version", "0.1.0");
    try doc.setString("minimum_zig_version", "0.15.0");

    // Fingerprint (u64 / large hex)
    const fp: u64 = 0xee480fa30d50cbf6;
    try doc.setInt("fingerprint", @intCast(fp));

    // Paths
    try doc.setArray("paths");
    try doc.appendToArray("paths", "build.zig");
    try doc.appendToArray("paths", "build.zig.zon");
    try doc.appendToArray("paths", "src");

    // Dependencies
    try doc.setString("dependencies.http.url", "https://github.com/example/http");
    try doc.setString("dependencies.http.hash", "abc123def456");

    // Output
    const output = try doc.toString();
    defer allocator.free(output);
    std.debug.print("{s}\n", .{output});

    // Save
    try doc.saveAs("build.zig.zon");
}
```

**Output:**

```zig
.{
    .dependencies = .{
        .http = .{
            .hash = "abc123def456",
            .url = "https://github.com/example/http",
        },
    },
    .fingerprint = 0xee480fa30d50cbf6,
    .minimum_zig_version = "0.15.0",
    .name = .my_package,
    .paths = .{
        "build.zig",
        "build.zig.zon",
        "src",
    },
    .version = "0.1.0",
}
```

## Clone and Modify

```zig
// Create base config
var base = zon.create(allocator);
defer base.deinit();

try base.setString("name", "myapp");
try base.setString("environment", "development");
try base.setString("database.host", "localhost");

// Clone for production
var prod = try base.clone();
defer prod.deinit();

try prod.setString("environment", "production");
try prod.setString("database.host", "db.example.com");

// Save both
try base.saveAs("config.dev.zon");
try prod.saveAs("config.prod.zon");
```
