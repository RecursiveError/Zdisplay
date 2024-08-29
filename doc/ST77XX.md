# ST77XX Port guide
To create a display implementation, you need to implement the following callbacks:

`fn delay(delayus: u32) void`:
This is the function responsible for the driver's internal delay *IN MICROSECONDS*.

`fn send(ST77XXTransType, []const u8, *const anyopaque) ST77XXError!void`:This is the callback responsible for sending the information to the display, it receives:
- `ST77XXTransType`: The Transaction Type.
- `[]const u8`: an array containing all the bytes of the transaction.
- `*const anyopaque`: user data for the callback.


`fn gpio_set(RESET: i2, DC: i2) ST77XXError!void`:
function that receives the status of the DC and RESET GPIOs of the display:
- `-1`: indicates that the pin state should not be changed.
- `1`: indicates that the pin state should be in its ENABLE value.
- `0`: indicates that the pin state should be in its DISABLE value.

If the display used does not have these pins, the arguments can be ignored, in this case you must set the DC bit manually based on the transaction type of the `send` callback.
 
# Display-specific commands

certain types of displays have more instructions than the standard ST77XX or require more settings at startup, in which case use the functions: `custom_command` and `custom_init`

# Example of implementation in MicrozIg

```Zig
const std = @import("std");
const microzig = @import("microzig");
const zDisplay = @import("zDisplay");
const ST = zDisplay.ST77XX;

const timer = rp2040.time;

const rp2040 = microzig.hal;
const gpio = rp2040.gpio;
const peripherals = microzig.chip.peripherals;
const spi = rp2040.spi.instance.SPI0;
const BUF_LEN = 0x100;
const H_RES = 128;
const V_RES = 160;
const LEN_RES = H_RES * V_RES;

pub fn delay_us(time_delay: u32) void {
    timer.sleep_us(time_delay);
}

fn send(transtipe: ST.ST77XXTransType, data: []const u8, user_params: *const anyopaque) ST.ST77XXError!void {
    const cs_pin = rp2040.gpio.num(8);
    cs_pin.put(0);
    _ = spi.write_blocking(u8, data);
    _ = transtipe;
    _ = user_params;
    cs_pin.put(1);
}

fn gpio_set(RESET: i2, DC: i2) ST.ST77XXError!void {
    const DC_pin = gpio.num(6);
    const RESET_pin = gpio.num(7);

    if (RESET != -1) {
        RESET_pin.put(@intCast(RESET));
    }
    if (DC != -1) {
        DC_pin.put(@intCast(DC));
    }
}

pub fn main() !void {

    //pin config
    const SCLK = gpio.num(2);
    const MOSI = gpio.num(3);
    const led = gpio.num(5);
    const dc_pin = gpio.num(6);
    const reset_pin = gpio.num(7);
    const cs_pin = gpio.num(8);
    inline for (&.{ led, dc_pin, reset_pin, cs_pin }) |pin| {
        pin.set_function(.sio);
        pin.set_direction(.out);
    }
    //SPI Config
    cs_pin.put(1);
    led.put(1);
    SCLK.set_function(.spi);
    MOSI.set_function(.spi);
    try spi.apply(.{
        .clock_config = rp2040.clock_config,
        .data_width = .eight,
    });

    // zDisplay Driver
    var my_display = ST.new(send, gpio_set, delay_us, H_RES, V_RES, ST.ST77XXRGBEndian.BGR, ST.ST77XXColorSize.COLOR_16, undefined);
    try my_display.reset();
    try my_display.init();
    try my_display.display_ctrl(ST.DisplayCtrl.display_on);
    timer.sleep_ms(1000);
    var buffer: [LEN_RES]u16 = std.mem.zeroes([LEN_RES]u16);
    while (true) {
        for (0..0xFFFF) |color| {
            @memset(&buffer, @intCast(color));
            const cast: *[LEN_RES * 2]u8 = @ptrCast(&buffer);
            try my_display.send_pixel_map(0, H_RES, 0, V_RES, &cast.*);
        }
    }
}

```



