const std = @import("std");
const rl = @import("raylib");

const block_rotation = u2;

pub const BlockType = enum {
    // I,
    // S,
    O,
    // Z,
    // J,
    L,
    T,
};

pub const BlockDefinition = struct {
    block_type: BlockType,
    color: rl.Color,
    positions: [4][2]i32,
    rotation: u2, // 0 = spawn, 1 = right, 2 = reverse, 3 = left

    pub fn getRandom() BlockDefinition {
        const rand_index = std.crypto.random.intRangeLessThan(usize, 0, @typeInfo(BlockType).@"enum".fields.len);
        return getBlockDefinition(@enumFromInt(rand_index));
    }

    pub fn applyRotation(self: BlockDefinition, rotation: block_rotation) BlockDefinition {
        return BlockDefinition{
            .block_type = self.block_type,
            .color = self.color,
            .positions = rotateBlock(self, rotation),
            .rotation = rotation,
        };
    }
};

pub fn getBlockDefinition(block: BlockType) BlockDefinition {
    return switch (block) {
        // .I => BlockDefinition{
        //     .block_type = .I,
        //     .rotation = 0,
        //     .color = rl.Color.sky_blue,
        //     .positions = .{
        //         .{ 0, 0 }, .{ 0, 1 }, .{ 0, 2 }, .{ 0, 3 },
        //     },
        // },
        // .S => BlockDefinition{
        //     .block_type = .S,
        //     .rotation = 0,
        //     .color = rl.Color.green,
        //     .positions = .{
        //         .{ 1, 0 }, .{ 2, 0 }, .{ 0, 1 }, .{ 1, 1 },
        //     },
        // },
        .O => BlockDefinition{
            .block_type = .O,
            .rotation = 0,
            .color = rl.Color.yellow,
            .positions = .{
                .{ 0, 0 }, .{ 1, 0 }, .{ 0, 1 }, .{ 1, 1 },
            },
        },
        // .Z => BlockDefinition{
        //     .block_type = .Z,
        //     .rotation = 0,
        //     .color = rl.Color.red,
        //     .positions = .{
        //         .{ 0, 0 }, .{ 1, 0 }, .{ 1, 1 }, .{ 2, 1 },
        //     },
        // },
        // .J => BlockDefinition{
        //     .block_type = .J,
        //     .rotation = 0,
        //     .color = rl.Color.blue,
        //     .positions = .{
        //         .{ 0, 0 }, .{ 0, 1 }, .{ 0, 2 }, .{ 1, 2 },
        //     },
        // },
        .L => BlockDefinition{
            .block_type = .L,
            .rotation = 0,
            .color = rl.Color.orange,
            .positions = .{
                .{ 1, 0 }, .{ 1, 1 }, .{ 1, 2 }, .{ 0, 2 },
            },
        },
        .T => BlockDefinition{
            .block_type = .T,
            .rotation = 0,
            .color = rl.Color.purple,
            .positions = .{
                .{ 0, 0 }, .{ 1, 0 }, .{ 2, 0 }, .{ 1, 1 },
            },
        },
    };
}

fn rotateBlock(blockDefinition: BlockDefinition, rotation: block_rotation) [4][2]i32 {
    var rotated: [4][2]i32 = blockDefinition.positions;
    switch (blockDefinition.block_type) {
        .O => {
            // O block does not rotate
            return blockDefinition.positions;
        },
        else => {
            for (blockDefinition.positions, 0..) |pos, i| {
                const x = pos[0];
                const y = pos[1];
                // SRS: rotate around origin (0,0)
                // TODO: Isnt this technically incorrect? In SRS, the rotation happens around the center of the block
                // but here we are rotating around the top-left corner, since this implementation doesnt use 3x3/4x4 grid for block definitions
                switch (rotation) {
                    0 => rotated[i] = .{ x, y },
                    1 => rotated[i] = .{ -y, x },
                    2 => rotated[i] = .{ -x, -y },
                    3 => rotated[i] = .{ y, -x },
                }
            }
            return rotated;
        },
    }
}
