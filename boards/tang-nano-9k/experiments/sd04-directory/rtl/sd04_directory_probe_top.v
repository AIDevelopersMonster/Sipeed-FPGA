// SD-04.2 root-directory first-sector hardware probe, read-only.
// SD03 MBR/BPB discovery -> CMD17(root LBA) -> 32-byte entry parse -> UART.
// Shared SDHC core is not modified. Verilog-2005.
module sd04_directory_probe_top #(
 parameter integer HALF_PERIOD=64,
 parameter integer STARTUP_CYCLES=27000,
 parameter integer UART_BAUD=115200
)(
 input wire clk,input wire reset_n,input wire sd_miso,
 output wire sd_sck,sd_mosi,sd_cs_n,uart_tx,
 output wire [5:0] led_n
);
 reg scanner_start;
 wire scan_sd_start,scan_sd_busy,scan_sd_done;
 wire [31:0] scan_sd_lba;
 wire [7:0] scan_sd_error,peek_data;
 wire [8:0] scan_peek_addr;
 wire scan_done;
 wire [3:0] scan_result;
 wire [31:0] scan_volume,scan_fat,scan_data,scan_root,scan_clusters;
 reg root_read_start;
 reg [31:0] root_read_lba;
 wire sd_busy,sd_done,sd_initialized;
 wire [7:0] sd_error;
 reg [8:0] dir_peek_addr;
 wire [8:0] sd_peek_addr;
 assign sd_peek_addr=scan_mode?scan_peek_addr:dir_peek_addr;
 reg scan_mode;
 wire sd_start=scan_mode?scan_sd_start:root_read_start;
 wire [31:0] sd_lba=scan_mode?scan_sd_lba:root_read_lba;
 lab05_sd_read_sector #(.HALF_PERIOD(HALF_PERIOD),.STARTUP_CYCLES(STARTUP_CYCLES)) u_reader(
  .clk(clk),.reset_n(reset_n),.start(sd_start),.read_lba(sd_lba),
  .sd_miso(sd_miso),.sd_sck(sd_sck),.sd_mosi(sd_mosi),.sd_cs_n(sd_cs_n),
  .busy(sd_busy),.done(sd_done),.initialized(sd_initialized),.error_code(sd_error),
  .peek_addr(sd_peek_addr),.peek_data(peek_data)
 );
 sd03_volume_scanner u_scanner(
  .clk(clk),.reset_n(reset_n),.start(scanner_start),
  .sd_start(scan_sd_start),.sd_lba(scan_sd_lba),
  .sd_busy(sd_busy),.sd_done(sd_done),.sd_error(sd_error),
  .peek_addr(scan_peek_addr),.peek_data(peek_data),
  .done(scan_done),.result(scan_result),
  .volume_lba(scan_volume),.fat_lba(scan_fat),
  .data_lba(scan_data),.root_lba(scan_root),.cluster_count(scan_clusters)
 );
 reg dir_start,dir_valid;
 reg [8:0] dir_index;
 reg [7:0] dir_byte;
 wire dir_entry_valid,dir_sector_done;
 wire [3:0] dir_kind;
 wire [7:0] dir_entry_index,dir_attr;
 wire [87:0] dir_name;
 wire [31:0] dir_cluster,dir_size;
 sd04_directory_parser u_dir(
  .clk(clk),.reset_n(reset_n),.start(dir_start),
  .byte_valid(dir_valid),.byte_index(dir_index),.byte_data(dir_byte),
  .entry_valid(dir_entry_valid),.kind(dir_kind),.entry_index(dir_entry_index),
  .short_name(dir_name),.attributes(dir_attr),
  .first_cluster(dir_cluster),.file_size(dir_size),.sector_done(dir_sector_done)
 );
 reg report_send;
 reg [2:0] report_type;
 wire report_busy,report_done;
 reg [3:0] latched_kind;
 reg [7:0] latched_index,latched_attr,latched_err,latched_code;
 reg [87:0] latched_name;
 reg [31:0] latched_cluster,latched_size;
 reg [7:0] nfiles,ndirs,nlfn,nskip,stop_reason;
 sd04_uart_report #(.CLOCK_HZ(27000000),.BAUD(UART_BAUD)) u_report(
  .clk(clk),.reset_n(reset_n),.send(report_send),.msg_type(report_type),
  .root_lba(scan_root),.vol_lba(scan_volume),.fat_lba(scan_fat),
  .err(latched_err),.code(latched_code),.idx(latched_index),
  .attr(latched_attr),.nfiles(nfiles),.ndirs(ndirs),
  .nlfn(nlfn),.nskip(nskip),.stop(stop_reason),
  .kind(latched_kind),.name_raw(latched_name),
  .cluster(latched_cluster),.size(latched_size),
  .uart_tx(uart_tx),.busy(report_busy),.done(report_done)
 );
 localparam [4:0] BOOT=0,SCANNING=1,GEOM_SEND=2,GEOM_WAIT=3,
  READ_START=4,READ_WAIT=5,DIR_BEGIN=6,DIR_RAM_WAIT=7,
  DIR_RAM_SAMPLE=8,DIR_DRAIN=9,ENTRY_DECIDE=10,
  ENTRY_SEND=11,ENTRY_WAIT=12,DIR_NEXT=13,
  SUMMARY_SEND=14,SUMMARY_WAIT=15,ERROR_SEND=16,ERROR_WAIT=17,HALT=18;
 reg [4:0] state;
 reg [8:0] ix;
 reg [5:0] leds;
 assign led_n=leds;
 always @(posedge clk or negedge reset_n) begin
 if(!reset_n)begin
  scanner_start<=0;root_read_start<=0;root_read_lba<=0;
  dir_start<=0;dir_valid<=0;dir_index<=0;dir_byte<=0;
  scan_mode<=1;dir_peek_addr<=0;report_send<=0;report_type<=0;
  latched_kind<=0;latched_index<=0;latched_attr<=0;latched_err<=0;
  latched_code<=0;latched_name<=0;latched_cluster<=0;latched_size<=0;
  nfiles<=0;ndirs<=0;nlfn<=0;nskip<=0;stop_reason<=0;
  state<=BOOT;ix<=0;leds<=6'b111111;
 end else begin
  scanner_start<=0;root_read_start<=0;dir_start<=0;dir_valid<=0;report_send<=0;
  case(state)
   BOOT:begin scanner_start<=1;scan_mode<=1;state<=SCANNING;end
   SCANNING:if(scan_done)begin
    latched_err<=sd_error;latched_code<={4'd0,scan_result};
    if(scan_result==1 || scan_result==2)begin
     scan_mode<=0;state<=GEOM_SEND;
    end else begin
     report_type<=3;state<=ERROR_SEND;
    end
   end
   GEOM_SEND:if(!report_busy)begin report_type<=0;report_send<=1;state<=GEOM_WAIT;end
   GEOM_WAIT:if(report_done)state<=READ_START;
   READ_START:begin
     root_read_lba<=scan_root;
     root_read_start<=1;
     state<=READ_WAIT;
   end
   READ_WAIT:if(sd_done)begin
    if(sd_error!=0)begin latched_err<=sd_error;report_type<=4;state<=ERROR_SEND;end
    else begin ix<=0;dir_peek_addr<=0;state<=DIR_BEGIN;end
   end
   DIR_BEGIN:begin dir_start<=1;state<=DIR_RAM_WAIT;end
   DIR_RAM_WAIT:state<=DIR_RAM_SAMPLE;
   DIR_RAM_SAMPLE:begin
    dir_index<=ix;dir_byte<=peek_data;dir_valid<=1;
    state<=DIR_DRAIN;
   end
   DIR_DRAIN:begin dir_valid<=0;state<=ENTRY_DECIDE;end
   ENTRY_DECIDE:begin
    // Parser entry_valid is registered after the last byte of each 32-byte entry.
    if(dir_entry_valid)begin
     latched_kind<=dir_kind;latched_index<=dir_entry_index;
     latched_attr<=dir_attr;latched_name<=dir_name;
     latched_cluster<=dir_cluster;latched_size<=dir_size;
     case(dir_kind)
      1:nfiles<=nfiles+1'b1;
      2:ndirs<=ndirs+1'b1;
      3:nlfn<=nlfn+1'b1;
      4,6:nskip<=nskip+1'b1;
      default:begin end
     endcase
     if(dir_kind==5)stop_reason<=1; // first unused entry terminates
     if(dir_kind==1 || dir_kind==2)state<=ENTRY_SEND;
     else if(dir_kind==5)state<=SUMMARY_SEND;
     else state<=DIR_NEXT;
    end else state<=DIR_NEXT;
   end
   ENTRY_SEND:if(!report_busy)begin report_type<=1;report_send<=1;state<=ENTRY_WAIT;end
   ENTRY_WAIT:if(report_done)state<=DIR_NEXT;
   DIR_NEXT:begin
    if(ix==9'd511)begin stop_reason<=2;state<=SUMMARY_SEND;end
    else begin ix<=ix+1'b1;dir_peek_addr<=ix+1'b1;state<=DIR_RAM_WAIT;end
   end
   SUMMARY_SEND:if(!report_busy)begin report_type<=2;report_send<=1;state<=SUMMARY_WAIT;end
   SUMMARY_WAIT:if(report_done)begin leds<=6'b111110;state<=HALT;end
   ERROR_SEND:if(!report_busy)begin report_send<=1;state<=ERROR_WAIT;end
   ERROR_WAIT:if(report_done)begin leds<=6'b111101;state<=HALT;end
   HALT:state<=HALT;
   default:state<=HALT;
  endcase
 end
 end
 wire unused_sd_initialized=sd_initialized;
 wire unused_sd_busy=sd_busy;
 wire unused_dir_sector_done=dir_sector_done;
endmodule
