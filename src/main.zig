const std = @import("std");
const rl = @import("raylib");
const zhip_mod = @import("zhip.zig");
const Zhip = zhip_mod.Zhip;

const PIXEL_SCALE = 20;

const KEY_MAP = [_]rl.KeyboardKey{
    .key_x,
    .key_one,
    .key_two,
    .key_three,
    .key_q,
    .key_w,
    .key_e,
    .key_a,
    .key_s,
    .key_d,
    .key_z,
    .key_c,
    .key_four,
    .key_r,
    .key_f,
    .key_v,
};

pub fn main() !void {
    var zhip = Zhip.init();
    try zhip.loadRomFromFile("roms/test_opcode.ch8");
    const screenWidth = zhip_mod.DISPLAY_WIDTH * PIXEL_SCALE;
    const screenHeight = zhip_mod.DISPLAY_HEIGHT * PIXEL_SCALE;

    rl.initWindow(screenWidth, screenHeight, "Zhip8");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second

    while (!rl.windowShouldClose()) {
        zhip.runCycle();

        // key stuff
        // key down
        for (0..KEY_MAP.len) |i| {
            if (rl.isKeyDown(KEY_MAP[i])) {
                zhip.keys[i] = 1;
                std.debug.print("{d}", .{zhip.keys});
            }
        }
        // key up
        for (0..KEY_MAP.len) |i| {
            if (rl.isKeyUp(KEY_MAP[i])) {
                zhip.keys[i] = 0;
            }
        }

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
