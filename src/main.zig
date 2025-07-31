const std = @import("std");
const tetris = @import("tetris");
const rl = @import("raylib");
const Color = @import("raylib.color");

// Game configuration constants
const GRID_WIDTH: i32 = 10;
const GRID_HEIGHT: i32 = 20;
const BLOCK_SIZE: i32 = 40;
const FALL_INTERVAL: f32 = 0.5;
const BLOCK_START_OFFSET: i32 = 2;

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
        const x = origin_x + (pos[0] * BLOCK_SIZE);
        const y = origin_y + (pos[1] * BLOCK_SIZE);
        rl.drawRectangle(
            x,
            y,
            BLOCK_SIZE,
            BLOCK_SIZE,
            def.color,
        );
        // Draw border for visual separation
        rl.drawRectangleLines(
            x,
            y,
            BLOCK_SIZE,
            BLOCK_SIZE,
            rl.Color.black,
        );
    }
}

// Game state struct
const GameState = struct {
    active_block: BlockType,
    block_x: i32, // grid position
    block_y: i32, // grid position
    grid: [GRID_HEIGHT][GRID_WIDTH]?BlockType, // null = empty, otherwise filled
    fall_timer: f32,
};

// Helper to initialize the grid
fn initGrid() [GRID_HEIGHT][GRID_WIDTH]?BlockType {
    return [_][GRID_WIDTH]?BlockType{[_]?BlockType{null} ** GRID_WIDTH} ** GRID_HEIGHT;
}

fn getRandomBlock() BlockType {
    const block_types = [_]BlockType{ .I, .O, .S, .Z, .J, .L, .T };
    const rand_index = std.crypto.random.intRangeLessThan(usize, 0, block_types.len);
    return block_types[rand_index];
}

fn spawnRandomBlock(state: *GameState) void {
    state.active_block = getRandomBlock();
    state.block_x = GRID_WIDTH / 2 - BLOCK_START_OFFSET;
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
        if (x < 0 or x >= GRID_WIDTH or y < 0 or y >= GRID_HEIGHT) return false;
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
        if (x >= 0 and x < GRID_WIDTH and y >= 0 and y < GRID_HEIGHT) {
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
                    @as(i32, @intCast(x)) * BLOCK_SIZE,
                    @as(i32, @intCast(y)) * BLOCK_SIZE,
                    BLOCK_SIZE,
                    BLOCK_SIZE,
                    def.color,
                );
                rl.drawRectangleLines(
                    @as(i32, @intCast(x)) * BLOCK_SIZE,
                    @as(i32, @intCast(y)) * BLOCK_SIZE,
                    BLOCK_SIZE,
                    BLOCK_SIZE,
                    rl.Color.black,
                );
            }
        }
    }
}

fn drawActiveBlock(state: *GameState) void {
    drawTetrisBlock(state.active_block, state.block_x * BLOCK_SIZE, state.block_y * BLOCK_SIZE);
}

// Main game loop
pub fn main() !void {
    // Initialization
    const screenWidth = GRID_WIDTH * BLOCK_SIZE;
    const screenHeight = GRID_HEIGHT * BLOCK_SIZE;
    rl.initWindow(screenWidth, screenHeight, "Tetris Clone");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    var state = GameState{
        .active_block = getRandomBlock(),
        .block_x = GRID_WIDTH / 2 - BLOCK_START_OFFSET,
        .block_y = 0,
        .grid = initGrid(),
        .fall_timer = 0.0,
    };

    while (!rl.windowShouldClose()) {
        // Update
        state.fall_timer += rl.getFrameTime();
        handleMovement(&state);
        if (state.fall_timer > FALL_INTERVAL) {
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
