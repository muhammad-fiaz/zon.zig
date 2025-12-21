const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Create the zon module
    const zon_module = b.createModule(.{
        .root_source_file = b.path("src/zon.zig"),
    });

    // Expose the module for external projects that depend on this package.
    // This allows users to do: `const zon = @import("zon");` in their code
    // after adding zon as a dependency and calling `dep.module("zon")` in their build.zig
    _ = b.addModule("zon", .{
        .root_source_file = b.path("src/zon.zig"),
    });

    const examples = [_]struct { name: []const u8, path: []const u8, skip_run_all: bool = false }{
        .{ .name = "basic", .path = "examples/basic.zig" },
        .{ .name = "package_manifest", .path = "examples/package_manifest.zig" },
        .{ .name = "find_replace", .path = "examples/find_replace.zig" },
        .{ .name = "arrays", .path = "examples/arrays.zig" },
        .{ .name = "pretty_print", .path = "examples/pretty_print.zig" },
        .{ .name = "merge_clone", .path = "examples/merge_clone.zig" },
        .{ .name = "config_management", .path = "examples/config_management.zig" },
        .{ .name = "error_handling", .path = "examples/error_handling.zig" },
        .{ .name = "file_operations", .path = "examples/file_operations.zig", .skip_run_all = false },
        .{ .name = "nested_creation", .path = "examples/nested_creation.zig" },
        .{ .name = "identifier_values", .path = "examples/identifier_values.zig" },
    };

    inline for (examples) |example| {
        const exe = b.addExecutable(.{
            .name = example.name,
            .root_module = b.createModule(.{
                .root_source_file = b.path(example.path),
                .target = target,
                .optimize = optimize,
            }),
        });
        exe.root_module.addImport("zon", zon_module);

        const install_exe = b.addInstallArtifact(exe, .{});
        const example_step = b.step("example-" ++ example.name, "Build " ++ example.name ++ " example");
        example_step.dependOn(&install_exe.step);

        // Add run step for each example
        const run_exe = b.addRunArtifact(exe);
        run_exe.step.dependOn(&install_exe.step);
        const run_step = b.step("run-" ++ example.name, "Run " ++ example.name ++ " example");
        run_step.dependOn(&run_exe.step);
    }

    // Create run-all-examples step that runs all examples sequentially
    const run_all_examples = b.step("run-all-examples", "Run all examples sequentially");
    var previous_run_step: ?*std.Build.Step = null;

    inline for (examples) |example| {
        if (example.skip_run_all) continue;
        const exe = b.addExecutable(.{
            .name = "run-all-" ++ example.name,
            .root_module = b.createModule(.{
                .root_source_file = b.path(example.path),
                .target = target,
                .optimize = optimize,
            }),
        });
        exe.root_module.addImport("zon", zon_module);

        const install_exe = b.addInstallArtifact(exe, .{});
        const run_exe = b.addRunArtifact(exe);
        run_exe.step.dependOn(&install_exe.step);

        // Make each run step depend on the previous run step to ensure sequential execution
        if (previous_run_step) |prev| {
            run_exe.step.dependOn(prev);
        }
        previous_run_step = &run_exe.step;
    }

    if (previous_run_step) |last| {
        run_all_examples.dependOn(last);
    }

    // Backward compatibility: "example" runs basic example
    const basic_exe = b.addExecutable(.{
        .name = "example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/basic.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    basic_exe.root_module.addImport("zon", zon_module);
    const run_basic = b.addRunArtifact(basic_exe);
    const example_step = b.step("example", "Run basic example");
    example_step.dependOn(&run_basic.step);

    // Alias: "examples" runs all examples
    const examples_step = b.step("examples", "Run all examples");
    examples_step.dependOn(run_all_examples);

    // Unit tests
    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/zon.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    // Create comprehensive test-all step that runs everything sequentially
    const test_all_step = b.step("test-all", "Run all tests and examples sequentially");

    // First run unit tests
    test_all_step.dependOn(test_step);

    // Then run all examples
    test_all_step.dependOn(run_all_examples);

    // Install step for library
    const lib = b.addLibrary(.{
        .name = "zon",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/zon.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(lib);
}
