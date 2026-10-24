// SD-03 MBR partition selector. Byte-stream input, one sector exactly.
// No filesystem assumptions and no SD writes. Verilog-2005.
// LBA0 bytes 446..509 contain four 16-byte entries; 510..511 = 55 AA.
// SPDX-License-Identifier: MIT
module sd03_mbr_parser (
  input wire clk, input wire reset_n, input wire start,
  input wire byte_valid, input wire [8:0] byte_index,
  input wire [7:0] byte_data,
  output reg done, output reg [2:0] status,
  output reg [31:0] partition_lba, output reg [31:0] partition_sectors,
  output reg [7:0] partition_type, output reg [1:0] partition_index
);
  // status: 0 pending, 1 FAT32 MBR, 2 no FAT32 entry,
  // 3 invalid signature, 4 protective GPT, 5 malformed entry.
  reg active, sig55, sigaa, found, gpt;
  reg [31:0] cand_lba,cand_size;
  reg [7:0] cand_type;
  reg [7:0] ty[0:3];
  reg [31:0] ls[0:3],sz[0:3];
  reg [7:0] boot[0:3];
  integer i;
  integer slot,off;
  always @(posedge clk or negedge reset_n) begin
    if(!reset_n) begin
      active<=0;done<=0;status<=0;partition_lba<=0;
      partition_sectors<=0;partition_type<=0;partition_index<=0;
      sig55<=0;sigaa<=0;found<=0;gpt<=0;
      cand_lba<=0;cand_size<=0;cand_type<=0;
      for(i=0;i<4;i=i+1)begin ty[i]<=0;ls[i]<=0;sz[i]<=0;boot[i]<=0;end
    end else begin
      done<=0;
      if(start)begin
        active<=1;status<=0;sig55<=0;sigaa<=0;found<=0;gpt<=0;
        partition_lba<=0;partition_sectors<=0;partition_type<=0;partition_index<=0;
        for(i=0;i<4;i=i+1)begin ty[i]<=0;ls[i]<=0;sz[i]<=0;boot[i]<=0;end
      end else if(active && byte_valid) begin
        if(byte_index==9'd510)sig55<=byte_data==8'h55;
        if(byte_index==9'd511)begin
          sigaa<=byte_data==8'haa;
          active<=0;done<=1;
          if(!sig55 || byte_data!=8'haa)status<=3;
          else if(ty[0]==8'hee)status<=4;
          else begin
            // Type 0B and 0C indicate FAT32, but BPB must be verified separately.
            status<=2;
            for(i=3;i>=0;i=i-1)
              if((ty[i]==8'h0b || ty[i]==8'h0c) && ls[i]!=0 && sz[i]!=0 &&
                 (boot[i]==8'h00 || boot[i]==8'h80))begin
                partition_lba<=ls[i];partition_sectors<=sz[i];
                partition_type<=ty[i];partition_index<=i;
                status<=1;
              end
          end
        end
        if(byte_index>=9'd446 && byte_index<=9'd509)begin
          slot=(byte_index-9'd446)/16;
          off=(byte_index-9'd446)%16;
          if(off==0)boot[slot]<=byte_data;
          if(off==4)ty[slot]<=byte_data;
          case(off)
            8:ls[slot][7:0]<=byte_data;
            9:ls[slot][15:8]<=byte_data;
            10:ls[slot][23:16]<=byte_data;
            11:ls[slot][31:24]<=byte_data;
            12:sz[slot][7:0]<=byte_data;
            13:sz[slot][15:8]<=byte_data;
            14:sz[slot][23:16]<=byte_data;
            15:sz[slot][31:24]<=byte_data;
          endcase
        end
      end
    end
  end
endmodule
