---
title: "Memory & Allocators"
description: "How zon.zig handles memory and how to use different Zig allocators like GPA and Arena correctly."
---

# Memory & Allocators

zon.zig follows standard Zig patterns for memory management. Any function that may allocate memory requires an `Allocator` parameter.

## Supported Allocators

The library is designed to work with **any** Zig allocator. The most common ones are:

### 1. GeneralPurposeAllocator (GPA)

Best for long-running processes or when you are dynamically adding/removing many keys in different documents.

```zig
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
defer _ = gpa.deinit();
const allocator = gpa.allocator();

var doc = zon.create(allocator);
defer doc.close(); // Important: Explicitly free document memory
```

### 2. ArenaAllocator

Best for CLI tools, one-off parsing tasks, or performance-critical loops. It is extremely fast and simplifies cleanup.

**Note**: `ArenaAllocator` is a wrapper that requires a "child" allocator (like `page_allocator`) to provide raw memory blocks.

```zig
var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
defer arena.deinit(); // Frees EVERYTHING allocated via this arena at once
const allocator = arena.allocator();

var doc = try zon.open(allocator, "config.zon");
// doc.close() is optional here because arena.deinit() handles it.
```

## Internal Allocation Strategy

When you create a `Document`, it stores the `Allocator` you provided. This allocator is used for:

- **Intermediate Objects**: Automatically created when setting nested paths (e.g., `doc.setString("a.b.c", "val")`).
- **Strings & Identifiers**: When parsing a string, all values are duplicated into the document's allocator.
- **Buffers**: Stringification and find/replace operations use this allocator for temporary results.

## Performance Tips

1. **Use Arenas for Parsing**: If you are just loading a ZON file to read a few values and then exiting or moving on, use an `ArenaAllocator`. It performs a single bulk free at the end.
2. **Pre-allocate with GPA**: If you have a single document you keep updating over hours of runtime, `GPA` is better for preventing overall heap fragmentation.
3. **Avoid Re-parsing**: If you need to access the same file many times, keep the `Document` alive in memory rather than calling `zon.open` repeatedly.

## Explicit Cleanup

While `doc.close()` (and its alias `doc.deinit()`) are provided, they are primarily for documents using `GPA`. When using an `ArenaAllocator`, you can rely on the arena's deinitialization to clean up the document and all its inner values automatically.

```zig
var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
defer arena.deinit();
const allocator = arena.allocator();

var doc = try zon.open(allocator, "settings.zon");
// No need for doc.close() if arena.deinit() is called.
```
