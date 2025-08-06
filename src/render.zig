const rl = @import("raylib");
const b = @import("block.zig");
const game = @import("game.zig");
const std = @import("std");

const BLOCK_SIZE: i32 = 40;
const SIDEBAR_WIDTH: i32 = 200;
const GRID_WIDTH: i32 = 10;
const GRID_HEIGHT: i32 = 20;
const SCREEN_WIDTH = GRID_WIDTH * BLOCK_SIZE + SIDEBAR_WIDTH;
const SCREEN_HEIGHT = GRID_HEIGHT * BLOCK_SIZE;

pub fn drawGrid(grid: game.Grid) void {
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

pub fn drawBlock(block: b.BlockDefinition, origin_x: i32, origin_y: i32, alpha: u8) void {
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

pub fn drawSidebar(score: u32, next_block: b.BlockType, saved_block: ?b.BlockType) void {
    const sidebar_x = GRID_WIDTH * BLOCK_SIZE;
    rl.drawRectangle(
        sidebar_x,
        0,
        SIDEBAR_WIDTH,
        SCREEN_HEIGHT,
        rl.Color.dark_gray,
    );

    // Draw score
    const text_x = sidebar_x + (SIDEBAR_WIDTH / 4);
    rl.drawText("Score:", text_x, 40, 32, rl.Color.white);
    var score_buf: [16]u8 = undefined;
    const score_str = @import("std").fmt.bufPrintZ(&score_buf, "{d}", .{score}) catch "0";
    rl.drawText(score_str, text_x, 80, 32, rl.Color.yellow);

    // TODO: Fix!
    const offset = switch (next_block) {
        .O => 1,
        .I => 1,
        else => 0,
    };
    std.debug.print("offset: .{}\n", .{offset});

    // Draw next block preview
    const block_preview_x: i32 = sidebar_x + (SIDEBAR_WIDTH / 2) - BLOCK_SIZE;
    rl.drawText("Next:", text_x, 140, 32, rl.Color.white);
    const next_def = b.getBlockDefinition(next_block);
    drawBlock(next_def, @divFloor(block_preview_x, BLOCK_SIZE), 200 / BLOCK_SIZE, 255);

    // Draw saved block preview
    rl.drawText("Saved:", text_x, 300, 32, rl.Color.white);
    if (saved_block) |block| {
        const preview_def = b.getBlockDefinition(block);
        drawBlock(preview_def, @divFloor(block_preview_x, BLOCK_SIZE), 360 / BLOCK_SIZE, 255);
    }
}

pub fn drawBlockPreview(activeBlock: game.ActiveBlock, grid: game.Grid, getDropLocation: fn (game.ActiveBlock, game.Grid) i32) void {
    var preview_block = activeBlock;
    preview_block.y = getDropLocation(activeBlock, grid);
    drawBlock(
        preview_block.block_definition,
        preview_block.x,
        preview_block.y,
        100,
    );
}
