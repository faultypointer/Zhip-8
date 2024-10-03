const std = @import("std");

pub const DISPLAY_WIDTH: usize = 64;
pub const DISPLAY_HEIGHT: usize = 32;
const MEMORY_SIZE: usize = 4 * 1024;
const STACK_SIZE: usize = 16;
const CHARACTER_SPRITE_START: usize = 0x50;

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
        @memcpy(zhip._ram[CHARACTER_SPRITE_START..0xA0], &chracters_sprite);

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

        // independent of run cycle??
        if (self._reg_dt > 0) {
            self._reg_dt -= 1;
        }
        if (self._reg_st > 0) {
            self._reg_st -= 1;
        }
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
                    0xE => self.returnFromSubroutine(),
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
            0xC => self.setRegisterRandom(),
            0xD => self.drawSprite(),
            0xE => {
                switch (self._reg_ir & 0x00FF) {
                    0x9E => self.skipIfKeyUp(),
                    0xA1 => self.skipIfKeyDown(),
                    else => self.panicOnUnknownInstruction(),
                }
            },
            0xF => {
                switch (self._reg_ir & 0xFF) {
                    0x07 => self.setRegisterToDelay(),
                    0x0A => self.waitUntilKeyPress(),
                    0x15 => self.setDelayToRegister(),
                    0x18 => self.setSoundToRegister(),
                    0x1E => self.addToIRegister(),
                    0x29 => self.setIRegisterToCharacter(),
                    0x33 => self.storeBCD(),
                    0x55 => self.storeRegistersInMemory(),
                    0x65 => self.loadRegistersFromMemory(),
                    else => self.panicOnUnknownInstruction(),
                }
            },
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
        const Vx: u8 = self._reg[self.getXIndex()];
        const nibble: u8 = @truncate(self._reg_ir);
        if (Vx == nibble) {
            self._pc += 2;
        }
    }

    // 0x4XNN; skips if Vx not equal to NN
    fn skipNextInstructionIfNotEqual(self: *Zhip) void {
        const Vx: u8 = self._reg[self.getXIndex()];
        const nibble: u8 = @truncate(self._reg_ir);
        if (Vx != nibble) {
            self._pc += 2;
        }
    }

    // 0x5XY0
    fn skipNextInstructionIfVxEqualsVy(self: *Zhip) void {
        const Vx: u8 = self._reg[self.getXIndex()];
        const Vy: u8 = self._reg[self.getYIndex()];
        if (Vx == Vy) {
            self._pc += 2;
        }
    }

    // 0x9XY0
    fn skipNextInstructionIfVxNotEqualsVy(self: *Zhip) void {
        const Vx: u8 = self._reg[self.getXIndex()];
        const Vy: u8 = self._reg[self.getYIndex()];
        if (Vx != Vy) {
            self._pc += 2;
        }
    }
    // 0x8XY0;
    // all the instructions of this type involves register Vx or Vy or both
    fn handle8XY(self: *Zhip) void {
        const Vx = &self._reg[self.getXIndex()];
        const Vy = &self._reg[self.getYIndex()];
        const nibble: u4 = @truncate(self._reg_ir);
        switch (nibble) {
            0x0 => Vx.* = Vy.*,
            0x1 => Vx.* = Vx.* | Vy.*,
            0x2 => Vx.* = Vx.* & Vy.*,
            0x3 => Vx.* = Vx.* ^ Vy.*,
            0x4 => {
                const big_vx: u16 = @intCast(Vx.*);
                const big_vy: u16 = @intCast(Vy.*);
                const result: u16 = big_vx + big_vy;
                Vx.* = @truncate(result);
                self._reg[0xF] = @truncate(result >> 8);
            },
            0x5, 0x7 => {
                const signed_vx: i16 = @intCast(Vx.*);
                const signed_vy: i16 = @intCast(Vy.*);
                var result: i16 = signed_vx - signed_vy;
                if (nibble == 0x7) {
                    result = -result;
                }
                if (result < 0) {
                    self._reg[0xF] = 0;
                    Vx.* = @intCast(0x100 + result);
                } else {
                    self._reg[0xF] = 1;
                    Vx.* = @intCast(result);
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
        const byte: u8 = @truncate(self._reg_ir & 0x00FF);
        const result = @addWithOverflow(self._reg[index], byte);
        self._reg[index] = result.@"0";
    }

    // ANNN; I register is set to NNN
    fn loadIRegister(self: *Zhip) void {
        const addr = self._reg_ir & 0x0FFF;
        self._reg_i = addr;
    }

    // CXNN; generate a random byte, AND it with NN and store in Vx
    fn setRegisterRandom(self: *Zhip) void {
        var prng = std.rand.DefaultPrng.init(blk: {
            var seed: u64 = undefined;
            std.posix.getrandom(std.mem.asBytes(&seed)) catch unreachable;
            break :blk seed;
        });
        const rand = prng.random();
        const byte: u8 = @truncate(self._reg_ir);
        self._reg[self.getXIndex()] = rand.int(u8) & byte;
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

    // EX9E; skip if the key with value Vx is pressed
    fn skipIfKeyDown(self: *Zhip) void {
        if (self.keys[self._reg[self.getXIndex()]] == 1) {
            self._pc += 2;
        }
    }

    // EXA1 skip if the key with value Vx is pressed
    fn skipIfKeyUp(self: *Zhip) void {
        if (self.keys[self._reg[self.getXIndex()]] == 0) {
            self._pc += 2;
        }
    }
    // 0xFX07 set register Vx to value in delay timer register
    fn setRegisterToDelay(self: *Zhip) void {
        self._reg[self.getXIndex()] = self._reg_dt;
    }
    // 0xFX15 set delay timer register to value in Vx
    fn setDelayToRegister(self: *Zhip) void {
        self._reg_dt = self._reg[self.getXIndex()];
    }
    // 0xFX18 set sound timer register to value in Vx
    fn setSoundToRegister(self: *Zhip) void {
        self._reg_st = self._reg[self.getXIndex()];
    }
    // 0xFX1E; adds Value in Vx to value in I register, result in I
    fn addToIRegister(self: *Zhip) void {
        self._reg_i += self._reg[self.getXIndex()];
    }
    // 0xFX29; loads the location of sprite of character in Vx
    fn setIRegisterToCharacter(self: *Zhip) void {
        const start: u16 = @intCast(CHARACTER_SPRITE_START);
        self._reg_i = start + (self._reg[self.getXIndex()] & 0x0F) * 5;
    }
    // 0xFX0A; execution stops until key is pressed
    fn waitUntilKeyPress(self: *Zhip) void {
        var key_pressed = false;
        for (0..0xF) |i| {
            if (self.keys[i] == 1) {
                self._reg[self.getXIndex()] = @truncate(i);
                key_pressed = true;
            }
        }
        if (!key_pressed) {
            self._pc -= 2;
        }
    }

    // 0xFx33 store bcd repr of Vx in I, I+1, I+2
    fn storeBCD(self: *Zhip) void {
        var Vx = self._reg[self.getXIndex()];

        self._ram[self._reg_i + 2] = Vx % 10;
        Vx /= 10;
        self._ram[self._reg_i + 1] = Vx % 10;
        self._ram[self._reg_i] = Vx / 10;
    }
    // 0xFX55; store register V0 to Vx(inclusive) in memory
    fn storeRegistersInMemory(self: *Zhip) void {
        const X = self.getXIndex();
        for (0..X + 1) |i| {
            self._ram[self._reg_i + i] = self._reg[i];
        }
    }
    // 0xFX65; load register V0 to Vx(inclusive) from memory
    fn loadRegistersFromMemory(self: *Zhip) void {
        const X = self.getXIndex();
        for (0..X + 1) |i| {
            self._reg[i] = self._ram[self._reg_i + i];
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
