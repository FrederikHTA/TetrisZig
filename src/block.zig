const std = @import("std");
const rl = @import("raylib");

pub const blockRotation = u2;
pub const blockPosition = [4][4]u1;

pub const BlockType = enum {
    I,
    S,
    O,
    Z,
    J,
    L,
    T,
};

pub const BlockDefinition = struct {
    block_type: BlockType,
    color: rl.Color,
    positions: blockPosition,
    rotation: u2, // 0 = spawn, 1 = right, 2 = reverse, 3 = left

    pub fn getRandom() BlockDefinition {
        const rand_index = std.crypto.random.intRangeLessThan(usize, 0, @typeInfo(BlockType).@"enum".fields.len);
        return getBlockDefinition(@enumFromInt(rand_index));
    }

    pub fn applyRotation(self: BlockDefinition, rotation: blockRotation) BlockDefinition {
        return BlockDefinition{
            .block_type = self.block_type,
            .color = self.color,
            .positions = rotateBlock(self, rotation),
            .rotation = rotation,
        };
    }
};

// TODO: improve, seems very lazy
fn getBlockPositions(block: BlockType, rotation: blockRotation) blockPosition {
    const block_rotations: [4][4][4]u1 = switch (block) {
        .I => .{
            .{
                .{ 0, 0, 0, 0 },
                .{ 1, 1, 1, 1 },
                .{ 0, 0, 0, 0 },
                .{ 0, 0, 0, 0 },
            },
            .{
                .{ 0, 0, 1, 0 },
                .{ 0, 0, 1, 0 },
                .{ 0, 0, 1, 0 },
                .{ 0, 0, 1, 0 },
            },
            .{
                .{ 0, 0, 0, 0 },
                .{ 0, 0, 0, 0 },
                .{ 1, 1, 1, 1 },
                .{ 0, 0, 0, 0 },
            },
            .{
                .{ 0, 1, 0, 0 },
                .{ 0, 1, 0, 0 },
                .{ 0, 1, 0, 0 },
                .{ 0, 1, 0, 0 },
            },
        },
        .S => .{
            .{
                .{ 0, 1, 1, 0 },
                .{ 1, 1, 0, 0 },
                .{ 0, 0, 0, 0 },
                .{ 0, 0, 0, 0 },
            },
            .{
                .{ 0, 1, 0, 0 },
                .{ 0, 1, 1, 0 },
                .{ 0, 0, 1, 0 },
                .{ 0, 0, 0, 0 },
            },
            .{
                .{ 0, 0, 0, 0 },
                .{ 0, 1, 1, 0 },
                .{ 1, 1, 0, 0 },
                .{ 0, 0, 0, 0 },
            },
            .{
                .{ 1, 0, 0, 0 },
                .{ 1, 1, 0, 0 },
                .{ 0, 1, 0, 0 },
                .{ 0, 0, 0, 0 },
            },
        },
        .O => .{
            .{
                .{ 0, 1, 1, 0 },
                .{ 0, 1, 1, 0 },
                .{ 0, 0, 0, 0 },
                .{ 0, 0, 0, 0 },
            },
            .{
                .{ 0, 1, 1, 0 },
                .{ 0, 1, 1, 0 },
                .{ 0, 0, 0, 0 },
                .{ 0, 0, 0, 0 },
            },
            .{
                .{ 0, 1, 1, 0 },
                .{ 0, 1, 1, 0 },
                .{ 0, 0, 0, 0 },
                .{ 0, 0, 0, 0 },
            },
            .{
                .{ 0, 1, 1, 0 },
                .{ 0, 1, 1, 0 },
                .{ 0, 0, 0, 0 },
                .{ 0, 0, 0, 0 },
            },
        },
        .J => .{
            .{
                .{ 1, 0, 0, 0 },
                .{ 1, 1, 1, 0 },
                .{ 0, 0, 0, 0 },
                .{ 0, 0, 0, 0 },
            },
            .{
                .{ 0, 1, 1, 0 },
                .{ 0, 1, 0, 0 },
                .{ 0, 1, 0, 0 },
                .{ 0, 0, 0, 0 },
            },
            .{
                .{ 0, 0, 0, 0 },
                .{ 1, 1, 1, 0 },
                .{ 0, 0, 1, 0 },
                .{ 0, 0, 0, 0 },
            },
            .{
                .{ 0, 1, 0, 0 },
                .{ 0, 1, 0, 0 },
                .{ 1, 1, 0, 0 },
                .{ 0, 0, 0, 0 },
            },
        },
        .L => .{
            .{
                .{ 0, 0, 1, 0 },
                .{ 1, 1, 1, 0 },
                .{ 0, 0, 0, 0 },
                .{ 0, 0, 0, 0 },
            },
            .{
                .{ 0, 1, 0, 0 },
                .{ 0, 1, 0, 0 },
                .{ 0, 1, 1, 0 },
                .{ 0, 0, 0, 0 },
            },
            .{
                .{ 0, 0, 0, 0 },
                .{ 1, 1, 1, 0 },
                .{ 1, 0, 0, 0 },
                .{ 0, 0, 0, 0 },
            },
            .{
                .{ 1, 1, 0, 0 },
                .{ 0, 1, 0, 0 },
                .{ 0, 1, 0, 0 },
                .{ 0, 0, 0, 0 },
            },
        },
        .Z => .{
            .{
                .{ 1, 1, 0, 0 },
                .{ 0, 1, 1, 0 },
                .{ 0, 0, 0, 0 },
                .{ 0, 0, 0, 0 },
            },
            .{
                .{ 0, 0, 1, 0 },
                .{ 0, 1, 1, 0 },
                .{ 0, 1, 0, 0 },
                .{ 0, 0, 0, 0 },
            },
            .{
                .{ 0, 0, 0, 0 },
                .{ 1, 1, 0, 0 },
                .{ 0, 1, 1, 0 },
                .{ 0, 0, 0, 0 },
            },
            .{
                .{ 0, 1, 0, 0 },
                .{ 1, 1, 0, 0 },
                .{ 1, 0, 0, 0 },
                .{ 0, 0, 0, 0 },
            },
        },
        .T => .{
            .{
                .{ 0, 1, 0, 0 },
                .{ 1, 1, 1, 0 },
                .{ 0, 0, 0, 0 },
                .{ 0, 0, 0, 0 },
            },
            .{
                .{ 0, 1, 0, 0 },
                .{ 0, 1, 1, 0 },
                .{ 0, 1, 0, 0 },
                .{ 0, 0, 0, 0 },
            },
            .{
                .{ 0, 0, 0, 0 },
                .{ 1, 1, 1, 0 },
                .{ 0, 1, 0, 0 },
                .{ 0, 0, 0, 0 },
            },
            .{
                .{ 0, 1, 0, 0 },
                .{ 1, 1, 0, 0 },
                .{ 0, 1, 0, 0 },
                .{ 0, 0, 0, 0 },
            },
        },
    };
    return block_rotations[rotation]; // unreachable
}

pub fn getBlockDefinition(blockType: BlockType) BlockDefinition {
    return BlockDefinition{
        .block_type = blockType,
        .rotation = 0,
        .positions = getBlockPositions(blockType, 0),
        .color = switch (blockType) {
        .I => rl.Color.sky_blue,
        .S => rl.Color.green,
        .O => rl.Color.yellow,
        .Z => rl.Color.red,
        .J => rl.Color.blue,
        .L => rl.Color.orange,
        .T => rl.Color.purple,
        }
    };
}

fn rotateBlock(blockDefinition: BlockDefinition, rotation: blockRotation) blockPosition {
    return getBlockPositions(blockDefinition.block_type, rotation);
}

// pub fn getBlockPositions(block: BlockType, rotation: block_rotation) [4][2]i32 {
//     const def = getBlockDefinition(block);
//     var positions: [4][2]i32 = undefined;
//     var idx: usize = 0;
//     for (def.shapes[rotation], 0..) |row, y| {
//         for (row, 0..) |cell, x| {
//             if (cell == 1) {
//                 positions[idx] = .{ x, y };
//                 idx += 1;
//             }
//         }
//     }
//     return positions;
// }
