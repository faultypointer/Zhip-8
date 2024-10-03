const std = @import("std");
const Zhip = @import("zhip.zig").Zhip;

pub fn main() !void {
    var zhip = Zhip.init();
    try zhip.loadRomFromFile("roms/ibm.ch8");
    while (true) {
        zhip.runCycle();
    }
}
