// PR25-04 USBH01 - Tang Primer 25K Dock USB-A -> USB-C debugger UART
// Minimal adaptation of thisiseth/tang-primer-25k-spi-io USB Host module.
// No HDMI, no SDRAM, no SD, no external CPU.
// Expected USART on debugger: 115200 8N1 (Prepare_USBH01.ps1 patches BAUDCNT).
`define GW_IDE

module top (
    input  wire clk_50m,
    inout  wire usb_dp,
    inout  wire usb_dn,
    output wire uart_tx,
    input  wire uart_rx
);
    wire clk_usb_48m;
    wire clk_cpu_bram_96m;
    wire pll_lock;

    gowin_pll_usb pll_usb (
        .clkin   (clk_50m),
        .clkout0 (clk_usb_48m),
        .clkout1 (clk_cpu_bram_96m),
        .lock    (pll_lock)
    );

    // usb_host includes: RV32I, USB1.1 PHY/SIE, host firmware and UART.
    // Firmware is already in src/usb_host/ucmem/mem.hex (upstream).
    // It prints "start", "device connect", "std keyboard detected"
    // and "KEYBD: ..." boot HID reports to cpu_uart_tx.
    usb_host host (
        .clk_48m            (clk_usb_48m),
        .clk_cpu_bram_96m    (clk_cpu_bram_96m),
        .reset              (~pll_lock),
        .usb_dp             (usb_dp),
        .usb_dn             (usb_dn),
        .cpu_uart_tx        (uart_tx),
        .cpu_uart_rx        (uart_rx),
        .hid_read           (1'b0),
        .hid_keyboard_connected (),
        .hid_mouse_connected    (),
        .hid_keyboard_modifiers (),
        .hid_keyboard_keycodes  (),
        .hid_mouse_buttons      (),
        .hid_mouse_x            (),
        .hid_mouse_y            (),
        .hid_mouse_wheel        ()
    );
endmodule
