const std = @import("std");
const rl = @import("raylib");
const render = @import("render.zig");
const b = @import("block.zig");
const game = @import("game.zig");
const leaderboard = @import("leaderboard.zig");

const BLOCK_SIZE: i32 = 40;
const SIDEBAR_WIDTH: i32 = 200;
const GRID_WIDTH: i32 = 10;
const GRID_HEIGHT: i32 = 20;
const SCREEN_WIDTH = GRID_WIDTH * BLOCK_SIZE + SIDEBAR_WIDTH;
const SCREEN_HEIGHT = GRID_HEIGHT * BLOCK_SIZE;

pub const GameScreen = enum { Start, Playing, Death };
pub const DeathScreenAction = enum { retry, exit, none };
pub const StartScreenAction = enum { start, none };

pub fn drawStartScreen() StartScreenAction {
    const logo_text = "TETRIS";
    const logo_font_size = 80;
    const logo_width = rl.measureText(logo_text, logo_font_size);
    rl.drawText(
        logo_text,
        @divTrunc((SCREEN_WIDTH - logo_width), 2),
        SCREEN_HEIGHT / 3,
        logo_font_size,
        rl.Color.yellow,
    );
    const btn_w = 240;
    const btn_h = 60;
    const btn_x = (SCREEN_WIDTH - btn_w) / 2;
    const btn_y = SCREEN_HEIGHT / 2;
    const mouse = rl.getMousePosition();
    const hovered =
        mouse.x >= btn_x and mouse.x <= btn_x + btn_w and mouse.y >= btn_y and mouse.y <= btn_y + btn_h;
    rl.drawRectangle(
        btn_x,
        btn_y,
        btn_w,
        btn_h,
        if (hovered) rl.Color.light_gray else rl.Color.gray,
    );
    rl.drawText("Start Game", btn_x + 32, btn_y + 12, 32, rl.Color.black);
    if (hovered and rl.isMouseButtonPressed(rl.MouseButton.left)) {
        return StartScreenAction.start;
    }
    return StartScreenAction.none;
}

pub fn drawDeathScreen() DeathScreenAction {
    const lost_text = "YOU LOST";
    const lost_font_size = 64;
    const lost_width = rl.measureText(lost_text, lost_font_size);
    rl.drawText(
        lost_text,
        @divTrunc((SCREEN_WIDTH - lost_width), 2),
        SCREEN_HEIGHT / 3,
        lost_font_size,
        rl.Color.red,
    );
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
        return DeathScreenAction.retry;
    }
    if (exit_hovered and rl.isMouseButtonPressed(rl.MouseButton.left)) {
        return DeathScreenAction.exit;
    }
    return DeathScreenAction.none;
}

pub fn drawDeathScreenWithLeaderboard(
    state: *game.GameState,
    name_buf: []u8,
    name_len: *usize,
    name_entered: *bool,
    leaderboard_entries: *[]leaderboard.LeaderboardEntry,
    allocator: std.mem.Allocator,
) DeathScreenAction {
    if (!name_entered.*) {
        // Handle name input
        if (rl.isKeyPressed(rl.KeyboardKey.enter) and name_len.* > 0) {
            // Add score to leaderboard
            leaderboard_entries.* = leaderboard.addScore(
                allocator,
                leaderboard_entries.*,
                name_buf[0..name_len.*],
                state.score,
            ) catch leaderboard_entries.*;
            leaderboard.saveLeaderboard(leaderboard_entries.*) catch {};
            name_entered.* = true;
        } else {
            // Handle character input
            const keyPressed = rl.getKeyPressed();
            if (@intFromEnum(keyPressed) >= 65 and @intFromEnum(keyPressed) <= 90 and name_len.* < name_buf.len) {
                name_buf[name_len.*] = @as(u8, @intCast(@intFromEnum(keyPressed)));
                name_len.* += 1;
            } else if (keyPressed == rl.KeyboardKey.backspace and name_len.* > 0) {
                name_len.* -= 1;
            }
        }
    }

    const lost_text = "YOU LOST";
    const lost_font_size = 64;
    const lost_width = rl.measureText(lost_text, lost_font_size);
    rl.drawText(
        lost_text,
        @divTrunc((SCREEN_WIDTH - lost_width), 2),
        100,
        lost_font_size,
        rl.Color.red,
    );

    // Draw leaderboard
    const leaderboard_width = rl.measureText("Leaderboard", 28);
    render.drawLeaderboard(@ptrCast(leaderboard_entries.*), @divTrunc((SCREEN_WIDTH - leaderboard_width), 2), 200);

    // Draw name input if needed
    const enter_name_text = "Enter your name:";
    const enter_name_width = rl.measureText(enter_name_text, 32);
    if (!name_entered.*) {
        rl.drawText(
            "Enter your name:",
            @divTrunc((SCREEN_WIDTH - enter_name_width), 2),
            SCREEN_HEIGHT / 2,
            32,
            rl.Color.white,
        );

        // TODO: Temp arr to display name input, without showing the whole name_buf, as it contains '????????'
        var input_buf: [16]u8 = undefined;
        @memset(&input_buf, 0);
        for (name_buf[0..name_len.*], 0..) |c, i| {
            input_buf[i] = c;
        }
        rl.drawText(
            @ptrCast(&input_buf),
            @divTrunc((SCREEN_WIDTH - 220), 2) + 5,
            SCREEN_HEIGHT / 2 + 45,
            32,
            rl.Color.yellow,
        );
        rl.drawRectangleLines(
            @divTrunc((SCREEN_WIDTH - 220), 2),
            SCREEN_HEIGHT / 2 + 40,
            220,
            40,
            rl.Color.yellow,
        );
    }

    // Draw retry button
    const btn_w = 180;
    const btn_h = 50;
    const btn_x = (SCREEN_WIDTH - btn_w) / 2;
    const btn_y = SCREEN_HEIGHT - 160;
    const mouse = rl.getMousePosition();
    const retry_hovered = mouse.x >= btn_x and mouse.x <= btn_x + btn_w and mouse.y >= btn_y and mouse.y <= btn_y + btn_h;
    rl.drawRectangle(
        btn_x,
        btn_y,
        btn_w,
        btn_h,
        if (retry_hovered) rl.Color.light_gray else rl.Color.gray,
    );
    rl.drawText("Retry", btn_x + 32, btn_y + 12, 32, rl.Color.black);
    if (retry_hovered and rl.isMouseButtonPressed(rl.MouseButton.left)) {
        return DeathScreenAction.retry;
    }

    // Draw exit button
    const exit_btn_y = btn_y + btn_h + 20;
    const exit_hovered = mouse.x >= btn_x and mouse.x <= btn_x + btn_w and mouse.y >= exit_btn_y and mouse.y <= exit_btn_y + btn_h;
    rl.drawRectangle(
        btn_x,
        exit_btn_y,
        btn_w,
        btn_h,
        if (exit_hovered) rl.Color.light_gray else rl.Color.gray,
    );
    rl.drawText("Exit", btn_x + 48, exit_btn_y + 12, 32, rl.Color.black);
    if (exit_hovered and rl.isMouseButtonPressed(rl.MouseButton.left)) {
        return DeathScreenAction.exit;
    }
    return DeathScreenAction.none;
}
