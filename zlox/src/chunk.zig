const std = @import("std");
const vals = @import("./values.zig");
const LineInfo = @import("./lineInfo.zig").LineInfo;

pub const Chunk = struct {
    count: u32 = 0,
    capacity: u32,
    code: []u8,
    lineInfo: []*const LineInfo,
    constants: vals.ValueArray,
    allocator: *const std.mem.Allocator,

    pub fn free(self: *Chunk) void {
        self.allocator.free(self.*.code);
        self.allocator.free(self.lineInfo);
        self.constants.free();
    }

    pub fn write(self: *Chunk, byte: u8, line: *const LineInfo) !void {
        if (self.capacity < self.count + 1) {
            var oldCap = self.capacity;
            self.capacity = growCapacity(oldCap);
            self.code = try self.allocator.realloc(self.code, self.capacity);
            self.lineInfo = try self.allocator.realloc(self.lineInfo, self.capacity);
        }
        self.code[self.count] = byte;
        self.lineInfo[self.count] = line;
        self.count += 1;
    }

    pub fn addConstant(self: *Chunk, value: vals.Value) !u8 {
        return try self.constants.write(value);
    }
};

pub fn newChunk(allocator: *const std.mem.Allocator) std.mem.Allocator.Error!Chunk {
    var constants = try vals.newValueArray(allocator);
    var chunk = Chunk{
        .capacity = 8,
        .code = try allocator.alloc(u8, 8),
        .lineInfo = try allocator.alloc(*const LineInfo, 8),
        .constants = constants,
        .allocator = allocator,
    };
    return chunk;
}

fn growCapacity(capacity: u32) u32 {
    if (capacity < 8) {
        return 8;
    }
    if (capacity < 2048) {
        return capacity * 2;
    }
    if (capacity >= std.math.maxInt(u32) - 1024) {
        return std.math.maxInt(u32);
    }
    return capacity + 1024;
}

const expectEqual = std.testing.expectEqual;
test "growCapacity" {
    try expectEqual(growCapacity(0), 8);
    try expectEqual(growCapacity(8), 16);
    try expectEqual(growCapacity(2000), 4000);
    try expectEqual(growCapacity(2048), 3072);
    try expectEqual(growCapacity(std.math.maxInt(u32) - 1), std.math.maxInt(u32));
    try expectEqual(growCapacity(std.math.maxInt(u32)), std.math.maxInt(u32));
}

test "newChunk" {
    const allocator = std.testing.allocator;
    var chunk = try newChunk(&allocator);
    defer chunk.free();

    try expectEqual(chunk.count, 0);
    try expectEqual(chunk.capacity, 8);
    try expectEqual(chunk.code.len, 8);
    try expectEqual(chunk.allocator, &allocator);
}

test "opcode_grow" {
    const allocator = std.testing.allocator;
    var chunk = try newChunk(&allocator);
    defer chunk.free();

    try chunk.write(0);
    try chunk.write(1);
    try chunk.write(2);
    try chunk.write(3);
    try chunk.write(4);
    try chunk.write(5);
    try chunk.write(6);
    try chunk.write(7);
    try chunk.write(8);

    try expectEqual(chunk.capacity, 16);
    try expectEqual(chunk.code.len, 16);
    try expectEqual(chunk.code[8], 8);
}
