const std = @import("std");
const tetris = @import("tetris");
const rl = @import("raylib");
const b = @import("block.zig"); // Import the BlockDefinition struct from block.zig
const print = std.debug.print;

// Game configuration constants
const GRID_WIDTH: i32 = 10;
const GRID_HEIGHT: i32 = 20;
const BLOCK_SIZE: i32 = 40;
const FALL_INTERVAL: f32 = 0.5;
const BLOCK_START_OFFSET: i32 = 2;
const SIDEBAR_WIDTH: i32 = 200; // Width of the sidebar for score display
const SCREEN_WIDTH = GRID_WIDTH * BLOCK_SIZE + SIDEBAR_WIDTH;
const SCREEN_HEIGHT = GRID_HEIGHT * BLOCK_SIZE;

const Grid = [GRID_HEIGHT][GRID_WIDTH]?b.BlockType;

const ActiveBlock = struct {
    block_definition: b.BlockDefinition,
    x: i32, // grid position
    y: i32, // grid position
};

const GameState = struct {
    active_block: ActiveBlock,
    grid: Grid,
    fall_timer: f32,
    score: u32 = 0, // Score for cleared lines
};

fn drawTetrisBlock(block: *b.BlockDefinition, origin_x: i32, origin_y: i32, alpha: u8) void {
    const blockRef: b.BlockDefinition = block.*;
    const positions: b.blockPosition = blockRef.applyRotation(blockRef.rotation).positions;

    for (positions, 0..) |row, i| {
        const rowI = @as(i32, @intCast(i));
        for (row, 0..) |cell, j| {
            const colI = @as(i32, @intCast(j));
            if (cell != 1) continue;
            const x: i32 = (origin_x + colI) * BLOCK_SIZE;
            const y: i32 = (origin_y + rowI) * BLOCK_SIZE;
            var color = block.color;
            color.a = alpha;
            rl.drawRectangle(x, y, BLOCK_SIZE, BLOCK_SIZE, color);
            rl.drawRectangleLines(x, y, BLOCK_SIZE, BLOCK_SIZE, rl.Color.black);
        }
    }
}

fn spawnRandomBlock(state: *GameState) void {
    const active_block = ActiveBlock{
        .block_definition = b.BlockDefinition.getRandom(),
        .x = GRID_WIDTH / 2 - BLOCK_START_OFFSET,
        .y = 0,
    };
    state.active_block = active_block;
}

fn handleMovement(state: *GameState) void {
    if (rl.isKeyPressed(rl.KeyboardKey.left)) {
        if (canMoveBlock(state.active_block, state.grid, -1, 0)) {
            state.active_block.x -= 1;
        }
    }
    if (rl.isKeyPressed(rl.KeyboardKey.right)) {
        if (canMoveBlock(state.active_block, state.grid, 1, 0)) {
            state.active_block.x += 1;
        }
    }
    if (rl.isKeyDown(rl.KeyboardKey.down)) {
        if (canMoveBlock(state.active_block, state.grid, 0, 1)) {
            state.active_block.y += 1;
            // Optionally, reset fall_timer to avoid double move in same frame
            state.fall_timer = 0.0;
        }
    }
    if (rl.isKeyPressed(rl.KeyboardKey.up)) {
        // TODO: Fix this ugly casting logic
        const new_rotation: u2 = @as(u2, @intCast((@as(u4, state.active_block.block_definition.rotation) + 1) % 4));
        if (canRotateBlock(state, new_rotation)) {
            state.active_block.block_definition.rotation = new_rotation;
        }
    }
    if (rl.isKeyPressed(rl.KeyboardKey.space)) {
        while (canMoveBlock(state.active_block, state.grid, 0, 1)) {
            state.active_block.y += 1;
        }
        placeBlock(state.active_block, &state.grid);
        clearFullLines(state);
        spawnRandomBlock(state);
        state.fall_timer = 0.0;
    }
}

fn canMoveBlock(activeBlock: ActiveBlock, grid: Grid, dx: i32, dy: i32) bool {
    const blockDef = activeBlock.block_definition.applyRotation(activeBlock.block_definition.rotation);
    for (blockDef.positions, 0..) |row, rowI| {
        for (row, 0..) |cell, colI| {
            if (cell != 1) continue;
            const x = activeBlock.x + @as(i32, @intCast(colI)) + dx;
            const y = activeBlock.y + @as(i32, @intCast(rowI)) + dy;
            if (x < 0 or x >= GRID_WIDTH or y < 0 or y >= GRID_HEIGHT) return false;
            if (grid[@intCast(y)][@intCast(x)] != null) return false;
        }
    }
    return true;
}

fn canRotateBlock(state: *GameState, new_rotation: u2) bool {
    const positions = state.active_block.block_definition.applyRotation(new_rotation).positions;

    for (positions) |pos| {
        const x = state.active_block.x + pos[0];
        const y = state.active_block.y + pos[1];
        // Check bounds
        if (x < 0 or x >= GRID_WIDTH or y < 0 or y >= GRID_HEIGHT) return false;
        // Check collision with placed blocks
        if (state.grid[@intCast(y)][@intCast(x)] != null) return false;
    }
    return true;
}

