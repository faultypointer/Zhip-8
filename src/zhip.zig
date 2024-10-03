const std = @import("std");

pub const DISPLAY_WIDTH: usize = 64;
pub const DISPLAY_HEIGHT: usize = 32;
const MEMORY_SIZE: usize = 4 * 1024;
const STACK_SIZE: usize = 16;

// Struct that represents a chip 8 emulator
pub const Zhip = struct {
    _ram: [MEMORY_SIZE]u8,
    _reg: [16]u8, // 16 8-bit registers
    _reg_i: u16, // 16 bit register to hold address (only 12 right most bits are used for 4k memory size. applicable for all address based registers and stack)
    _reg_dt: u8, // 8 bit delay timer register
    _reg_st: u8, // 8 bit sound timer resiter
    _reg_ir: u16, // 16 bit register to hold the current instruction
    _pc: u16, // 16 bit program counter (rightmost 12 bits)
    _sp: u8, // stack pointer
    _stack: [STACK_SIZE]u16, // stack to hold return address from subroutine , can hold 16 addresses so 16 level of nested subroutine calls

    graphics: [DISPLAY_HEIGHT][DISPLAY_WIDTH]u8, // display
    keys: [16]u8, // input keys state

    pub fn init() Zhip {
        var zhip = Zhip{
            ._ram = undefined,
            ._reg = undefined,
            ._reg_i = 0,
            ._reg_dt = 0,
            ._reg_st = 0,
            ._reg_ir = 0,
            ._pc = 0,
            ._sp = 0,
            ._stack = undefined,

            .graphics = undefined,
            .keys = undefined,
        };

        for (0..STACK_SIZE) |i| {
            zhip._stack[i] = 0;
        }
        for (0..16) |i| {
            zhip._reg[i] = 0;
            zhip.keys[i] = 0;
        }

        for (0..MEMORY_SIZE) |i| {
            zhip._ram[i] = 0;
        }

        for (0..DISPLAY_HEIGHT) |j| {
            for (0..DISPLAY_WIDTH) |i| {
                zhip.graphics[j][i] = 0;
            }
        }

        // load character sprites
        const chracters_sprite = [_]u8{
            0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
            0x20, 0x60, 0x20, 0x20, 0x70, // 1
            0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
            0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
            0x90, 0x90, 0xF0, 0x10, 0x10, // 4
            0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
            0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
            0xF0, 0x10, 0x20, 0x40, 0x40, // 7
            0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
            0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
            0xF0, 0x90, 0xF0, 0x90, 0x90, // A
            0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
            0xF0, 0x80, 0x80, 0x80, 0xF0, // C
            0xE0, 0x90, 0x90, 0x90, 0xE0, // D
            0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
            0xF0, 0x80, 0xF0, 0x80, 0x80, // F
        };
        @memcpy(zhip._ram[0x50..0xA0], &chracters_sprite);

        return zhip;
    }

    pub fn loadRomFromFile(self: *Zhip, filename: []const u8) !void {
        const file = try std.fs.cwd().openFile(filename, .{});
        _ = try file.readAll(self._ram[0x200..]);
        self._pc = 0x200;
    }

    pub fn runCycle(self: *Zhip) void {
        self.fetch();
        self.decodeAndExecute();
    }

    fn fetch(self: *Zhip) void {
        self._reg_ir = self._ram[self._pc];
        self._pc += 1;
        self._reg_ir <<= 8;
        self._reg_ir += self._ram[self._pc];
        self._pc += 1;
    }

    fn decodeAndExecute(self: *Zhip) void {
        switch ((self._reg_ir & 0xF000) >> 12) {
            0 => {
                switch (self._reg_ir & 0x000F) {
                    0 => self.clearDisplay(),
                    // 0xE => self.returnFromSubroutine(),
                    else => self.panicOnUnknownInstruction(),
                }
            },
            1 => self.jumpToAddr(),
            2 => self.callAddress(),
            3 => self.skipNextInstructionIfEqual(),
            4 => self.skipNextInstructionIfNotEqual(),
            5 => self.skipNextInstructionIfVxEqualsVy(),
            6 => self.setRegister(),
            7 => self.addToRegister(),
            8 => self.handle8XY(),
            9 => self.skipNextInstructionIfVxNotEqualsVy(),
            0xA => self.loadIRegister(),
            0xB => self.jumpToAddrPlusOffset(),
            0xD => self.drawSprite(),
            else => self.panicOnUnknownInstruction(),
        }
    }

    // 00E0
    fn clearDisplay(self: *Zhip) void {
        for (0..DISPLAY_HEIGHT) |j| {
            for (0..DISPLAY_WIDTH) |i| {
                self.graphics[j][i] = 0;
            }
        }
    }
    // 0x00EE
    fn returnFromSubroutine(self: *Zhip) void {
        self._sp -= 1;
        self._pc = self._stack[self._sp];
    }

    // 0x2NNN; call address NNN
    fn callAddress(self: *Zhip) void {
        self._stack[self._sp] = self._pc;
        self._sp += 1;
        self._pc = self._reg_ir & 0x0FFF;
    }

    // 0x3XNN; skips next instruction if Vx equals NN
    fn skipNextInstructionIfEqual(self: *Zhip) void {
        const Vx: u8 = self._reg_ir[self.getXIndex()];
        const nibble: u8 = @truncate(self._reg_ir);
        if (Vx == nibble) {
            self._pc += 2;
        }
    }

    // 0x4XNN; skips if Vx not equal to NN
    fn skipNextInstructionIfNotEqual(self: *Zhip) void {
        const Vx: u8 = self._reg_ir[self.getXIndex()];
        const nibble: u8 = @truncate(self._reg_ir);
        if (Vx != nibble) {
            self._pc += 2;
        }
    }

    // 0x5XY0
    fn skipNextInstructionIfVxEqualsVy(self: *Zhip) void {
        const Vx: u8 = self._reg_ir[self.getXIndex()];
        const Vy: u8 = self._reg_ir[self.getYIndex()];
        if (Vx == Vy) {
            self._pc += 2;
        }
    }

    // 0x9XY0
    fn skipNextInstructionIfVxNotEqualsVy(self: *Zhip) void {
        const Vx: u8 = self._reg_ir[self.getXIndex()];
        const Vy: u8 = self._reg_ir[self.getYIndex()];
        if (Vx != Vy) {
            self._pc += 2;
        }
    }
    // 0x8XY0;
    // all the instructions of this type involves register Vx or Vy or both
    fn handle8XY(self: *Zhip) void {
        const Vx = &self._reg_ir[self.getXIndex()];
        const Vy = &self._reg_ir[self.getYIndex()];
        const nibble: u4 = @truncate(self._reg_ir);
        switch (nibble) {
            0x0 => Vx.* = Vy.*,
            0x1 => Vx.* = Vx.* | Vy.*,
            0x2 => Vx.* = Vx.* & Vy.*,
            0x3 => Vx.* = Vx.* ^ Vy.*,
            0x4 => {
                const result: u16 = Vx.* + Vy.*;
                Vx.* = @truncate(result);
                self._reg[0xF] = (result >> 8);
            },
            0x5, 0x7 => {
                const result: i8 = Vx.* - Vy.*;
                if (nibble == 0x7) {
                    result = -result;
                }
                if (result < 0) {
                    self._reg[0xF] = 0;
                    Vx.* = 0x100 + result;
                } else {
                    self._reg[0xF] = 1;
                    Vx.* = result;
                }
            },
            0x6 => {
                self._reg[0xF] = Vx.* & 1;
                Vx.* >>= 1;
            },
            0xE => {
                self._reg[0xF] = Vx.* >> 7;
                Vx.* <<= 1;
            },
            else => self.panicOnUnknownInstruction(),
        }
    }
    // 1NNN; jumps to location NNN
    fn jumpToAddr(self: *Zhip) void {
        self._pc = 0x0FFF & self._reg_ir;
    }
    // BNNN; jumps to location NNN + V0
    fn jumpToAddrPlusOffset(self: *Zhip) void {
        self._pc = (0x0FFF & self._reg_ir) + self._reg[0x0];
    }

    // 6XNN; sets register Vx to NN
    fn setRegister(self: *Zhip) void {
        const index = self.getXIndex();
        // check for flags??
        self._reg[index] = @intCast(self._reg_ir & 0x00FF);
    }

    // 7XNN; adds NN to Vx; result in Vx
    fn addToRegister(self: *Zhip) void {
        const index = self.getXIndex();
        self._reg[index] += @intCast(self._reg_ir & 0x00FF);
    }

    // ANNN; I register is set to NNN
    fn loadIRegister(self: *Zhip) void {
        const addr = self._reg_ir & 0x0FFF;
        self._reg_i = addr;
    }

    // DXYN; draws N bytes sprite starting from location I
    // at coordinate (Vx, Vy) of display
    fn drawSprite(self: *Zhip) void {
        var vy: usize = @intCast((self._reg[self.getYIndex()]) % DISPLAY_HEIGHT);
        const sprite_height: usize = @intCast(self._reg_ir & 0x000F);
        self._reg[0xF] = 0; // set Vf to 0 initially

        for (0..sprite_height) |j| {
            const current_sprite_byte = self._ram[@intCast(self._reg_i + j)];
            var vx: usize = @intCast((self._reg[self.getXIndex()]) % DISPLAY_WIDTH);
            for (0..8) |i| {
                const shift: u3 = @intCast(i);
                const current_sprite_pixel: u8 = (current_sprite_byte >> (7 - shift)) & 1;
                // if any pixel in sprite causes any of the pixel in graphics to turn off (1 -> 0)
                // then we set Vf to 1
                if ((self._reg[0xF] == 0) and (self.graphics[vy][vx] & current_sprite_pixel == 1)) {
                    self._reg[0xF] = 1;
                }
                self.graphics[vy][vx] ^= current_sprite_pixel;
                vx = vx + 1;
                if (vx == DISPLAY_WIDTH) {
                    break;
                }
            }
            vy = vy + 1;
            if (vy == DISPLAY_HEIGHT) {
                break;
            }
        }
    }

    fn panicOnUnknownInstruction(self: Zhip) noreturn {
        std.debug.panic("unknown instruction: {X:0>4}\n", .{self._reg_ir});
    }

    // returns the index to the register array
    // represented by the lower nibble of upper byte of
    // the instruction (ie 0xFXFF)
    fn getXIndex(self: Zhip) usize {
        return @intCast((self._reg_ir & 0x0F00) >> 8);
    }
    // returns the index to the register array
    // represented by the upper nibble of lower byte of
    // the instruction (ie 0xFFYF)
    fn getYIndex(self: Zhip) usize {
        return @intCast((self._reg_ir & 0x00F0) >> 4);
    }
};
