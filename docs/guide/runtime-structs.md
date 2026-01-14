---
title: "Runtime Struct Conversion"
description: "How to convert dynamic ZON documents into static Zig structs at runtime using toStruct."
---

# Runtime Struct Conversion

While `zon.zig` is primarily a dynamic document-based library, version 0.0.4 introduces the ability to convert these dynamic documents (or parts of them) into static Zig structs at runtime.

This bridges the gap between dynamic editing and type-safe usage, allowing you to "unmarshal" ZON data after loading or modifying it.

## Basics

Use `doc.toStruct(T)` or `zon.toStruct(&doc, T)` to convert. You can also go the other way with `zon.fromStruct`.

## Struct to Document

You can create a full ZON Document from a Zig struct or value using `zon.fromStruct`:

```zig
const Config = struct {
    name: []const u8 = "default",
    port: u16 = 8080,
    features: []const []const u8 = &.{ "a", "b" },
};

var doc = try zon.fromStruct(allocator, Config{ .name = "custom" });
defer doc.deinit();

try std.testing.expectEqualStrings("custom", doc.getString("name").?);
```

You can also set a specific path from a struct:

```zig
try doc.setFromStruct("server.config", my_config_struct);
```

## Document to Struct

```zig
const std = @import("std");
const zon = @import("zon");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var doc = try zon.parse(allocator, 
        \\.{ 
        \\    .name = "my-app", 
        \\    .version = 1, 
        \\    .active = true 
        \\}
    );
    defer doc.deinit();

    const Config = struct {
        name: []const u8,
        version: i32,
        active: bool,
    };

    // Convert to strict struct
    const config = try doc.toStruct(Config);
    // Note: Strings are duplicated using the doc's allocator
    defer allocator.free(config.name);

    std.debug.print("App: {s} v{d}\n", .{config.name, config.version});
}
```

## Features

- **Nested Structs**: Recursively converts ZON objects to sub-structs.
- **Arrays/Slices**: Converts ZON arrays to Zig slices (`[]T`) or arrays (`[N]T`).
- **Strings**: Duplicates strings using the provided allocator.
- **Defaults**: Uses struct field default values if ZON keys are missing.
- **Generic**: Works with any standard Zig type layout.

## Advanced Example

```zig
const Server = struct {
    host: []const u8,
    port: u16 = 8080, // Default value used if missing in ZON
};

const App = struct {
    name: []const u8,
    servers: []Server, // Slice of structs
};

// ZON: 
// .{ 
//    .name = "cluster", 
//    .servers = .{
//        .{ .host = "node1" },
//        .{ .host = "node2", .port = 9000 } 
//    }
// }

const app = try doc.toStruct(App);
defer {
    allocator.free(app.name);
    for (app.servers) |s| allocator.free(s.host);
    allocator.free(app.servers);
}
```

## Error Handling

The conversion will fail with specific errors if the structure doesn't match:

- `error.MissingField`: A required field (no default value) is missing in the ZON.
- `error.TypeMismatch`: ZON value cannot be coerced to the target type (e.g. string to int).
- `error.ArrayLengthMismatch`: Fixed-size array size differs.

## vs std.zon

`std.zon` parses *directly* to structs during the tokenization/parsing phase. `zon.zig` parses to a **Document** (DOM) first, then allows you to convert to a struct.

- **Use `std.zon`** for maximum performance if you only need readonly access to a fixed schema.
- **Use `zon.zig` + `toStruct`** if you need to:
    - Edit the config before using it.
    - Handle unknown fields gracefully (by checking the Document before conversion).
    - Convert only *parts* of a file to structs.
