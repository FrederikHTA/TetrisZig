const std = @import("std");
const tetris = @import("tetris");
const rl = @import("raylib");
const b = @import("block.zig");
const bag = @import("bag.zig");
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
    score: u32 = 0,
    block_bag: bag.BlockBag,
    saved_block: ?b.BlockType = null,

    pub fn init() GameState {
        var blockBag = bag.BlockBag.init();
        const activeBlock = ActiveBlock{
            .block_definition = b.getBlockDefinition(blockBag.draw()),
            .x = GRID_WIDTH / 2 - BLOCK_START_OFFSET,
            .y = 0,
        };

        const state = GameState{
            .active_block = activeBlock,
            .grid = [_][GRID_WIDTH]?b.BlockType{[_]?b.BlockType{null} ** GRID_WIDTH} ** GRID_HEIGHT,
            .fall_timer = 0.0,
            .block_bag = blockBag,
        };
        return state;
    }
};

fn spawnNextBlock(state: *GameState) void {
    const block_type = state.block_bag.draw();
    const active_block = ActiveBlock{
        .block_definition = b.getBlockDefinition(block_type),
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
        const can_rotate = canRotateBlockWithWallKick(state, new_rotation);
        if (can_rotate.success) {
            state.active_block.block_definition.rotation = new_rotation;
            state.active_block.x += can_rotate.x_offset;
        }
    }
    if (rl.isKeyPressed(rl.KeyboardKey.space)) {
        while (canMoveBlock(state.active_block, state.grid, 0, 1)) {
            state.active_block.y += 1;
        }
        placeBlock(state.active_block, &state.grid);
        clearFullLines(state);
        spawnNextBlock(state);
        state.fall_timer = 0.0;
    }
    if (rl.isKeyPressed(rl.KeyboardKey.s)) {
        if (state.saved_block) |saved_block| {
            // If there's a saved block, swap it with the current active block
            state.active_block.block_definition = b.getBlockDefinition(saved_block);
            state.saved_block = null;
        } else {
            // Save the current active block
            state.saved_block = state.active_block.block_definition.block_type;
            spawnNextBlock(state);
        }
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

fn canRotateBlockWithWallKick(state: *GameState, new_rotation: u2) struct { success: bool, x_offset: i32 } {
    const kicks = [_]i8{ 0, -1, 1, -2, 2 };
    for (kicks) |dx| {
        var preview = state.active_block;
        // preview.x += dx;
        preview.block_definition.rotation = new_rotation;
        if (canMoveBlock(preview, state.grid, dx, 0)) {
            return .{ .success = true, .x_offset = dx };
        }
    }
    return .{ .success = false, .x_offset = 0 };
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

fn getBlockDropLocationPreview(activeBlock: ActiveBlock, grid: Grid) i32 {
    var preview = activeBlock;

    while (true) {
        const can_move = canMoveBlock(preview, grid, 0, 1);
        if (!can_move) break;
        preview.y += 1;
    }
    return preview.y;
}

fn drawGrid(grid: Grid) void {
    for (grid, 0..) |row, y| {
        for (row, 0..) |cell, x| {
            rl.drawRectangleLines(
                @as(i32, @intCast(x)) * BLOCK_SIZE,
                @as(i32, @intCast(y)) * BLOCK_SIZE,
                BLOCK_SIZE,
                BLOCK_SIZE,
                rl.Color.dark_gray.alpha(0.5),
            );

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
    drawBlock(
        activeBlock.block_definition,
        activeBlock.x,
        activeBlock.y,
        255,
    );
}

fn drawSidebar(score: u32, next_block: b.BlockType, saved_block: ?b.BlockType) void {
    const sidebar_x = GRID_WIDTH * BLOCK_SIZE;
    rl.drawRectangle(
        sidebar_x,
        0,
        SIDEBAR_WIDTH,
        SCREEN_HEIGHT,
        rl.Color.dark_gray,
    );
    const text_x = sidebar_x + (SIDEBAR_WIDTH / 4);
    rl.drawText("Score:", text_x, 40, 32, rl.Color.white);
    var score_buf: [16]u8 = undefined;
    const score_str = std.fmt.bufPrintZ(&score_buf, "{d}", .{score}) catch "0";
    rl.drawText(score_str, text_x, 80, 32, rl.Color.yellow);

    // Draw next piece preview
    const block_preview_x = sidebar_x + (SIDEBAR_WIDTH / 2) - (1 * BLOCK_SIZE);

    rl.drawText("Next:", text_x, 140, 32, rl.Color.white);
    const next_def = b.getBlockDefinition(next_block);
    drawBlock(next_def, block_preview_x / BLOCK_SIZE, 200 / BLOCK_SIZE, 255);

    // Center the saved piece preview in the sidebar
    // Draw next block preview
    rl.drawText("Saved:", text_x, 300, 32, rl.Color.white);
    if (saved_block) |block| {
        // If there's a saved block, draw it
        const preview_def = b.getBlockDefinition(block);
        drawBlock(preview_def, block_preview_x / BLOCK_SIZE, 360 / BLOCK_SIZE, 255);
    }
}

fn drawBlock(block: b.BlockDefinition, origin_x: i32, origin_y: i32, alpha: u8) void {
    const positions: b.blockPosition = block.applyRotation(block.rotation).positions;

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

fn drawBlockPreview(activeBlock: ActiveBlock, grid: Grid) void {
    var preview_block = activeBlock;
    preview_block.y = getBlockDropLocationPreview(activeBlock, grid);

    drawBlock(
        preview_block.block_definition,
        preview_block.x,
        preview_block.y,
        100,
    );
}

const GameScreen = enum { Start, Playing, Death };

fn isGameOver(grid: Grid) bool {
    // If any cell in the top row is filled, game over
    for (grid[0]) |cell| {
        if (cell != null) return true;
    }
    return false;
}

pub fn main() !void {
    rl.initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Tetris Clone");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    var state = GameState.init();
    var screen: GameScreen = GameScreen.Start;

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(rl.Color.black);

        switch (screen) {
            GameScreen.Start => {
                // Draw Tetris logo
                const logo_text = "TETRIS";
                const logo_font_size = 80;
                const logo_width = rl.measureText(logo_text, logo_font_size);
                rl.drawText(
                    logo_text,
                    @divTrunc(SCREEN_WIDTH - logo_width, 2),
                    SCREEN_HEIGHT / 3,
                    logo_font_size,
                    rl.Color.yellow,
                );
                const btn_w = 240;
                const btn_h = 60;
                const btn_x = (SCREEN_WIDTH - btn_w) / 2;
                const btn_y = SCREEN_HEIGHT / 2;
                const mouse = rl.getMousePosition();
                const hovered = mouse.x >= btn_x and mouse.x <= btn_x + btn_w and mouse.y >= btn_y and mouse.y <= btn_y + btn_h;
                rl.drawRectangle(
                    btn_x,
                    btn_y,
                    btn_w,
                    btn_h,
                    if (hovered) rl.Color.light_gray else rl.Color.gray,
                );
                rl.drawText("Start Game", btn_x + 32, btn_y + 12, 32, rl.Color.black);
                if (hovered and rl.isMouseButtonPressed(rl.MouseButton.left)) {
                    state = GameState.init();
                    screen = GameScreen.Playing;
                }
            },
            GameScreen.Playing => {
                state.fall_timer += rl.getFrameTime();
                handleMovement(&state);
                if (state.fall_timer > FALL_INTERVAL) {
                    if (canMoveBlock(state.active_block, state.grid, 0, 1)) {
                        state.active_block.y += 1;
                    } else {
                        placeBlock(state.active_block, &state.grid);
                        clearFullLines(&state);
                        spawnNextBlock(&state);
                        if (isGameOver(state.grid)) {
                            screen = GameScreen.Death;
                        }
                    }
                    state.fall_timer = 0.0;
                }
                drawGrid(state.grid);
                drawBlockPreview(state.active_block, state.grid);
                drawActiveBlock(&state.active_block);
                drawSidebar(state.score, state.block_bag.next_piece, state.saved_block);
            },
            GameScreen.Death => {
                // Draw death screen
                const lost_text = "YOU LOST";
                const lost_font_size = 64;
                const lost_width = rl.measureText(lost_text, lost_font_size);
                rl.drawText(
                    lost_text,
                    @divTrunc(SCREEN_WIDTH - lost_width, 2),
                    SCREEN_HEIGHT / 3,
                    lost_font_size,
                    rl.Color.red,
                );
                // Retry button
                const btn_w = 180;
                const btn_h = 50;
                const btn_x = (SCREEN_WIDTH - btn_w) / 2;
                const btn_y = SCREEN_HEIGHT / 2;
                const mouse = rl.getMousePosition();
                const retry_hovered = mouse.x >= btn_x and mouse.x <= btn_x + btn_w and mouse.y >= btn_y and mouse.y <= btn_y + btn_h;
                rl.drawRectangle(
                    btn_x,
                    btn_y,
                    btn_w,
                    btn_h,
                    if (retry_hovered) rl.Color.light_gray else rl.Color.gray,
                );
                rl.drawText("Retry", btn_x + 40, btn_y + 10, 32, rl.Color.black);
                // Exit button
                const exit_btn_y = btn_y + btn_h + 20;
                const exit_hovered = mouse.x >= btn_x and mouse.x <= btn_x + btn_w and mouse.y >= exit_btn_y and mouse.y <= exit_btn_y + btn_h;
                rl.drawRectangle(
                    btn_x,
                    exit_btn_y,
                    btn_w,
                    btn_h,
                    if (exit_hovered) rl.Color.light_gray else rl.Color.gray,
                );
                rl.drawText("Exit", btn_x + 55, exit_btn_y + 10, 32, rl.Color.black);
                if (retry_hovered and rl.isMouseButtonPressed(rl.MouseButton.left)) {
                    state = GameState.init();
                    screen = GameScreen.Playing;
                }
                if (exit_hovered and rl.isMouseButtonPressed(rl.MouseButton.left)) {
                    break;
                }
            },
        }
    }
    // TODO: switching to saved block can cause the block to be placed in an invalid position
}
