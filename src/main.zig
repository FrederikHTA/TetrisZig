const std = @import("std");
const rl = @import("raylib");
const b = @import("block.zig");
const game = @import("game.zig");
const render = @import("render.zig");
const screens = @import("screens.zig");
const c = @import("constants.zig");

pub fn main() !void {
    rl.initWindow(c.SCREEN_WIDTH, c.SCREEN_HEIGHT, "Tetris Clone");
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
                if (state.fall_timer > c.FALL_INTERVAL) {
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
                render.drawBlockPreview(
                    state.active_block,
                    state.grid,
                    game.getBlockDropLocationPreview,
                );
                render.drawBlock(
                    state.active_block.block_definition,
                    state.active_block.x,
                    state.active_block.y,
                    255,
                );
                render.drawSidebar(
                    state.score,
                    state.block_bag.next_piece,
                    state.saved_block,
                );
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
            const saved_block_definition = b.getBlockDefinition(saved_block);
            // Create a copy of activeBlock to avoid modifying the original
            var saved_active_block = state.active_block;
            saved_active_block.block_definition = saved_block_definition;

            // Check if the saved block can be inserted at current location, with wall kick if needed.
            const can_rotate = game.canRotateBlockWithWallKick(
                saved_active_block,
                state.grid,
                saved_block_definition.rotation,
            );

            if (can_rotate.success) {
                // Set saved block to current active block, and update active block to saved block.
                state.saved_block = state.active_block.block_definition.block_type;
                state.active_block.block_definition = saved_block_definition;
                state.active_block.x += can_rotate.x_offset;
            }
        } else {
            state.saved_block = state.active_block.block_definition.block_type;
            game.spawnNextBlock(state);
        }
    }
}
