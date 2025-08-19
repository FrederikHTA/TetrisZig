const rl = @import("raylib");
const b = @import("block.zig");
const game = @import("game.zig");
const c = @import("constants.zig");
const screen = @import("screens.zig");
const std = @import("std");
const leaderboard = @import("leaderboard.zig");

pub fn renderGame(state : *game.GameState, gameScreen: *screen.GameScreen) void {
    if (state.fall_timer > c.FALL_INTERVAL) {
        if (game.canMoveBlock(state.active_block, state.grid, 0, 1)) {
            state.active_block.y += 1;
        } else {
            game.placeBlock(state.active_block, &state.grid);
            game.clearFullLines(state);
            game.spawnNextBlock(state);
            if (game.isGameOver(state.grid)) {
                gameScreen.* = screen.GameScreen.Death;
            }
        }
        state.fall_timer = 0.0;
    }
    drawGrid(state.grid);
    drawBlockPreview(
        state.active_block,
        state.grid,
        game.getBlockDropLocationPreview,
    );
    drawBlock(
        state.active_block.block_definition,
        state.active_block.x,
        state.active_block.y,
        255,
    );
    drawSidebar(
        state.score,
        state.block_bag.next_piece,
        state.saved_block,
    );
}

pub fn drawLeaderboard(entries: []const leaderboard.LeaderboardEntry, x: i32, y: i32) void {
    const font_size = 28;
    rl.drawText("Leaderboard", x, y, font_size, rl.Color.yellow);

    var y_offset = y + font_size + 8;
    for (entries, 0..) |entry, i| {
        var line_buf: [64]u8 = undefined;
        // Format: "1. NAME .......... 12345"
        const name = std.mem.trimRight(u8, &entry.name, "");
        const line = std.fmt.bufPrintZ(
            &line_buf,
            "{d}. {s: <16} {d}",
            .{i + 1, name, entry.score},
        ) catch "ERR";
        rl.drawText(line, x, y_offset, 24, rl.Color.white);
        y_offset += 28;
    }
}

pub fn drawGrid(grid: game.Grid) void {
    for (grid, 0..) |row, y| {
        for (row, 0..) |cell, x| {
            rl.drawRectangleLines(
                @as(i32, @intCast(x)) * c.BLOCK_SIZE,
                @as(i32, @intCast(y)) * c.BLOCK_SIZE,
                c.BLOCK_SIZE,
                c.BLOCK_SIZE,
                rl.Color.dark_gray.alpha(0.5),
            );
            if (cell) |block| {
                const def = b.getBlockDefinition(block);
                rl.drawRectangle(
                    @as(i32, @intCast(x)) * c.BLOCK_SIZE,
                    @as(i32, @intCast(y)) * c.BLOCK_SIZE,
                    c.BLOCK_SIZE,
                    c.BLOCK_SIZE,
                    def.color,
                );
                rl.drawRectangleLines(
                    @as(i32, @intCast(x)) * c.BLOCK_SIZE,
                    @as(i32, @intCast(y)) * c.BLOCK_SIZE,
                    c.BLOCK_SIZE,
                    c.BLOCK_SIZE,
                    rl.Color.black,
                );
            }
        }
    }
}

/// Draws a block at the specified origin based on block size.
/// This means x = 10 will be the 10th block in the grid, not pixel position.
pub fn drawBlock(block: b.BlockDefinition, origin_x: i32, origin_y: i32, alpha: u8) void {
    const positions: b.blockPosition = block.applyRotation(block.rotation).positions;
    for (positions, 0..) |row, i| {
        const rowI = @as(i32, @intCast(i));
        for (row, 0..) |cell, j| {
            const colI = @as(i32, @intCast(j));
            if (cell != 1) continue;
            const x: i32 = (origin_x + colI) * c.BLOCK_SIZE;
            const y: i32 = (origin_y + rowI) * c.BLOCK_SIZE;
            var color = block.color;
            color.a = alpha;
            rl.drawRectangle(x, y, c.BLOCK_SIZE, c.BLOCK_SIZE, color);
            rl.drawRectangleLines(x, y, c.BLOCK_SIZE, c.BLOCK_SIZE, rl.Color.black);
        }
    }
}

pub fn drawSidebar(score: u32, next_block: b.BlockType, saved_block: ?b.BlockType) void {
    const sidebar_x = c.GRID_WIDTH * c.BLOCK_SIZE;
    const font_size = 32;
    rl.drawRectangle(
        sidebar_x,
        0,
        c.SIDEBAR_WIDTH,
        c.SCREEN_HEIGHT,
        rl.Color.dark_gray,
    );

    // Draw score
    const text_x = sidebar_x + (c.SIDEBAR_WIDTH / 4);
    rl.drawText("Score:", text_x, 40, font_size, rl.Color.white);
    var score_buf: [16]u8 = undefined;
    const score_str = std.fmt.bufPrintZ(&score_buf, "{d}", .{score}) catch "0";
    rl.drawText(score_str, text_x, 80, font_size, rl.Color.yellow);

    // Draw next block preview
    const block_preview_x: i32 = sidebar_x + (c.SIDEBAR_WIDTH / c.BLOCK_SIZE) + c.BLOCK_SIZE;
    rl.drawText("Next:", text_x, 140, font_size, rl.Color.white);
    const next_def = b.getBlockDefinition(next_block);

    const next_block_offet: i32 = if (next_block == .O) c.BLOCK_SIZE else 0;
    // TODO:
    // Due to the current implementation of drawBlock, the position is drawn in grid coordinates of block_size,
    // and has to be an int. We cannot draw something at fx block_size / 2, which is needed to center the "I" block.
    // I should probably make a new method that can draw at pixel positions, or change the current one to accept floats.
    drawBlock(next_def, @divFloor(block_preview_x - next_block_offet, c.BLOCK_SIZE), 200 / c.BLOCK_SIZE, 255);

    // Draw saved block preview
    rl.drawText("Saved:", text_x, 300, font_size, rl.Color.white);
    if (saved_block) |block| {
        const preview_def = b.getBlockDefinition(block);
        const preview_block_offet: i32 = if (block == .O) c.BLOCK_SIZE else 0;
        drawBlock(preview_def, @divFloor(block_preview_x - preview_block_offet, c.BLOCK_SIZE), 360 / c.BLOCK_SIZE, 255);
    }
}

pub fn drawBlockPreview(
    activeBlock: game.ActiveBlock,
    grid: game.Grid,
    getDropLocation: fn (game.ActiveBlock, game.Grid) i32,
) void {
    var preview_block = activeBlock;
    preview_block.y = getDropLocation(activeBlock, grid);
    drawBlock(
        preview_block.block_definition,
        preview_block.x,
        preview_block.y,
        100,
    );
}
