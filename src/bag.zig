const std = @import("std");
const b = @import("block.zig");

pub const BlockBag = struct {
    bag: [7]b.BlockType,
    index: usize,
    next_piece: b.BlockType,

    pub fn init() BlockBag {
        var bag = BlockBag{
            .bag = undefined,
            .next_piece = undefined,
            .index = 0,
        };
        bag.shuffle();
        bag.next_piece = bag.bag[bag.index];
        return bag;
    }

    pub fn shuffle(self: *BlockBag) void {
        var block_types: [7]b.BlockType = b.BlockType.all();
        std.crypto.random.shuffle(b.BlockType, &block_types);
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
