const std = @import("std");
const tetris = @import("tetris");
const rl = @import("raylib");
const Color = @import("raylib.color");

const BlockSize = 40;

const BlockType = enum {
    I,
    O,
    S,
    Z,
    J,
    L,
    T,
};

const BlockDef = struct {
    color: rl.Color,
    positions: [4][2]i32, // 4 squares, each with x,y offset
};

fn getBlockDef(block: BlockType) BlockDef {
    return switch (block) {
        .I => BlockDef{
            .color = rl.Color.sky_blue,
            .positions = .{
                .{ 0, 0 }, .{ 0, 1 }, .{ 0, 2 }, .{ 0, 3 },
            },
        },
        .O => BlockDef{
            .color = rl.Color.yellow,
            .positions = .{
                .{ 0, 0 }, .{ 1, 0 }, .{ 0, 1 }, .{ 1, 1 },
            },
        },
        .S => BlockDef{
            .color = rl.Color.green,
            .positions = .{
                .{ 1, 0 }, .{ 2, 0 }, .{ 0, 1 }, .{ 1, 1 },
            },
        },
        .Z => BlockDef{
            .color = rl.Color.red,
            .positions = .{
                .{ 0, 0 }, .{ 1, 0 }, .{ 1, 1 }, .{ 2, 1 },
            },
        },
        .J => BlockDef{
            .color = rl.Color.blue,
            .positions = .{
                .{ 0, 0 }, .{ 0, 1 }, .{ 0, 2 }, .{ 1, 2 },
            },
        },
        .L => BlockDef{
            .color = rl.Color.orange,
            .positions = .{
                .{ 1, 0 }, .{ 1, 1 }, .{ 1, 2 }, .{ 0, 2 },
            },
        },
        .T => BlockDef{
            .color = rl.Color.purple,
            .positions = .{
                .{ 0, 0 }, .{ 1, 0 }, .{ 2, 0 }, .{ 1, 1 },
            },
        },
    };
}

fn drawTetrisBlock(block: BlockType, origin_x: i32, origin_y: i32) void {
    const def = getBlockDef(block);
    for (def.positions) |pos| {
        const x = origin_x + (pos[0] * BlockSize);
        const y = origin_y + (pos[1] * BlockSize);
        rl.drawRectangle(
            x,
            y,
            BlockSize,
            BlockSize,
            def.color,
        );
        // Draw border for visual separation
        rl.drawRectangleLines(
            x,
            y,
            BlockSize,
            BlockSize,
            rl.Color.black,
        );
    }
}

const GridWidth: i32 = 10;
const GridHeight: i32 = 20;

const GameState = struct {
    active_block: BlockType,
    block_x: i32, // grid position
    block_y: i32, // grid position
    grid: [GridHeight][GridWidth]?BlockType, // null = empty, otherwise filled
    fall_timer: f32,
};

const FallInterval: f32 = 0.5;
const BlockStartOffset: i32 = 2;

fn getRandomBlock() BlockType {
    const block_types = [_]BlockType{ .I, .O, .S, .Z, .J, .L, .T };
    const rand_index = std.crypto.random.intRangeLessThan(usize, 0, block_types.len);
    return block_types[rand_index];
}

fn spawnRandomBlock(state: *GameState) void {
    state.active_block = getRandomBlock();
    state.block_x = GridWidth / 2 - BlockStartOffset;
    state.block_y = 0;
}

fn handleMovement(state: *GameState) void {
    if (rl.isKeyPressed(rl.KeyboardKey.left)) {
        if (canMoveBlock(state, -1, 0)) {
            state.block_x -= 1;
        }
    }
    if (rl.isKeyPressed(rl.KeyboardKey.right)) {
        if (canMoveBlock(state, 1, 0)) {
            state.block_x += 1;
        }
    }
    if (rl.isKeyDown(rl.KeyboardKey.down)) {
        // Drop block faster if possible
        if (canMoveBlock(state, 0, 1)) {
            state.block_y += 1;
            // Optionally, reset fall_timer to avoid double move in same frame
            state.fall_timer = 0.0;
        }
    }
}

fn canMoveBlock(state: *GameState, dx: i32, dy: i32) bool {
    const def = getBlockDef(state.active_block);
    for (def.positions) |pos| {
        const x = state.block_x + pos[0] + dx;
        const y = state.block_y + pos[1] + dy;
        // Check bounds
        if (x < 0 or x >= GridWidth or y < 0 or y >= GridHeight) return false;
        // For downward movement, check collision with placed blocks
        if (dy != 0 and state.grid[@intCast(y)][@intCast(x)] != null) return false;
    }
    return true;
}

fn placeBlock(state: *GameState) void {
    const def = getBlockDef(state.active_block);
    for (def.positions) |pos| {
        const x = state.block_x + pos[0];
        const y = state.block_y + pos[1];
        if (x >= 0 and x < GridWidth and y >= 0 and y < GridHeight) {
            state.grid[@intCast(y)][@intCast(x)] = state.active_block;
        }
    }
}

fn drawGrid(state: *GameState) void {
    for (state.grid, 0..) |row, y| {
        for (row, 0..) |cell, x| {
            if (cell) |block| {
                const def = getBlockDef(block);
                rl.drawRectangle(
                    @as(i32, @intCast(x)) * BlockSize,
                    @as(i32, @intCast(y)) * BlockSize,
                    BlockSize,
                    BlockSize,
                    def.color,
                );
                rl.drawRectangleLines(
                    @as(i32, @intCast(x)) * BlockSize,
                    @as(i32, @intCast(y)) * BlockSize,
                    BlockSize,
                    BlockSize,
                    rl.Color.black,
                );
            }
        }
    }
}

fn drawActiveBlock(state: *GameState) void {
    drawTetrisBlock(state.active_block, state.block_x * BlockSize, state.block_y * BlockSize);
}

pub fn main() !void {
    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = GridWidth * BlockSize;
    const screenHeight = GridHeight * BlockSize;

    rl.initWindow(screenWidth, screenHeight, "Tetris Clone");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    var state = GameState{
        .active_block = getRandomBlock(),
        .block_x = GridWidth / 2 - 2,
        .block_y = 0,
        .grid = [_][GridWidth]?BlockType{[_]?BlockType{null} ** GridWidth} ** GridHeight,
        .fall_timer = 0.0,
    };

    // Main game loop
    while (!rl.windowShouldClose()) {
        // Update
        state.fall_timer += rl.getFrameTime();
        handleMovement(&state);
        if (state.fall_timer > FallInterval) {
            if (canMoveBlock(&state, 0, 1)) {
                state.block_y += 1;
            } else {
                placeBlock(&state);
                spawnRandomBlock(&state);
            }
            state.fall_timer = 0.0;
        }

        // Draw
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.black);
        drawGrid(&state);
        drawActiveBlock(&state);
    }
}

// test "simple test" {
//     var list = std.ArrayList(i32).init(std.testing.allocator);
//     defer list.deinit(); // Try commenting this out and see if zig detects the memory leak!
//     try list.append(42);
//     try std.testing.expectEqual(@as(i32, 42), list.pop());
// }
//
// test "fuzz example" {
//     const Context = struct {
//         fn testOne(context: @This(), input: []const u8) anyerror!void {
//             _ = context;
//             // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
//             try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
//         }
//     };
//     try std.testing.fuzz(Context{}, Context.testOne, .{});
// }
