const std = @import("std");
const Zhip = @import("zhip.zig").Zhip;

pub fn main() !void {
    var zhip = Zhip.init();
    try zhip.loadRomFromFile("roms/ibm.ch8");
    std.debug.print("{X}\n", .{zhip._ram[0x200..0x300]});
}
