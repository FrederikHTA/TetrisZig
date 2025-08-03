const std = @import("std");
const b = @import("block.zig"); 

pub const BlockBag = struct {
    bag: [7]b.BlockType,
    index: usize,
    next_piece: b.BlockType,

    pub fn init() BlockBag {
        var bag = BlockBag{
            .bag = undefined,
            .index = 0,
            .next_piece = b.BlockType.I, // default, will be set on shuffle
        };
        bag.shuffle();
        bag.next_piece = bag.bag[bag.index];
        return bag;
    }

    pub fn shuffle(self: *BlockBag) void {
        var block_types = [_]b.BlockType{ .I, .O, .S, .Z, .J, .L, .T };
        for (block_types, 0..) |_, i| {
            const j = std.crypto.random.intRangeLessThan(usize, 0, @typeInfo(b.BlockType).@"enum".fields.len);
            // const j = prng.random().intRangeLessThan(usize, 0, block_types.len);
            const tmp = block_types[i];
            block_types[i] = block_types[j];
            block_types[j] = tmp;
        }
        self.bag = block_types;
        self.index = 0;
    }

    pub fn draw(self: *BlockBag) b.BlockType {
        if (self.index >= self.bag.len) {
            self.shuffle();
        }
        const piece = self.bag[self.index];
        self.index += 1;
        // Set next_piece for preview
        if (self.index < self.bag.len) {
            self.next_piece = self.bag[self.index];
        } else {
            // If bag is empty, shuffle and set next_piece
            self.shuffle();
            self.next_piece = self.bag[0];
        }
        return piece;
    }
};