fn placeBlock(activeBlock: ActiveBlock, grid: *Grid) void {
    const blockDef = activeBlock.block_definition.applyRotation(activeBlock.block_definition.rotation);
    for (blockDef.positions, 0..) |row, rowI| {
        for (row, 0..) |cell, colI| {
            if (cell != 1) continue;
            const x = activeBlock.x + @as(i32, @intCast(colI));
            const y = activeBlock.y + @as(i32, @intCast(rowI));
            if (x >= 0 and x < GRID_WIDTH and y >= 0 and y < GRID_HEIGHT) {
                grid[@intCast(y)][@intCast(x)] = blockDef.block_type;
            }
        }
    }
}

fn clearFullLines(state: *GameState) void {
    var y: i32 = GRID_HEIGHT - 1;
    var linesCleared: u16 = 0;
    while (y >= 0) : (y -= 1) {
        var is_full = true;
        for (state.grid[@intCast(y)]) |cell| {
            if (cell == null) {
                is_full = false;
                break;
            }
        }
        if (is_full) {
            linesCleared += 1;
            // Clear the line and move everything above down
            var row = y;
            while (row > 0) : (row -= 1) {
                state.grid[@intCast(row)] = state.grid[@intCast(row - 1)];
            }
            // Clear the top row
            state.grid[0] = [_]?b.BlockType{null} ** GRID_WIDTH;
            // Stay at same y to check the new line at this position
            y += 1;
        }
    }

    state.score += 100 * @as(u32, linesCleared);
}

fn drawGrid(state: *GameState) void {
    for (state.grid, 0..) |row, y| {
        for (row, 0..) |cell, x| {
            if (cell) |block| {
                const def = b.getBlockDefinition(block);
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

fn drawActiveBlock(activeBlock: *ActiveBlock) void {
    drawTetrisBlock(
        &activeBlock.block_definition,
        activeBlock.x,
        activeBlock.y,
        255,
    );
}

// Draw the score in the sidebar
fn drawSidebar(score: u32) void {
    const sidebar_x = GRID_WIDTH * BLOCK_SIZE;
    // Draw sidebar background
    rl.drawRectangle(
        sidebar_x,
        0,
        SIDEBAR_WIDTH,
        SCREEN_HEIGHT,
        rl.Color.dark_gray, // Choose a distinct color
    );
    // Draw score text
    const text_x = sidebar_x + (SIDEBAR_WIDTH / 4);
    rl.drawText("Score:", text_x, 40, 32, rl.Color.white);
    var score_buf: [16]u8 = undefined;
    const score_str = std.fmt.bufPrintZ(&score_buf, "{d}", .{score}) catch "0";
    rl.drawText(score_str, text_x, 80, 32, rl.Color.yellow);
}

fn getBlockDropLocationPreview(activeBlock: ActiveBlock, grid: Grid) i32 {
    var preview = activeBlock;

    while (true) {
        const can_move = canMoveBlock(preview, grid, 0, 1);
        if (!can_move) break;
        preview.y += 1;
    }
    return preview.y;
}

fn drawBlockPreview(state: *GameState) void {
    var preview_block = state.active_block;
    preview_block.y = getBlockDropLocationPreview(state.active_block, state.grid);

    drawTetrisBlock(
        &preview_block.block_definition,
        preview_block.x,
        preview_block.y,
        100,
    );
}

// Main game loop
pub fn main() !void {
    // Initialization
    rl.initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Tetris Clone");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    const activeBlock = ActiveBlock{
        .block_definition = b.BlockDefinition.getRandom(),
        .x = GRID_WIDTH / 2 - BLOCK_START_OFFSET,
        .y = 0,
    };

    var state = GameState{
        .active_block = activeBlock,
        .grid = [_][GRID_WIDTH]?b.BlockType{[_]?b.BlockType{null} ** GRID_WIDTH} ** GRID_HEIGHT,
        .fall_timer = 0.0,
    };

    while (!rl.windowShouldClose()) {
        // Update
        state.fall_timer += rl.getFrameTime();
        handleMovement(&state);
        if (state.fall_timer > FALL_INTERVAL) {
            if (canMoveBlock(state.active_block, state.grid, 0, 1)) {
                state.active_block.y += 1;
            } else {
                placeBlock(state.active_block, &state.grid);
                clearFullLines(&state);
                spawnRandomBlock(&state);
            }
            state.fall_timer = 0.0;
        }

        // Draw
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(rl.Color.black);
        drawGrid(&state);
        drawBlockPreview(&state);
        drawActiveBlock(&state.active_block);
        drawSidebar(state.score);
        // TODO: Fix rotation / wall kicks / can rotate into other blocks
        // TODO: Die when blocks reach top
        // TODO: Next block incoming?
        // TODO: Save blocks
        // TODO: Use bag randomizer for blocks, so all blocks are used before repeating
    }
}
