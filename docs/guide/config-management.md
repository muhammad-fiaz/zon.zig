---
title: "Configuration Management"
description: "Learn how to manage application configurations with zon.zig using base configurations and environment-specific overrides."
---

# Configuration Management

`zon.zig` shines at configuration management because of its document-based nature. You can load a default configuration, then selectively override parts of it (e.g., from environment variables, CLI args, or another file) using deep merging.

## The Base + Override Pattern

A common pattern is to have a base configuration (e.g., development defaults) and apply overrides for different environments (production, staging).

### 1. Define Base Configuration

```zig
var config = zon.create(allocator);
defer config.deinit();

// Set defaults
try config.setString("app.env", "development");
try config.setInt("server.port", 8080);
try config.setBool("logging.verbose", true);
try config.setString("db.host", "localhost");
```

### 2. Create Overrides

You can load overrides from a file (`prod.zon`) or create them programmatically:

```zig
var prod_overrides = zon.create(allocator);
defer prod_overrides.deinit();

// Production changes
try prod_overrides.setString("app.env", "production");
try prod_overrides.setBool("logging.verbose", false);
try prod_overrides.setString("db.host", "db-prod.example.com");
// Note: server.port is NOT set, so it will keep the default
```

### 3. Merge Recursive

Use `mergeRecursive` to blend the overrides into the base config. Unlike `merge` (which replaces top-level keys), `mergeRecursive` walks down into nested objects.

```zig
// Apply overrides to config
try config.mergeRecursive(&prod_overrides);

// Result:
// app.env = "production"
// server.port = 8080 (preserved)
// logging.verbose = false
// db.host = "db-prod.example.com"
```

## Example: Environment Support

You can automate this by checking an environment variable:

```zig
const env = std.posix.getenv("APP_ENV") orelse "dev";

var config = try zon.open(allocator, "config/default.zon");
defer config.deinit();

// Try to open env-specific config
const env_file = try std.fmt.allocPrint(allocator, "config/{s}.zon", .{env});
defer allocator.free(env_file);

if (zon.open(allocator, env_file)) |*env_doc| {
    defer env_doc.deinit();
    try config.mergeRecursive(env_doc);
    std.debug.print("Loaded overrides from {s}\n", .{env_file});
} else |_| {
    // No env config found, stick with defaults
}
```

## Flattening for Env Vars

Sometimes you need to export your config to environment variables (e.g., for subprocesses). `zon.zig` allows you to treat keys as paths:

```zig
// config.zon:
// .{ .server = .{ .port = 8080 } }

const port = config.getInt("server.port"); 
// You can map this to SERVER_PORT=8080
```
