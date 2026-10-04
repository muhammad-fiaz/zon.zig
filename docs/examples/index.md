---
title: "Examples"
description: "Complete runnable examples for zon.zig: every example with its usecase, output, and run command."
---

# Examples

Every example below is a complete runnable program in `examples/`. Each page
shows the usecase, how to run it, and its actual verified output.

## Running Examples

```bash
# Run a specific example
zig build run-basic

# Run all examples one at a time
zig build run-all-examples
```

## All Examples

| Example | Usecase | Command |
| ------- | ------- | ------- |
| [Basic](./basic) | Core operations: create, set, get, update, delete, save | `zig build run-basic` |
| [Package Manifest](./package_manifest) | Parse and modify `build.zig.zon` files | `zig build run-package_manifest` |
| [Nested Creation](./nested_creation) | Deeply nested structures via dot paths | `zig build run-nested_creation` |
| [Find & Replace](./find_replace) | Search and replace values document-wide | `zig build run-find_replace` |
| [Arrays](./arrays) | Array create, append, insert, pop, shift | `zig build run-arrays` |
| [Pretty Print](./pretty_print) | Compact, 2/4/8-space ZON output | `zig build run-pretty_print` |
| [Merge & Clone](./merge_clone) | Shallow/deep merge, deep equality, deep copy | `zig build run-merge_clone` |
| [Config Management](./config_management) | Dev/prod configs via clone and recursive merge | `zig build run-config_management` |
| [Error Handling](./error_handling) | Parse/file errors, defaults for missing values | `zig build run-error_handling` |
| [File Operations](./file_operations) | Atomic writes, backups, copy/move, validation | `zig build run-file_operations` |
| [Identifier Values](./identifier_values) | `.name = .value` identifier syntax | `zig build run-identifier_values` |
| [Allocators](./allocators) | DebugAllocator vs ArenaAllocator lifecycles | `zig build run-allocators` |
| [Struct Conversion](./struct_conversion) | Zig struct to document and back | `zig build run-struct_conversion` |
| [Walk & Map](./walk_map) | Traversal, path listing, value mapping | `zig build run-walk_map` |
| [Pick & Omit](./pick_omit) | Document subsets with pick/omit | `zig build run-pick_omit` |
| [Sort & Format](./sort_format) | Key sorting and stringify options | `zig build run-sort_format` |
| [Validation & Sort](./validation_sort) | Type checking, case utils, array ops, filter | `zig build run-validation_sort` |
| [Explicit I/O](./explicit_io) | Client-owned I/O with `std.Io`, no helpers | `zig build run-explicit_io` |
