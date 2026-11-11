// PiKoSoL LAB-04.3.2 synchronous program ROM, generated from lab04_boot.S.
// 4096x32 BRAM inference; readmemh file staged in work/ for Gowin.
module lab04_boot_rom(input wire clk, input wire [11:0] word_addr, output reg [31:0] rdata);
  reg [31:0] rom [0:4095] /* synthesis syn_romstyle = "block_rom" */;
  initial $readmemh("lab04_boot.hex", rom);
  always @(posedge clk) rdata <= rom[word_addr];
endmodule
