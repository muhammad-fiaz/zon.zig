---
title: "Introduction"
description: "An introduction to zon.zig: why it exists, what it solves, and how it compares to standard library options."
---

# Introduction

**zon.zig** is a high-level, document-based library for working with the **Zig Object Notation (ZON)** format.

While Zig's standard library (`std.zon`) focuses on **deserialization** (parsing ZON directly into Zig structs), **zon.zig** takes a **document-oriented approach** (similar to DOM in HTML or generic JSON parsers). It parses ZON into a manipulatable in-memory tree (`Value` tree), allowing you to query, edit, add, remove, and structural changes *without* knowing the full schema ahead of time.

## Why use zon.zig?

There are two primary ways to handle data formats:

1.  **Static/Type-Based** (like `std.json` or `std.zon`):
    *   You define a Zig struct: `const Config = struct { port: u16 };`
    *   You parse input directly into that struct.
    *   *Pros:* Type safety, performance, low memory overhead.
    *   *Cons:* Can't handle unknown fields easily, can't "edit" the source file structure (comments/layout are often lost or hard to preserve), rigid structure.

2.  **Dynamic/Document-Based** (like **zon.zig**):
    *   You parse input into a generic `Document` tree.
    *   You access values by path: `doc.getInt("server.port")`.
    *   You can set new values: `doc.setString("new.key", "value")`.
    *   *Pros:* Extreme flexibility, ideal for "editors" or "rewriters", handles unknown structures, powerful manipulation (merge, diff, find/replace).
    *   *Cons:* Higher memory usage (heap allocation for tree), runtime type checking.

**zon.zig** fills the gap for the second use case. It is designed specifically for **building tools** that need to read, modify, and save ZON files (like package managers, config editors, or build tools).

## Core Capabilities

*   **Dynamic Access**: Access deep properties using dot notation: `doc.get("dependencies.http.url")`.
*   **Modification**: set, delete, and move values.
*   **File Management**: Atomic saving, safe file replacement, backups, reload/check-for-changes logic.
*   **Advanced Operations**: Deep merging of documents, finding and replacing values, deep equality checks.
*   **Interop**: Convert generic ZON documents to strict Zig structs (`toStruct`) or initialize documents from structs (`initFromStruct`).
*   **Robustness**: Handles NaN/Inf values, special identifiers, and multi-line strings correctly.

## Comparison to `std.zon`

| Feature | zon.zig | std.zon |
| :--- | :--- | :--- |
| **Model** | **Document Object Model** (Tree) | **Struct Deserialization** |
| **Editing** | ✅ First-class support (Read-Modify-Write) | ❌ Read-only (typically) |
| **Unknown Keys** | ✅ Preserved and accessible | ❌ Ignored or errors |
| **Type Safety** | Runtime checks (returns Optional/Error) | Compile-time checks |
| **Use Case** | **Tools, Editors, Dynamic Configs** | **Application Loading, Static Configs** |

## When to choose zon.zig?

*   You are matching a `build.zig.zon` file and want to add a dependency programmatically.
*   You are writing a CLI that updates a configuration file (e.g., changing a version number).
*   You need to merge multiple ZON files (e.g., `default.zon` + `user.zon`).
*   You are prototyping and the schema is changing rapidly.

## When to choose `std.zon`?

*   You just need to load your app's configuration at startup.
*   You want strict validation that the input matches exactly your expected struct.
*   You are in a constrained environment where heap allocation for a full document tree is undesirable.

## Getting Started

Ready to dive in? Check out the [Installation](./installation.md) guide or jump straight to [Basic Usage](./basic-usage.md).
