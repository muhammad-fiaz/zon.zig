//! Library Version Information
//!
//! Provides compile-time version constants and comparison utilities
//! for the zon.zig library.

const std = @import("std");

/// Current library version.
pub const version = "0.0.5";

const version_semver = parsedVersion();

/// Semantic version components derived from `version`.
pub const major: u32 = @intCast(version_semver.major);
pub const minor: u32 = @intCast(version_semver.minor);
pub const patch: u32 = @intCast(version_semver.patch);

fn parsedVersion() std.SemanticVersion {
    return std.SemanticVersion.parse(version) catch unreachable;
}

/// Get the semantic version struct.
pub fn semanticVersion() std.SemanticVersion {
    return version_semver;
}

/// Get the full version string.
pub fn fullVersion() []const u8 {
    return getVersion();
}

/// Get the version string (alias).
pub fn getVersion() []const u8 {
    return version;
}

/// Get version info struct.
pub fn getVersionInfo() struct { major: u32, minor: u32, patch: u32, string: []const u8 } {
    return .{
        .major = major,
        .minor = minor,
        .patch = patch,
        .string = version,
    };
}

/// Compare two semantic version strings.
/// Returns: -1 if a < b, 0 if a == b, 1 if a > b
pub fn compareVersions(a: []const u8, b: []const u8) i8 {
    const ver_a = std.SemanticVersion.parse(a) catch return 0;
    const ver_b = std.SemanticVersion.parse(b) catch return 0;
    return switch (ver_a.order(ver_b)) {
        .lt => -1,
        .eq => 0,
        .gt => 1,
    };
}

/// Returns true if this library version is compatible with the required version.
/// Uses semver compatibility rules (0.x.x is breaking at any change).
pub fn isCompatible(required: []const u8) bool {
    const req = std.SemanticVersion.parse(required) catch return false;
    const current = version_semver;

    if (current.major == 0) {
        return current.major == req.major and current.minor == req.minor and current.patch >= req.patch;
    }
    return current.major == req.major and current.minor >= req.minor;
}

test "version constants" {
    try std.testing.expect(std.mem.eql(u8, version, "0.0.5"));
    try std.testing.expect(major == 0);
    try std.testing.expect(minor == 0);
    try std.testing.expect(patch == 5);
}

test "semantic version" {
    const sv = semanticVersion();
    try std.testing.expect(sv.major == 0);
    try std.testing.expect(sv.minor == 0);
    try std.testing.expect(sv.patch == 5);
}

test "version comparison" {
    try std.testing.expectEqual(@as(i8, 0), compareVersions("1.0.0", "1.0.0"));
    try std.testing.expectEqual(@as(i8, -1), compareVersions("1.0.0", "2.0.0"));
    try std.testing.expectEqual(@as(i8, 1), compareVersions("2.0.0", "1.0.0"));
    try std.testing.expectEqual(@as(i8, -1), compareVersions("1.0.0", "1.1.0"));
    try std.testing.expectEqual(@as(i8, 1), compareVersions("1.1.0", "1.0.0"));
}
