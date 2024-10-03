const std = @import("std");

const rl = @import("raylib");
const Zhip = @import("zhip.zig").Zhip;

pub fn main() !void {
    var zhip = Zhip.init();
    try zhip.loadRomFromFile("roms/ibm.ch8");
    const screenWidth = 800;
    const screenHeight = 450;

    rl.initWindow(screenWidth, screenHeight, "Zhip8");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second

    while (!rl.windowShouldClose()) {
        zhip.runCycle();

        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(rl.Color.black);
        // rl.drawText("Congrats! You created your first window!", 190, 200, 20, rl.Color.light_gray);
        const message = rl.textFormat("Current instruction: %x", .{zhip._reg_ir});
        rl.drawText(message, 190, 200, 20, rl.Color.white);
    }
}
