const std = @import("std");
const rl = @import("raylib");
const zhip_mod = @import("zhip.zig");
const Zhip = zhip_mod.Zhip;

const PIXEL_SCALE = 20;

pub fn main() !void {
    var zhip = Zhip.init();
    try zhip.loadRomFromFile("roms/ibm.ch8");
    const screenWidth = zhip_mod.DISPLAY_WIDTH * PIXEL_SCALE;
    const screenHeight = zhip_mod.DISPLAY_HEIGHT * PIXEL_SCALE;

    rl.initWindow(screenWidth, screenHeight, "Zhip8");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second

    while (!rl.windowShouldClose()) {
        zhip.runCycle();

        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(rl.Color.black);
        drawGraphics(zhip);
    }
}

fn drawGraphics(zhip: Zhip) void {
    for (0..zhip_mod.DISPLAY_HEIGHT) |j| {
        for (0..zhip_mod.DISPLAY_WIDTH) |i| {
            if (zhip.graphics[j][i] == 1) {
                rl.drawRectangle(@intCast(i * PIXEL_SCALE), @intCast(j * PIXEL_SCALE), @intCast(PIXEL_SCALE), @intCast(PIXEL_SCALE), rl.Color.white);
            }
        }
    }
}
