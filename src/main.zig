const std = @import("std");
const tetris = @import("tetris");
const rl = @import("raylib");

// Game configuration constants
const GRID_WIDTH: i32 = 10;
const GRID_HEIGHT: i32 = 20;
const BLOCK_SIZE: i32 = 40;
const FALL_INTERVAL: f32 = 0.5;
const BLOCK_START_OFFSET: i32 = 2;
const SCREEN_WIDTH = GRID_WIDTH * BLOCK_SIZE;
const SCREEN_HEIGHT = GRID_HEIGHT * BLOCK_SIZE;

const BlockType = enum {
    I,
    O,
    S,
    Z,
    J,
    L,
    T,

    pub fn getRandom() BlockType {
        const block_types = [_]BlockType{ .I, .O, .S, .Z, .J, .L, .T };
        const rand_index = std.crypto.random.intRangeLessThan(usize, 0, block_types.len);
        return block_types[rand_index];
    }
};

// Active block struct
const ActiveBlock = struct {
    block_type: BlockType,
    x: i32, // grid position
    y: i32, // grid position
};

// Game state struct
const GameState = struct {
    active_block: ActiveBlock,
    grid: [GRID_HEIGHT][GRID_WIDTH]?BlockType, // null = empty, otherwise filled
    fall_timer: f32,
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

// Helper to initialize the grid
fn initGrid() [GRID_HEIGHT][GRID_WIDTH]?BlockType {
    return [_][GRID_WIDTH]?BlockType{[_]?BlockType{null} ** GRID_WIDTH} ** GRID_HEIGHT;
}

fn spawnRandomBlock(state: *GameState) void {
    const active_block = ActiveBlock{
        .block_type = BlockType.getRandom(),
        .x = GRID_WIDTH / 2 - BLOCK_START_OFFSET,
        .y = 0,
    };
    state.active_block = active_block;
}

fn handleMovement(state: *GameState) void {
    if (rl.isKeyPressed(rl.KeyboardKey.left)) {
        if (canMoveBlock(state, -1, 0)) {
            state.active_block.x -= 1;
        }
    }
    if (rl.isKeyPressed(rl.KeyboardKey.right)) {
        if (canMoveBlock(state, 1, 0)) {
            state.active_block.x += 1;
        }
    }
    if (rl.isKeyDown(rl.KeyboardKey.down)) {
        // Drop block faster if possible
        if (canMoveBlock(state, 0, 1)) {
            state.active_block.y += 1;
            // Optionally, reset fall_timer to avoid double move in same frame
            state.fall_timer = 0.0;
        }
    }
}

fn canMoveBlock(state: *GameState, dx: i32, dy: i32) bool {
    const def = getBlockDef(state.active_block.block_type);
    for (def.positions) |pos| {
        const x = state.active_block.x + pos[0] + dx;
        const y = state.active_block.y + pos[1] + dy;
        // Check bounds
        if (x < 0 or x >= GRID_WIDTH or y < 0 or y >= GRID_HEIGHT) return false;
        // For downward movement, check collision with placed blocks
        if (dy != 0 and state.grid[@intCast(y)][@intCast(x)] != null) return false;
    }
    return true;
}

fn placeBlock(state: *GameState) void {
    const def = getBlockDef(state.active_block.block_type);
    for (def.positions) |pos| {
        const x = state.active_block.x + pos[0];
        const y = state.active_block.y + pos[1];
        if (x >= 0 and x < GRID_WIDTH and y >= 0 and y < GRID_HEIGHT) {
            state.grid[@intCast(y)][@intCast(x)] = state.active_block.block_type;
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
    drawTetrisBlock(state.active_block.block_type, state.active_block.x * BLOCK_SIZE, state.active_block.y * BLOCK_SIZE);
}

// Main game loop
pub fn main() !void {
    // Initialization
    rl.initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Tetris Clone");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    const activeBlock = ActiveBlock{
        .block_type = BlockType.getRandom(),
        .x = GRID_WIDTH / 2 - BLOCK_START_OFFSET,
        .y = 0,
    };

    var state = GameState{
        .active_block = activeBlock,
        .grid = initGrid(),
        .fall_timer = 0.0,
    };

    while (!rl.windowShouldClose()) {
        // Update
        state.fall_timer += rl.getFrameTime();
        handleMovement(&state);
        if (state.fall_timer > FALL_INTERVAL) {
            if (canMoveBlock(&state, 0, 1)) {
                state.active_block.y += 1;
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