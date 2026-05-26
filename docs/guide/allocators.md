---
title: "Memory & Allocators"
description: "How zon.zig handles memory and how to use Zig allocators: DebugAllocator, ArenaAllocator, SmpAllocator, and more."
---

# Memory & Allocators

zon.zig follows standard Zig patterns for memory management. Any function that may allocate memory requires an `Allocator` parameter.

## Supported Allocators

The library is designed to work with **any** Zig allocator. The most common ones for Zig 0.16 are:

### 1. DebugAllocator (GPA)

Best for **development and debugging** — detects memory leaks and double-frees at runtime. Replaces the old `GeneralPurposeAllocator` (removed in Zig 0.16).

```zig
var gpa = std.heap.DebugAllocator(.{}){};
defer _ = gpa.deinit();
const allocator = gpa.allocator();

var doc = zon.create(allocator);
defer doc.close(); // Important: Explicitly free document memory
```

### 2. ArenaAllocator

Best for **CLI tools, one-off parsing tasks, or performance-critical loops** — extremely fast allocation with a single bulk free at the end.

```zig
var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
defer arena.deinit(); // Frees EVERYTHING allocated via this arena at once
const allocator = arena.allocator();

var doc = try zon.open(allocator, "config.zon");
// doc.close() is optional here because arena.deinit() handles it.
```

### 3. SmpAllocator (New in Zig 0.16)

Best for **production multi-threaded applications** — a high-performance allocator with per-thread freelists. Designed for `ReleaseFast` builds.

```zig
const allocator: std.mem.Allocator = .{ .vtable = &std.heap.SmpAllocator.vtable };
// SmpAllocator is a singleton — no init/deinit needed.

var doc = try zon.open(allocator, "config.zon");
defer doc.close();
```

### 4. FixedBufferAllocator

Best for **embedded or no-alloc environments** — allocates from a fixed byte buffer with no heap usage.

```zig
var buf: [1024 * 64]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&buf);
const allocator = fba.allocator();

var doc = try zon.open(allocator, "config.zon");
defer doc.close();
```

### 5. PageAllocator

Direct OS page-level allocator — useful for very large allocations.

```zig
const allocator = std.heap.page_allocator;
var doc = try zon.open(allocator, "config.zon");
defer doc.close();
```

## Internal Allocation Strategy

When you create a `Document`, it stores the `Allocator` you provided. This allocator is used for:

- **Intermediate Objects**: Automatically created when setting nested paths (e.g., `doc.setString("a.b.c", "val")`).
- **Strings & Identifiers**: When parsing a string, all values are duplicated into the document's allocator.
- **Buffers**: Stringification and find/replace operations use this allocator for temporary results.

## Performance Tips

1. **Use Arenas for Parsing**: If you are just loading a ZON file to read a few values and then exiting or moving on, use an `ArenaAllocator`. It performs a single bulk free at the end.
2. **Use DebugAllocator for Development**: It catches memory leaks and double-frees — invaluable during development. Switch to `SmpAllocator` in release builds.
3. **Use SmpAllocator for Production**: In `ReleaseFast` mode with multi-threading, `SmpAllocator` provides per-thread freelists for minimal contention.
4. **Avoid Re-parsing**: If you need to access the same file many times, keep the `Document` alive in memory rather than calling `zon.open` repeatedly.

## Explicit Cleanup

While `doc.close()` (and its alias `doc.deinit()`) are provided, they are primarily for documents using `DebugAllocator` or `SmpAllocator`. When using an `ArenaAllocator`, you can rely on the arena's deinitialization to clean up the document and all its inner values automatically.

```zig
// DebugAllocator / SmpAllocator — always call doc.close()
var doc = zon.create(allocator);
defer doc.close();

// ArenaAllocator — arena.deinit() cleans up everything
var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
defer arena.deinit();
const allocator = arena.allocator();
var doc = try zon.open(allocator, "settings.zon");
// No need for doc.close() if arena.deinit() is called.
```
