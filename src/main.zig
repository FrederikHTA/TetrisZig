const std = @import("std");
const rl = @import("raylib");
const b = @import("block.zig");
const game = @import("game.zig");
const render = @import("render.zig");
const screens = @import("screens.zig");

const FALL_INTERVAL: f32 = 0.5;
const BLOCK_SIZE: i32 = 40;
const SIDEBAR_WIDTH: i32 = 200;
const GRID_WIDTH: i32 = 10;
const GRID_HEIGHT: i32 = 20;
const SCREEN_WIDTH = GRID_WIDTH * BLOCK_SIZE + SIDEBAR_WIDTH;
const SCREEN_HEIGHT = GRID_HEIGHT * BLOCK_SIZE;

pub fn main() !void {
    rl.initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Tetris Clone");
    defer rl.closeWindow();
    rl.setTargetFPS(60);

    var state = game.GameState.init();
    var screen: screens.GameScreen = screens.GameScreen.Start;

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(rl.Color.black);

        switch (screen) {
            screens.GameScreen.Start => {
                var startClicked = false;
                screens.drawStartScreen(&startClicked);
                if (startClicked) {
                    state = game.GameState.init();
                    screen = screens.GameScreen.Playing;
                }
            },
            screens.GameScreen.Playing => {
                state.fall_timer += rl.getFrameTime();
                handleMovement(&state);
                if (state.fall_timer > FALL_INTERVAL) {
                    if (game.canMoveBlock(state.active_block, state.grid, 0, 1)) {
                        state.active_block.y += 1;
                    } else {
                        game.placeBlock(state.active_block, &state.grid);
                        game.clearFullLines(&state);
                        game.spawnNextBlock(&state);
                        if (game.isGameOver(state.grid)) {
                            screen = screens.GameScreen.Death;
                        }
                    }
                    state.fall_timer = 0.0;
                }
                render.drawGrid(state.grid);
                render.drawBlockPreview(state.active_block, state.grid, getBlockDropLocationPreview);
                render.drawBlock(state.active_block.block_definition, state.active_block.x, state.active_block.y, 255);
                render.drawSidebar(state.score, state.block_bag.next_piece, state.saved_block);
            },
            screens.GameScreen.Death => {
                var retryClicked = false;
                var exitClicked = false;
                screens.drawDeathScreen(&retryClicked, &exitClicked);
                if (retryClicked) {
                    state = game.GameState.init();
                    screen = screens.GameScreen.Playing;
                }
                if (exitClicked) {
                    break;
                }
            },
        }
    }
}

fn handleMovement(state: *game.GameState) void {
    if (rl.isKeyPressed(rl.KeyboardKey.left)) {
        if (game.canMoveBlock(state.active_block, state.grid, -1, 0)) {
            state.active_block.x -= 1;
        }
    }
    if (rl.isKeyPressed(rl.KeyboardKey.right)) {
        if (game.canMoveBlock(state.active_block, state.grid, 1, 0)) {
            state.active_block.x += 1;
        }
    }
    if (rl.isKeyDown(rl.KeyboardKey.down)) {
        if (game.canMoveBlock(state.active_block, state.grid, 0, 1)) {
            state.active_block.y += 1;
            state.fall_timer = 0.0;
        }
    }
    if (rl.isKeyPressed(rl.KeyboardKey.up)) {
        const new_rotation: u2 = @as(u2, @intCast((@as(u4, state.active_block.block_definition.rotation) + 1) % 4));
        const can_rotate = game.canRotateBlockWithWallKick(state.active_block, state.grid, new_rotation);
        if (can_rotate.success) {
            state.active_block.block_definition.rotation = new_rotation;
            state.active_block.x += can_rotate.x_offset;
        }
    }
    if (rl.isKeyPressed(rl.KeyboardKey.space)) {
        while (game.canMoveBlock(state.active_block, state.grid, 0, 1)) {
            state.active_block.y += 1;
        }
        game.placeBlock(state.active_block, &state.grid);
        game.clearFullLines(state);
        game.spawnNextBlock(state);
        state.fall_timer = 0.0;
    }
    if (rl.isKeyPressed(rl.KeyboardKey.s)) {
        if (state.saved_block) |saved_block| {
            const block_definition = b.getBlockDefinition(saved_block);
            var saved_active_block = state.active_block;
            saved_active_block.block_definition = block_definition;

            const can_rotate = game.canRotateBlockWithWallKick(saved_active_block, state.grid, block_definition.rotation);
            if (can_rotate.success) {
                state.active_block.block_definition = block_definition;
                state.active_block.x = state.active_block.x + can_rotate.x_offset;
                state.saved_block = null;
            }
        } else {
            state.saved_block = state.active_block.block_definition.block_type;
            game.spawnNextBlock(state);
        }
    }
}

fn getBlockDropLocationPreview(activeBlock: game.ActiveBlock, grid: game.Grid) i32 {
    var preview = activeBlock;
    while (true) {
        const can_move = game.canMoveBlock(preview, grid, 0, 1);
        if (!can_move) break;
        preview.y += 1;
    }
    return preview.y;
}
