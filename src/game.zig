const b = @import("block.zig");
const bag = @import("bag.zig");

const GRID_WIDTH: i32 = 10;
const GRID_HEIGHT: i32 = 20;
const BLOCK_START_OFFSET: i32 = 2;

pub const Grid = [GRID_HEIGHT][GRID_WIDTH]?b.BlockType;

pub const ActiveBlock = struct {
    block_definition: b.BlockDefinition,
    x: i32,
    y: i32,
};

pub const GameState = struct {
    active_block: ActiveBlock,
    grid: Grid,
    fall_timer: f32,
    score: u32 = 0,
    block_bag: bag.BlockBag,
    saved_block: ?b.BlockType = null,

    pub fn init() GameState {
        var blockBag = bag.BlockBag.init();
        blockBag.shuffle();
        const activeBlock = ActiveBlock{
            .block_definition = b.getBlockDefinition(blockBag.draw()),
            .x = GRID_WIDTH / 2 - BLOCK_START_OFFSET,
            .y = 0,
        };
        return GameState{
            .active_block = activeBlock,
            .grid = [_][GRID_WIDTH]?b.BlockType{[_]?b.BlockType{null} ** GRID_WIDTH} ** GRID_HEIGHT,
            .fall_timer = 0.0,
            .block_bag = blockBag,
        };
    }
};

pub fn getBlockDropLocationPreview(activeBlock: ActiveBlock, grid: Grid) i32 {
    var preview = activeBlock;
    while (true) {
        const can_move = canMoveBlock(preview, grid, 0, 1);
        if (!can_move) break;
        preview.y += 1;
    }
    return preview.y;
}

pub fn spawnNextBlock(state: *GameState) void {
    const block_type = state.block_bag.draw();
    const active_block = ActiveBlock{
        .block_definition = b.getBlockDefinition(block_type),
        .x = GRID_WIDTH / 2 - BLOCK_START_OFFSET,
        .y = 0,
    };
    state.active_block = active_block;
}

pub fn canMoveBlock(activeBlock: ActiveBlock, grid: Grid, dx: i32, dy: i32) bool {
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

pub fn canRotateBlockWithWallKick(activeBlock: ActiveBlock, grid: Grid, new_rotation: u2) struct { success: bool, x_offset: i32 } {
    const kicks = [_]i8{ 0, -1, 1, -2, 2 };
    for (kicks) |dx| {
        var preview = activeBlock;
        preview.block_definition.rotation = new_rotation;
        if (canMoveBlock(preview, grid, dx, 0)) {
            return .{ .success = true, .x_offset = dx };
        }
    }
    return .{ .success = false, .x_offset = 0 };
}

pub fn placeBlock(activeBlock: ActiveBlock, grid: *Grid) void {
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

pub fn clearFullLines(state: *GameState) void {
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
            var row = y;
            while (row > 0) : (row -= 1) {
                state.grid[@intCast(row)] = state.grid[@intCast(row - 1)];
            }
            state.grid[0] = [_]?b.BlockType{null} ** GRID_WIDTH;
            y += 1;
        }
    }
    state.score += 100 * @as(u32, linesCleared);
}

pub fn isGameOver(grid: Grid) bool {
    for (grid[0]) |cell| {
        if (cell != null) return true;
    }
    return false;
}
