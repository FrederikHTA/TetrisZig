const std = @import("std");

pub const LeaderboardEntry = struct {
    name: [16]u8, // Player name (fixed size for simplicity)
    score: u32,
};

pub const MaxEntries = 10;
pub const LeaderboardFileName = "leaderboard.txt";
pub const OutputFolder = "output";

fn createFile() !void {
    const cwd: std.fs.Dir = std.fs.cwd();

    cwd.makeDir(OutputFolder) catch |e| switch (e) {
        error.PathAlreadyExists => {},
        else => return e,
    };

    var output_dir: std.fs.Dir = try cwd.openDir(OutputFolder, .{});
    defer output_dir.close();

    const file: std.fs.File = try output_dir.createFile(LeaderboardFileName, .{});
    defer file.close();

    const byte_written = try file.write("It's zigling time!");
    std.debug.print("Successfully wrote {d} bytes.\n", .{byte_written});
}

fn readFromFile() !void {
    const path = try std.fs.path.join(&.{OutputFolder, LeaderboardFileName});
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    
    var buffer: [64]u8 = undefined;
    const bytesRead = try file.read(buffer[0..]);
    const content = buffer[0..bytesRead];
    std.debug.print("File content: {s}", .{content});
}

