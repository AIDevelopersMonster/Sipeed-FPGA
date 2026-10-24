// SD-03.3 controller: SD-02 read-one-LBA handshake and 512-byte sync BSRAM
// -> MBR + FAT32 BPB validation. Never writes the SD card.
// The first sector is tested as MBR AND a possible superfloppy VBR.
// MBR FAT32 candidates get an additional physical CMD17 read at partition LBA.
// GPT and invalid/non-FAT32 formats return unsupported/not-found status.
// Verilog-2005. SPDX-License-Identifier: MIT
module sd03_volume_scanner (
 input wire clk, input wire reset_n, input wire start,
 output reg sd_start, output reg [31:0] sd_lba,
 input wire sd_busy, input wire sd_done, input wire [7:0] sd_error,
 output reg [8:0] peek_addr, input wire [7:0] peek_data,
 output reg done, output reg [3:0] result,
 output reg [31:0] volume_lba, fat_lba, data_lba, root_lba,
 output reg [31:0] cluster_count
);
 // result: 0 pending; 1 FAT32 via MBR; 2 FAT32 superfloppy;
 // 3 GPT unsupported; 4 no valid FAT32; 5 SD read error;
 // 6 second-stage invalid BPB.
 localparam [3:0] IDLE=0,READ_WAIT=1,PARSE_START=2,
  RAM_WAIT=3,RAM_SAMPLE=4,DRAIN=5,DECIDE=6,
  NEXT_READ=7,FINISH=8;
 reg [3:0] state;
 reg second_sector;
 reg parser_start, parser_valid;
 reg [8:0] parser_index;
 reg [7:0] parser_byte;
 reg [8:0] ix;
 reg [31:0] parser_base,parser_bound;
 reg [31:0] pending_lba,pending_sectors;
 wire mbr_done,bpb_done;
 wire [2:0] mbr_status,bpb_status;
 wire [31:0] partition_lba,partition_sectors;
 wire [7:0] partition_type;
 wire [1:0] partition_index;
 wire [31:0] bpb_fat,bpb_data,bpb_root,bpb_clusters;
 wire [31:0] bpb_total,bpb_fatsz,bpb_rootclus;
 wire [7:0] bpb_spc;
 sd03_mbr_parser u_mbr(
 .clk(clk),.reset_n(reset_n),.start(parser_start && !second_sector),
 .byte_valid(parser_valid && !second_sector),.byte_index(parser_index),
 .byte_data(parser_byte),.done(mbr_done),.status(mbr_status),
 .partition_lba(partition_lba),.partition_sectors(partition_sectors),
 .partition_type(partition_type),.partition_index(partition_index)
 );
 sd03_fat32_bpb u_bpb(
 .clk(clk),.reset_n(reset_n),.start(parser_start),
 .volume_lba(parser_base),.partition_sectors(parser_bound),
 .byte_valid(parser_valid),.byte_index(parser_index),.byte_data(parser_byte),
 .done(bpb_done),.status(bpb_status),
 .fat_lba(bpb_fat),.data_lba(bpb_data),.root_lba(bpb_root),
 .cluster_count(bpb_clusters),.total_sectors(bpb_total),
 .fat_sectors(bpb_fatsz),.root_cluster(bpb_rootclus),
 .sectors_per_cluster(bpb_spc)
 );
 always @(posedge clk or negedge reset_n) begin
  if(!reset_n)begin
   state<=IDLE;sd_start<=0;sd_lba<=0;peek_addr<=0;
   done<=0;result<=0;volume_lba<=0;fat_lba<=0;
   data_lba<=0;root_lba<=0;cluster_count<=0;
   second_sector<=0;parser_start<=0;parser_valid<=0;
   parser_index<=0;parser_byte<=0;ix<=0;
   parser_base<=0;parser_bound<=0;pending_lba<=0;pending_sectors<=0;
  end else begin
   done<=0;sd_start<=0;parser_start<=0;parser_valid<=0;
   case(state)
    IDLE:if(start)begin
      result<=0;volume_lba<=0;fat_lba<=0;data_lba<=0;
      root_lba<=0;cluster_count<=0;second_sector<=0;
      parser_base<=0;parser_bound<=0;sd_lba<=0;
      sd_start<=1;state<=READ_WAIT;
    end
    READ_WAIT:if(sd_done)begin
      if(sd_error!=0)begin result<=5;state<=FINISH;end
      else state<=PARSE_START;
    end
    PARSE_START:begin
      parser_start<=1;ix<=0;peek_addr<=0;
      state<=RAM_WAIT;
    end
    RAM_WAIT:state<=RAM_SAMPLE;
    RAM_SAMPLE:begin
      parser_index<=ix;parser_byte<=peek_data;parser_valid<=1;
      if(ix==511)state<=DRAIN;
      else begin ix<=ix+1'b1;peek_addr<=ix+1'b1;state<=RAM_WAIT;end
    end
    DRAIN:state<=DECIDE; // one cycle for parser to sample last byte
    DECIDE:begin
      if(second_sector)begin
        if(bpb_done && bpb_status==1)begin
          result<=1;volume_lba<=pending_lba;
          fat_lba<=bpb_fat;data_lba<=bpb_data;root_lba<=bpb_root;
          cluster_count<=bpb_clusters;
        end else result<=6;
        state<=FINISH;
      end else if(mbr_done && mbr_status==4)begin
        result<=3;state<=FINISH;
      end else if(mbr_done && mbr_status==1)begin
        pending_lba<=partition_lba;
        pending_sectors<=partition_sectors;
        sd_lba<=partition_lba;
        parser_base<=partition_lba;
        parser_bound<=partition_sectors;
        second_sector<=1;
        state<=NEXT_READ;
      end else if(bpb_done && bpb_status==1)begin
        result<=2;volume_lba<=0;
        fat_lba<=bpb_fat;data_lba<=bpb_data;root_lba<=bpb_root;
        cluster_count<=bpb_clusters;state<=FINISH;
      end else begin result<=4;state<=FINISH;end
    end
    NEXT_READ:begin sd_start<=1;state<=READ_WAIT;end
    FINISH:begin done<=1;state<=IDLE;end
    default:state<=IDLE;
   endcase
  end
 end
 wire _unused_sd_busy=sd_busy;
 wire _unused_partition_info=^partition_type ^ ^partition_index;
endmodule
