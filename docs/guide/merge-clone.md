---
title: "Merge & Clone"
description: "Merge and clone document operations for combining configurations and creating deep copies safely."
---

# Merge & Clone

zon.zig supports merging documents together and creating deep copies.

## Merging Documents

Use `merge` to combine two documents. Values from the source document overwrite existing values in the target.

```zig
var base = zon.create(allocator);
defer base.deinit();

try base.setString("name", "myapp");
try base.setString("version", "1.0.0");
try base.setInt("port", 8080);

var override = zon.create(allocator);
defer override.deinit();

try override.setInt("port", 9000);
try override.setBool("debug", true);

// Merge override into base
try base.merge(&override);

// base now has:
// - name: "myapp" (unchanged)
// - version: "1.0.0" (unchanged)
// - port: 9000 (overwritten)
// - debug: true (added)
```

### Use Cases

- **Configuration Layers**: Merge environment-specific configs over base configs
- **Default Values**: Create defaults, then merge user preferences
- **Incremental Updates**: Apply patches to existing documents

## Cloning Documents

Use `clone` to create an independent deep copy:

```zig
var original = zon.create(allocator);
defer original.deinit();

try original.setString("name", "original");
try original.setInt("value", 100);

// Create deep copy
var copy = try original.clone();
defer copy.deinit();

// Modify the copy
try copy.setString("name", "copy");
try copy.setInt("value", 200);

// Original is unchanged
std.debug.print("Original: {s}, {d}\n", .{
    original.getString("name").?,
    original.getInt("value").?
});
// Output: Original: original, 100

std.debug.print("Copy: {s}, {d}\n", .{
    copy.getString("name").?,
    copy.getInt("value").?
});
// Output: Copy: copy, 200
```

## Practical Example

```zig
const std = @import("std");
const zon = @import("zon");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    zon.disableUpdateCheck();

    // Create base config
    var dev_config = zon.create(allocator);
    defer dev_config.deinit();

    try dev_config.setString("environment", "development");
    try dev_config.setString("database.host", "localhost");
    try dev_config.setInt("database.port", 5432);
    try dev_config.setString("database.name", "myapp_dev");
    try dev_config.setBool("debug", true);

    std.debug.print("Development config:\n", .{});
    const dev_str = try dev_config.toString();
    defer allocator.free(dev_str);
    std.debug.print("{s}\n\n", .{dev_str});

    // Clone for production
    var prod_config = try dev_config.clone();
    defer prod_config.deinit();

    // Create production overrides
    var prod_overrides = zon.create(allocator);
    defer prod_overrides.deinit();

    try prod_overrides.setString("environment", "production");
    try prod_overrides.setString("database.host", "db.example.com");
    try prod_overrides.setString("database.name", "myapp_prod");
    try prod_overrides.setBool("debug", false);

    // Merge overrides
    try prod_config.merge(&prod_overrides);

    std.debug.print("Production config:\n", .{});
    const prod_str = try prod_config.toString();
    defer allocator.free(prod_str);
    std.debug.print("{s}\n", .{prod_str});
}
```

Output:

```
Development config:
.{
    .database = .{
        .host = "localhost",
        .name = "myapp_dev",
        .port = 5432,
    },
    .debug = true,
    .environment = "development",
}

Production config:
.{
    .database = .{
        .host = "db.example.com",
        .name = "myapp_prod",
        .port = 5432,
    },
    .debug = false,
    .environment = "production",
}
```
