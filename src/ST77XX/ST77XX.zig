pub const ST77XXError = error{
    invalid_args,
    invalid_fn,
    trintFromEnummit_error,
};

pub const ST77XXCommand = enum(u8) { NOP = 0x00, SWRESET = 0x01, RDDID = 0x04, RDDST = 0x09, RDDPM = 0x0A, RDD_MADCTL = 0x0B, RDD_COLMOD = 0x0C, RDDIM = 0x0D, RDDSM = 0x0E, SLPIN = 0x10, SLPOUT = 0x11, PTLON = 0x12, NORON = 0x13, INVOFF = 0x20, INVON = 0x21, GAMSET = 0x26, DISPOFF = 0x28, DISPON = 0x29, CASET = 0x2A, RASET = 0x2B, RAMWR = 0x2C, RAMRD = 0x2E, PTLAR = 0x30, TEOFF = 0x34, TEON = 0x35, MADCTL = 0x36, IDMOFF = 0x38, IDMON = 0x39, COLMOD = 0x3A, RDID1 = 0xDA, RDID2 = 0xDB, RDID3 = 0xDC };
pub const ST77XXTransType = enum { command, param, data };
pub const ST77XXRGBEndian = enum(u8) { BGR = 0, RGB = 1 << 3 };
pub const ST77XXColorSize = enum(u8) { COLOR_12 = 0b011, COLOR_16 = 0b101, COLOR_18 = 0b110 };

pub const DisplayCtrl = enum(u8) { display_on = 0x29, display_off = 0x28 };

pub const ST77XX_interface_callback = fn (transtype: ST77XXTransType, data: []const u8, user_params: *const anyopaque) ST77XXError!void;

pub const ST77XX_pinctrl_callback = fn (RESET: i2, DC: i2) ST77XXError!void;

pub const ST77XX_delayus_callback = fn (delayus: u32) void;

