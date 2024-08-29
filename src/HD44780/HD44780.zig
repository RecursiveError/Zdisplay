pub const lcd_interface_callback = fn (config: u8, data: u8) void;
pub const lcd_delayus_callback = fn (delay: u32) void;

pub const Lcd_commands = enum(u8) { lcd_clear = 0x01, lcd_reset = 0x02, lcd_shift_cursor_left = 0x10, lcd_shift_cursor_right = 0x14, lcd_shift_display_left = 0x18, lcd_shift_display_right = 0x1C };

//lcd "function set" enums
const Function_set = enum(u8) { lcd_line = 0x8, lcd_bus = 0x10, lcd_char = 0x4 };
pub const Bussize = enum { bus4bits, bus8bits };
pub const Charsize = enum { char5x8, char5x10 };

//lcd "entry mode" enum
const Entry_mode = enum(u8) { lcd_shift_mode = 0x1, lcd_shift_dir = 0x2 };

//lcd "display control" enum
const Display_control = enum(u8) { lcd_blink = 0x01, lcd_cursor = 0x02, lcd_display = 0x04 };

pub const HD44780 = struct {
    //internal config vars
    function_set: u8,
    entry_mode: u8,
    display_control: u8,
    enable_set: u8,
    full_bus: bool,

    //internal_callbacks
    internal_delay: *const lcd_delayus_callback,
    interface: *const lcd_interface_callback,

    //LCD functions

    //create a new LCD without set configs

    fn send8bits(Self: *HD44780, data: u8, rs_state: u1) void {
        Self.interface(rs_state, data);
        Self.interface(rs_state | Self.enable_set, data);
        Self.internal_delay(1);
        Self.interface(rs_state, data);
    }

    fn send4bits(Self: *HD44780, data: u8, rs_state: u1) void {
        const high_nibble: u8 = data & 0xF0;
        const low_nibble: u8 = data << 4;
        Self.send8bits(high_nibble, rs_state);
        Self.internal_delay(1);
        Self.send8bits(low_nibble, rs_state);
    }

    //Low level sendfunction
    pub fn send(Self: *HD44780, data: u8, rs_state: u1) *HD44780 {
        if (Self.full_bus) {
            Self.send8bits(data, rs_state);
        } else {
            Self.send4bits(data, rs_state);
        }

        if (rs_state == 0) {
            Self.internal_delay(40);
        } else {
            Self.internal_delay(2);
        }
        return Self;
    }
    //config functions
    pub fn set_bus_size(Self: *HD44780, size: Bussize) *HD44780 {
        if (size == Bussize.bus4bits) {
            Self.function_set &= ~@intFromEnum(Function_set.lcd_bus);
            Self.full_bus = false;
        } else {
            Self.function_set |= @intFromEnum(Function_set.lcd_bus);
            Self.full_bus = true;
        }
        return Self;
    }

    pub fn set_char_size(Self: *HD44780, charsize: Charsize) *HD44780 {
        if (charsize == Charsize.char5x8) {
            Self.function_set &= ~@intFromEnum(Function_set.lcd_char);
        } else {
            Self.function_set |= @intFromEnum(Function_set.lcd_char);
        }
        return Self;
    }

    //========== commands functions ==========

    //TODO: change left/right to dec/inc

    //low level command function
    pub inline fn command(Self: *HD44780, cmd: Lcd_commands) void {
        _ = Self.send(@intFromEnum(cmd), 0);
    }

    pub fn screen_clear(Self: *HD44780) *HD44780 {
        Self.command(Lcd_commands.lcd_clear);
        Self.internal_delay(1600); //clear and reset need to delay >1.6ms
        return Self;
    }

    pub fn reset_cursor(Self: *HD44780) *HD44780 {
        Self.command(Lcd_commands.lcd_reset);
        Self.internal_delay(1600); //clear and reset need to delay >1.6ms
        return Self;
    }

    pub fn shift_cursor_left(Self: *HD44780) *HD44780 {
        Self.command(Lcd_commands.lcd_shift_cursor_left);
        return Self;
    }

    pub fn shift_cursor_right(Self: *HD44780) *HD44780 {
        Self.command(Lcd_commands.lcd_shift_cursor_right);
        return Self;
    }

    pub fn shift_display_left(Self: *HD44780) *HD44780 {
        Self.command(Lcd_commands.lcd_shift_display_left);
        return Self;
    }

    pub fn shift_display_right(Self: *HD44780) *HD44780 {
        Self.command(Lcd_commands.lcd_shift_display_right);
        return Self;
    }

    //control functions

    pub fn shift_enable(Self: *HD44780) *HD44780 {
        Self.entry_mode |= Entry_mode.lcd_shift_mode;
        return Self;
    }

    pub fn shift_disable(Self: *HD44780) *HD44780 {
        Self.entry_mode &= ~Entry_mode.lcd_shift_mode;
        return Self;
    }

    pub fn shift_inc_mode(Self: *HD44780) *HD44780 {
        Self.entry_mode |= Entry_mode.lcd_shift_dir;
        return Self;
    }

    pub fn shift_dec_mode(Self: *HD44780) *HD44780 {
        Self.entry_mode &= ~Entry_mode.lcd_shift_dir;
        return Self;
    }

    pub fn display_enable(Self: *HD44780) *HD44780 {
        Self.display_control |= Display_control.lcd_display;
        return Self;
    }

    pub fn display_disable(Self: *HD44780) *HD44780 {
        Self.display_control &= ~Display_control.lcd_display;
        return Self;
    }

    pub fn cursor_enable(Self: *HD44780) *HD44780 {
        Self.display_control |= Display_control.lcd_cursor;
        return Self;
    }

    pub fn cursor_disable(Self: *HD44780) *HD44780 {
        Self.display_control &= ~Display_control.lcd_cursor;
        return Self;
    }

    pub fn cursor_blink_enable(Self: *HD44780) *HD44780 {
        Self.display_control |= Display_control.lcd_blink;
        return Self;
    }

    pub fn cursor_blink_disable(Self: *HD44780) *HD44780 {
        Self.display_control &= ~Display_control.lcd_blink;
        return Self;
    }

    //util functions
    pub fn apply_configs(Self: *HD44780) *HD44780 {
        _ = Self.send(Self.function_set, 0);
        return Self;
    }

    pub fn apply_control(Self: *HD44780) *HD44780 {
        _ = Self.send(Self.entry_mode, 0);
        _ = Self.send(Self.display_control, 0);
        return Self;
    }

    pub fn select_all(Self: *HD44780) *HD44780 {
        Self.enable_set = 0b1100;
        return Self;
    }
    pub inline fn select_lcd(Self: *HD44780, en: u1) *HD44780 {
        Self.enable_set = 1 << en;
        return Self;
    }

    pub fn set_cursor(Self: *HD44780, line: u8, col: u8) *HD44780 {
        const addrs = [_]u8{ 0x80, 0xC0 };
        if ((line < 2) and (col < 40)) {
            _ = Self.send(addrs[line] | col, 0);
        }
    }

    pub fn create_custom_char(Self: *HD44780, new_char: [8]u8, mem_addr: u8) *HD44780 {
        const mem_aux = ((mem_addr & 0b111) << 3) | 0x40;
        _ = Self.send(mem_aux, 0);
        for (new_char) |line| {
            _ = Self.send(line, 1);
        }
        return Self;
    }

    pub fn write(Self: *HD44780, text: []const u8, len: u32) *HD44780 {
        for (0..len) |index| {
            _ = Self.send(text[index], 1);
        }
        return Self;
    }

    pub fn init(Self: *HD44780) *HD44780 {
        //_ = Self.select_all();
        Self.internal_delay(55000); //power on wait time + init time (datasheet: power up time = more than 40ms | begin time = more than 15ms)
        Self.send8bits(0x30, 0);
        Self.internal_delay(4100);
        Self.send8bits(0x30, 0);
        Self.internal_delay(100);
        Self.send8bits(0x30, 0);
        Self.internal_delay(100);
        Self.send8bits(0x20, 0);
        _ = Self.apply_configs()
            .screen_clear()
            .reset_cursor()
            .apply_control();
        return Self;
    }
};

pub fn new(delay_callback: *const lcd_delayus_callback, interface: *const lcd_interface_callback) HD44780 {
    const lcd = HD44780{
        .function_set = 0, //config by the user
        .entry_mode = 0x06, // shift Off, written from left to right
        .display_control = 0x0C, // display on, cursor off, cursor blinking off
        .enable_set = 0b1100,
        .full_bus = false, //4bits by
        .internal_delay = delay_callback,
        .interface = interface,
    };
    return lcd;
}
