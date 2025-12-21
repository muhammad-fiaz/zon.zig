---
title: "Pretty Print"
description: "Formatting and output options: pretty, compact, and custom indentation for ZON serialization."
---

# Pretty Print

zon.zig provides flexible output formatting with configurable indentation.

## Default Output

The standard `toString()` uses 4-space indentation:

```zig
const output = try doc.toString();
defer allocator.free(output);
```

Output:

```zig
.{
    .name = "myapp",
    .config = .{
        .port = 8080,
    },
}
```

## Custom Indentation

Use `toPrettyString(indent)` for custom indentation:

### 2-Space Indentation

```zig
const output = try doc.toPrettyString(2);
defer allocator.free(output);
```

Output:

```zig
.{
  .name = "myapp",
  .config = .{
    .port = 8080,
  },
}
```

### 8-Space Indentation

```zig
const output = try doc.toPrettyString(8);
defer allocator.free(output);
```

Output:

```zig
.{
        .name = "myapp",
        .config = .{
                .port = 8080,
        },
}
```

## Compact Output

Use `toCompactString()` for minimal whitespace (0 indentation):

```zig
const compact = try doc.toCompactString();
defer allocator.free(compact);
```

Output:

```zig
.{
.name = "myapp",
.config = .{
.port = 8080,
},
}
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

    var doc = zon.create(allocator);
    defer doc.deinit();

    try doc.setString("name", "myapp");
    try doc.setString("version", "1.0.0");
    try doc.setString("config.server.host", "localhost");
    try doc.setInt("config.server.port", 8080);
    try doc.setBool("config.server.ssl", true);

    // Default (4-space)
    std.debug.print("=== Default (4-space) ===\n", .{});
    const default_output = try doc.toString();
    defer allocator.free(default_output);
    std.debug.print("{s}\n", .{default_output});

    // 2-space
    std.debug.print("=== 2-space ===\n", .{});
    const two_space = try doc.toPrettyString(2);
    defer allocator.free(two_space);
    std.debug.print("{s}\n", .{two_space});

    // Compact
    std.debug.print("=== Compact ===\n", .{});
    const compact = try doc.toCompactString();
    defer allocator.free(compact);
    std.debug.print("{s}\n", .{compact});
}
```

## Use Cases

| Format                | Use Case                        |
| --------------------- | ------------------------------- |
| **2-space**           | Compact but readable configs    |
| **4-space** (default) | Standard formatting             |
| **8-space**           | Extra readability               |
| **Compact**           | Minimizing file size, embedding |