pub const ST77XX = struct {
    ver_res: u32,
    hoz_res: u32,
    madctl_state: u8,
    colmod_state: u8,
    x_offset: u9,
    y_offset: u8,
    interface: *const ST77XX_interface_callback,
    io_interface: *const ST77XX_pinctrl_callback,
    delay: *const ST77XX_delayus_callback,
    user_data: *const anyopaque,

    fn internal_interface(Self: *ST77XX, transtype: ST77XXTransType, data: []const u8, user_params: *const anyopaque) ST77XXError!void {
        var DC_state = @as(i2, -1);
        switch (transtype) {
            ST77XXTransType.command => {
                DC_state = 0;
            },
            ST77XXTransType.data => {
                DC_state = 1;
            },
            ST77XXTransType.param => {
                DC_state = 1;
            },
        }
        try Self.io_interface(-1, DC_state);
        try Self.interface(transtype, data, user_params);
    }

    pub fn custom_command(Self: *ST77XX, data_cmd: [][]const u8, cmd_delay: u32) ST77XXError!void {
        try Self.internal_interface(ST77XXTransType.command, data_cmd[0..1], Self.user_data);
        if (data_cmd.len > 1) {
            try Self.internal_interface(ST77XXTransType.param, data_cmd[1..], Self.user_data);
        }
        if (cmd_delay > 0) {
            Self.delay(cmd_delay);
        }
    }

    pub fn custom_init(Self: *ST77XX, init_cmd: [][]const u8) ST77XXError!void {
        try Self.internal_interface(ST77XXTransType.command, &[_]u8{@intFromEnum(ST77XXCommand.SLPOUT)}, Self.user_data);
        Self.delay(120 * 1000);
        for (init_cmd) |cmd| {
            if (cmd[0] == @intFromEnum(ST77XXCommand.MADCTL)) {
                Self.madctl_state = cmd[1];
            } else if (cmd[0] == @intFromEnum(ST77XXCommand.COLMOD)) {
                Self.colmod_state = cmd[1];
            }
            try Self.custom_command(init_cmd, 0);
        }
    }

    pub fn init(Self: *ST77XX) ST77XXError!void {
        try Self.internal_interface(ST77XXTransType.command, &[_]u8{@intFromEnum(ST77XXCommand.SLPOUT)}, Self.user_data);
        Self.delay(120 * 1000);
        try Self.internal_interface(ST77XXTransType.command, &[_]u8{@intFromEnum(ST77XXCommand.MADCTL)}, Self.user_data);
        try Self.internal_interface(ST77XXTransType.param, &[_]u8{Self.madctl_state}, Self.user_data);
        try Self.internal_interface(ST77XXTransType.command, &[_]u8{@intFromEnum(ST77XXCommand.COLMOD)}, Self.user_data);
        try Self.internal_interface(ST77XXTransType.param, &[_]u8{Self.colmod_state}, Self.user_data);
    }

    pub fn reset(Self: *ST77XX) ST77XXError!void {
        try Self.io_interface(0, -1);
        Self.delay(10 * 1000);
        try Self.io_interface(1, -1);
        Self.delay(10 * 1000);
        Self.delay(120 * 1000);
    }

    pub fn display_ctrl(Self: *ST77XX, display_conf: DisplayCtrl) ST77XXError!void {
        try Self.internal_interface(ST77XXTransType.command, &[_]u8{@intFromEnum(display_conf)}, Self.user_data);
        Self.delay(120 * 1000);
    }

    pub fn invert_color_ctrl(Self: *ST77XX) ST77XXError!void {
        _ = Self; //Todo
    }

    pub fn invert_axis_ctrl(Self: *ST77XX) ST77XXError!void {
        _ = Self; //Todo
    }
    pub fn send_pixel_map(Self: *ST77XX, x0: u32, x1: u32, y0: u32, y1: u32, color_map: []const u8) ST77XXError!void {
        //error checks
        if ((x0 >= x1) or (y0 >= y1)) {
            return ST77XXError.invalid_args;
        }
        if ((x1 > Self.hoz_res) or (y1 > Self.ver_res)) {
            return ST77XXError.invalid_args;
        }
        const col_start = x0 + Self.x_offset;
        const col_end = x1 + Self.x_offset;
        const row_start = y0 + Self.y_offset;
        const row_end = y1 + Self.y_offset;
        try Self.internal_interface(ST77XXTransType.command, &[_]u8{@intFromEnum(ST77XXCommand.CASET)}, Self.user_data);
        try Self.internal_interface(ST77XXTransType.param, &[_]u8{ @intCast(((col_start >> 8) & 0xFF)), @intCast((col_start & 0xFF)), @intCast(((col_end - 1) >> 8) & 0xFF), @intCast(((col_end - 1) & 0xFF)) }, Self.user_data);
        try Self.internal_interface(ST77XXTransType.command, &[_]u8{@intFromEnum(ST77XXCommand.RASET)}, Self.user_data);
        try Self.internal_interface(ST77XXTransType.param, &[_]u8{ @intCast(((row_start >> 8) & 0xFF)), @intCast((row_start & 0xFF)), @intCast(((row_end - 1) >> 8) & 0xFF), @intCast(((row_end - 1) & 0xFF)) }, Self.user_data);
        try Self.internal_interface(ST77XXTransType.command, &[_]u8{@intFromEnum(ST77XXCommand.RAMWR)}, Self.user_data);
        try Self.internal_interface(ST77XXTransType.param, color_map, Self.user_data);
        try Self.internal_interface(ST77XXTransType.command, &[_]u8{@intFromEnum(ST77XXCommand.NOP)}, Self.user_data);
    }
};

pub fn new(interface: *const ST77XX_interface_callback, io_interface: *const ST77XX_pinctrl_callback, delay: *const ST77XX_delayus_callback, horizontal_res: u32, vertical_res: u32, rgb_endian: ST77XXRGBEndian, color_bits_qtd: ST77XXColorSize, user_data: *const anyopaque) ST77XX {
    const madctl = @intFromEnum(rgb_endian);
    const colmod = @intFromEnum(color_bits_qtd);
    const display = ST77XX{ .interface = interface, .io_interface = io_interface, .delay = delay, .user_data = user_data, .madctl_state = madctl, .colmod_state = colmod, .x_offset = 0, .y_offset = 0, .hoz_res = horizontal_res, .ver_res = vertical_res };
    return display;
}
