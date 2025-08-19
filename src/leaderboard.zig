const std = @import("std");

pub const LeaderboardEntry = struct {
    name: [16]u8, // Player name (fixed size for simplicity)
    score: u32,
};

pub const MaxEntries = 10;
pub const LeaderboardFile = "leaderboard.dat";

pub fn loadLeaderboard(allocator: std.mem.Allocator) ![]LeaderboardEntry {
    const entry_size = @sizeOf(LeaderboardEntry);
    var file = std.fs.cwd().openFile(LeaderboardFile, .{}) catch |err| {
        if (err == error.FileNotFound) return allocator.alloc(LeaderboardEntry, 0);
        return err;
    };
    defer file.close();

    const file_size = try file.getEndPos();
    if (file_size == 0) return allocator.alloc(LeaderboardEntry, 0);

    const max_bytes = @min(file_size, MaxEntries * entry_size);
    var buf = try allocator.alloc(u8, max_bytes);
    defer allocator.free(buf);

    const n = try file.reader().readAll(buf);
    const entry_count = n / entry_size;

    const entries = try allocator.alloc(LeaderboardEntry, entry_count);

    for (entries, 0..) |*entry, i| {
        const start = i * entry_size;
        const end = start + entry_size;
        @memcpy(std.mem.asBytes(entry), buf[start..end]);
    }

    return entries;
}

// @memcpy(std.mem.asBytes(&entries), buf[0 .. n]);

pub fn addScore(
    allocator: std.mem.Allocator,
    entries: []LeaderboardEntry,
    name: []const u8,
    score: u32,
) ![]LeaderboardEntry {
    var list = std.ArrayList(LeaderboardEntry).init(allocator);
    defer list.deinit();

    // Copy existing entries
    try list.appendSlice(entries);

    // Prepare new entry (truncate/pad name as needed)
    var entry: LeaderboardEntry = .{
        .name = [_]u8{0} ** 16,
        .score = score,
    };
    const name_len = @min(name.len, entry.name.len);
    // std.mem.copy(u8, entry.name[0..name_len], name[0..name_len]);
    @memcpy(entry.name[0..name_len], name[0..name_len]);

    try list.append(entry);

    // Sort descending by score
    std.mem.sort(LeaderboardEntry, list.items, {}, struct {
        pub fn lessThan(_: void, a: LeaderboardEntry, b: LeaderboardEntry) bool {
            return a.score > b.score;
        }
    }.lessThan);

    // Trim to MaxEntries
    if (list.items.len > MaxEntries) {
        list.items = list.items[0..MaxEntries];
    }

    return list.toOwnedSlice();
}

pub fn saveLeaderboard(entries: []const LeaderboardEntry) !void {
    var file = try std.fs.cwd().createFile(
        LeaderboardFile,
        .{ .truncate = true }
    );
    defer file.close();

    // Truncate file to zero length before writing
    try file.setEndPos(0);

    for (entries) |entry| {
        try file.writeAll(&entry.name);
        try file.writer().writeInt(u32, entry.score, .little);
    }
}

