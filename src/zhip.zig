const std = @import("std");

const DISPLAY_WIDTH: usize = 64;
const DISPLAY_HEIGHT: usize = 32;
const MEMORY_SIZE: usize = 4*1024;
const STACK_SIZE: usize = 16;

// Struct that represents a chip 8 emulator
pub const Zhip = struct {
    _ram: [MEMORY_SIZE]u8,
    _reg: [16]u8, // 16 8-bit registers
    _reg_i: u16, // 16 bit register to hold address (only 12 right most bits are used for 4k memory size. applicable for all address based registers and stack)
    _reg_dt: u8, // 8 bit delay timer register
    _reg_st: u8, // 8 bit sound timer resiter
    _reg_ir: u16, // 16 bit register to hold the current instruction
    _pc: u16,// 16 bit program counter (rightmost 12 bits)
    _sp: u8, // stack pointer
    _stack: [STACK_SIZE]u16, // stack to hold return address from subroutine , can hold 16 addresses so 16 level of nested subroutine calls

    graphics: [DISPLAY_HEIGHT][DISPLAY_WIDTH]u8, // display
    keys: [16]u8, // input keys state


    pub fn init() Zhip {
        var zhip =  Zhip {
            ._ram = undefined,
            ._reg= undefined,
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
            0xF0, 0x80, 0xF0, 0x80, 0x80,  // F
        };
        @memcpy(zhip._ram[0x50..0xA0], &chracters_sprite);

        return zhip;
    }

    pub fn loadRomFromFile(self: *Zhip, filename: []const u8) !void {
        const file = try std.fs.cwd().openFile(filename, .{});
        _ = try file.readAll(self._ram[0x200..]);
        self._pc = 0x200;
    }

    pub fn run(self: *Zhip) void {
        self.fetch();
    }

    fn fetch(self: *Zhip) void {
        self._reg_ir = self._ram[self._pc];
        self._pc += 1;
        self._reg_ir <<= 8;
        self._reg_ir += self._ram[self._pc];
    }
};
