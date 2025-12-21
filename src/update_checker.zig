//! Update Checker - Optional background update checking.

const std = @import("std");
const version = @import("version.zig");

pub const VersionRelation = enum {
    local_newer,
    remote_newer,
    equal,
    unknown,
};

pub const UpdateInfo = struct {
    available: bool,
    current_version: []const u8,
    latest_version: ?[]const u8,
    download_url: ?[]const u8,

    pub fn deinit(self: *UpdateInfo, allocator: std.mem.Allocator) void {
        if (self.latest_version) |v| allocator.free(v);
        if (self.download_url) |u| allocator.free(u);
    }
};

pub const UpdateConfig = struct {
    enabled: bool = true,
    timeout_ms: u64 = 3000,
    user_agent: []const u8 = "zon.zig-update-checker",
    /// Releases endpoint (defaults to GitHub releases latest for the repo)
    releases_endpoint: []const u8 = "https://api.github.com/repos/muhammad-fiaz/zon.zig/releases/latest",
};

pub var config: UpdateConfig = .{};

/// Override the releases endpoint (accepts a static string slice)
pub fn setReleasesEndpoint(url: []const u8) void {
    config.releases_endpoint = url;
}

/// Configure the update checker behavior.
pub fn configure(new_config: UpdateConfig) void {
    config = new_config;
}

var check_thread: ?std.Thread = null;
var check_result: ?UpdateInfo = null;
var result_mutex: std.Thread.Mutex = .{};

pub fn disableUpdateCheck() void {
    config.enabled = false;
}

pub fn enableUpdateCheck() void {
    config.enabled = true;
}

pub fn isUpdateCheckEnabled() bool {
    return config.enabled;
}

pub fn checkForUpdates(allocator: std.mem.Allocator) !UpdateInfo {
    if (!config.enabled) {
        return UpdateInfo{
            .available = false,
            .current_version = version.version,
            .latest_version = null,
            .download_url = null,
        };
    }

    var http_client = std.http.Client{ .allocator = allocator };
    defer http_client.deinit();

    const uri = std.Uri.parse(config.releases_endpoint) catch {
        return UpdateInfo{
            .available = false,
            .current_version = version.version,
            .latest_version = null,
            .download_url = null,
        };
    };

    var server_header_buffer: [16 * 1024]u8 = undefined;
    var req = http_client.open(.GET, uri, .{
        .extra_headers = &.{
            .{ .name = "User-Agent", .value = config.user_agent },
            .{ .name = "Accept", .value = "application/vnd.github.v3+json" },
        },
        .server_header_buffer = &server_header_buffer,
    }) catch {
        return UpdateInfo{
            .available = false,
            .current_version = version.version,
            .latest_version = null,
            .download_url = null,
        };
    };
    defer req.deinit();

    req.send() catch {
        return UpdateInfo{
            .available = false,
            .current_version = version.version,
            .latest_version = null,
            .download_url = null,
        };
    };

    req.wait() catch {
        return UpdateInfo{
            .available = false,
            .current_version = version.version,
            .latest_version = null,
            .download_url = null,
        };
    };

    if (req.status != .ok) {
        return UpdateInfo{
            .available = false,
            .current_version = version.version,
            .latest_version = null,
            .download_url = null,
        };
    }

    var body_buffer: std.ArrayListUnmanaged(u8) = .empty;
    defer body_buffer.deinit(allocator);

    var buf: [4096]u8 = undefined;
    while (true) {
        const n = req.reader().read(&buf) catch break;
        if (n == 0) break;
        body_buffer.appendSlice(allocator, buf[0..n]) catch break;
        if (body_buffer.items.len > 512 * 1024) break;
    }

    const parsed = std.json.parseFromSlice(struct {
        tag_name: []const u8,
        html_url: []const u8,
    }, allocator, body_buffer.items, .{ .ignore_unknown_fields = true }) catch {
        return UpdateInfo{
            .available = false,
            .current_version = version.version,
            .latest_version = null,
            .download_url = null,
        };
    };
    defer parsed.deinit();

    const latest = parseVersionTag(parsed.value.tag_name);
    const rel = compareVersions(latest);

    return UpdateInfo{
        .available = rel == .remote_newer,
        .current_version = version.version,
        .latest_version = allocator.dupe(u8, latest) catch null,
        .download_url = allocator.dupe(u8, parsed.value.html_url) catch null,
    };
}

fn backgroundCheck(allocator: std.mem.Allocator) void {
    const info = checkForUpdates(allocator) catch return;

    result_mutex.lock();
    defer result_mutex.unlock();
    check_result = info;
}

pub fn startBackgroundCheck(allocator: std.mem.Allocator) void {
    if (!config.enabled) return;
    if (check_thread != null) return;

    check_thread = std.Thread.spawn(.{}, backgroundCheck, .{allocator}) catch null;
}

pub fn checkAndNotify(allocator: std.mem.Allocator) void {
    if (!config.enabled) return;

    result_mutex.lock();
    const info = check_result;
    result_mutex.unlock();

    if (info) |i| {
        if (i.available) {
            if (i.latest_version) |latest| {
                std.debug.print(
                    "\n[zon.zig] Update available: {s} -> {s}\n" ++
                        "Download: https://github.com/muhammad-fiaz/zon.zig/releases/latest\n\n",
                    .{ i.current_version, latest },
                );
            }
        }
    } else {
        startBackgroundCheck(allocator);
    }
}

pub fn compareVersions(remote_version: []const u8) VersionRelation {
    const local = version.semanticVersion();
    const remote = std.SemanticVersion.parse(remote_version) catch return .unknown;

    if (local.major > remote.major) return .local_newer;
    if (local.major < remote.major) return .remote_newer;
    if (local.minor > remote.minor) return .local_newer;
    if (local.minor < remote.minor) return .remote_newer;
    if (local.patch > remote.patch) return .local_newer;
    if (local.patch < remote.patch) return .remote_newer;

    return .equal;
}

pub fn getCurrentVersion() []const u8 {
    return version.version;
}

pub fn parseVersionTag(tag: []const u8) []const u8 {
    if (tag.len > 0 and tag[0] == 'v') {
        return tag[1..];
    }
    return tag;
}

pub fn formatUpdateMessage(
    allocator: std.mem.Allocator,
    current: []const u8,
    latest: []const u8,
) ![]u8 {
    return std.fmt.allocPrint(
        allocator,
        "Update available: {s} -> {s}\n" ++
            "Download: https://github.com/muhammad-fiaz/zon.zig/releases/latest",
        .{ current, latest },
    );
}

test "version comparison - equal" {
    const result = compareVersions(version.version);
    try std.testing.expect(result == .equal);
}

test "version comparison - remote newer" {
    const result = compareVersions("1.0.0");
    try std.testing.expect(result == .remote_newer);
}

test "version comparison - local newer" {
    const result = compareVersions("0.0.0");
    try std.testing.expect(result == .local_newer);
}

test "current version" {
    const ver = getCurrentVersion();
    try std.testing.expectEqualStrings("0.0.3", ver);
}

test "version tag parsing" {
    try std.testing.expectEqualStrings("1.2.3", parseVersionTag("v1.2.3"));
    try std.testing.expectEqualStrings("1.2.3", parseVersionTag("1.2.3"));
}

test "disable update check" {
    disableUpdateCheck();
    try std.testing.expect(!isUpdateCheckEnabled());
    enableUpdateCheck();
    try std.testing.expect(isUpdateCheckEnabled());
}
