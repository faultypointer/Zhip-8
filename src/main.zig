const std = @import("std");
const Zhip = @import("zhip.zig").Zhip;

pub fn main() !void {
    var zhip = Zhip.init();
    try zhip.loadRomFromFile("roms/ibm.ch8");
    zhip.run();
    std.debug.print("{x}", .{zhip._reg_ir});
}
