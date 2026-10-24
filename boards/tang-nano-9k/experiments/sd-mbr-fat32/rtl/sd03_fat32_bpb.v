// SD-03.2: conservative read-only FAT32 BPB validator; 512-byte sector stream.
// All offsets are VBR-relative. No CPU, filesystem writes, or FAT traversal.
// Validates cluster-count derived FAT type (>= 65525) rather than text labels.
// Verilog-2005. SPDX-License-Identifier: MIT
module sd03_fat32_bpb (
    input wire clk, input wire reset_n, input wire start,
    input wire [31:0] volume_lba,
    input wire [31:0] partition_sectors, // 0 = unknown (superfloppy)
    input wire byte_valid, input wire [8:0] byte_index,
    input wire [7:0] byte_data,
    output reg done, output reg [2:0] status,
    output reg [31:0] fat_lba, data_lba, root_lba,
    output reg [31:0] cluster_count, total_sectors, fat_sectors,
    output reg [31:0] root_cluster,
    output reg [7:0] sectors_per_cluster
);
    // status: 0 pending, 1 FAT32 accepted, 2 invalid 55AA,
    // 3 inconsistent FAT32 BPB, 4 address/layout/partition overflow,
    // 5 cluster count/FAT size invalid, 6 exFAT identified (unsupported).
    reg active, sig55;
    reg [63:0] oem;
    reg [7:0] jump, spc, fat_count;
    reg [15:0] bps, reserved, root_entries, tot16, fatsz16;
    reg [31:0] tot32, fatsz32, rootclus;
    reg [15:0] fsver, fsinfo, backup;
    reg [31:0] base_lba, bound;
    reg [2:0] spc_shift;
    reg spc_valid;

    always @* begin
        spc_valid=1'b1;
        case(spc)
            8'd1: spc_shift=0;
            8'd2: spc_shift=1;
            8'd4: spc_shift=2;
            8'd8: spc_shift=3;
            8'd16: spc_shift=4;
            8'd32: spc_shift=5;
            8'd64: spc_shift=6;
            8'd128: spc_shift=7;
            default: begin spc_shift=0;spc_valid=0;end
        endcase
    end
    // Restrict NumFATs to 1 or 2; avoid a generic variable multiplier.
    wire [63:0] fat_region_sectors =
        fat_count==8'd1 ? {32'd0,fatsz32} : {31'd0,fatsz32,1'b0};
    wire [63:0] relative_fat = {48'd0,reserved};
    wire [63:0] relative_data = relative_fat + fat_region_sectors;
    wire [63:0] volume_sectors = {32'd0,tot32};
    wire [63:0] data_sectors = volume_sectors > relative_data ?
                                volume_sectors-relative_data : 64'd0;
    wire [63:0] clusters = data_sectors >> spc_shift;
    wire [63:0] fat_capacity = {25'd0,fatsz32,7'd0}; // bytes/4 per FAT
    wire [63:0] root_relative = relative_data +
                     (({32'd0,rootclus}-64'd2) << spc_shift);
    wire [63:0] abs_fat = {32'd0,base_lba}+relative_fat;
    wire [63:0] abs_data = {32'd0,base_lba}+relative_data;
    wire [63:0] abs_root = {32'd0,base_lba}+root_relative;
    wire [63:0] abs_end = {32'd0,base_lba}+volume_sectors;
    wire exfat = oem==64'h4558464154202020; // "EXFAT   "

    wire bpb_shape =
        (jump==8'heb || jump==8'he9) &&
        bps==16'd512 && spc_valid && reserved!=0 &&
        (fat_count==8'd1 || fat_count==8'd2) &&
        root_entries==0 && tot16==0 && fatsz16==0 &&
        tot32!=0 && fatsz32!=0 && fsver==0 &&
        rootclus>=2 &&
        (fsinfo==16'hffff || fsinfo<reserved) &&
        (backup==16'hffff || backup<reserved);
    wire layout_ok =
        volume_sectors>relative_data &&
        (bound==0 || tot32<=bound) &&
        abs_end<=64'h0000000100000000 &&
        abs_fat<=64'h00000000ffffffff &&
        abs_data<=64'h00000000ffffffff &&
        abs_root<=64'h00000000ffffffff &&
        root_relative<volume_sectors;
    wire cluster_ok =
        clusters>=64'd65525 && clusters<=64'h0fffffef &&
        fat_capacity>=clusters+64'd2 &&
        {32'd0,rootclus}<clusters+64'd2;

    always @(posedge clk or negedge reset_n) begin
        if(!reset_n) begin
            active<=0;done<=0;status<=0;sig55<=0;
            oem<=0;jump<=0;spc<=0;fat_count<=0;bps<=0;reserved<=0;
            root_entries<=0;tot16<=0;fatsz16<=0;tot32<=0;
            fatsz32<=0;rootclus<=0;fsver<=0;fsinfo<=0;backup<=0;
            base_lba<=0;bound<=0;
            fat_lba<=0;data_lba<=0;root_lba<=0;cluster_count<=0;
            total_sectors<=0;fat_sectors<=0;root_cluster<=0;
            sectors_per_cluster<=0;
        end else begin
            done<=0;
            if(start) begin
                active<=1;status<=0;sig55<=0;
                oem<=0;jump<=0;spc<=0;fat_count<=0;bps<=0;reserved<=0;
                root_entries<=0;tot16<=0;fatsz16<=0;tot32<=0;
                fatsz32<=0;rootclus<=0;fsver<=0;fsinfo<=16'hffff;
                backup<=16'hffff;
                base_lba<=volume_lba;bound<=partition_sectors;
                fat_lba<=0;data_lba<=0;root_lba<=0;cluster_count<=0;
                total_sectors<=0;fat_sectors<=0;root_cluster<=0;
                sectors_per_cluster<=0;
            end else if(active && byte_valid) begin
                case(byte_index)
                    9'd0:jump<=byte_data;
                    9'd3,9'd4,9'd5,9'd6,9'd7,9'd8,9'd9,9'd10:
                        oem<={oem[55:0],byte_data};
                    9'd11:bps[7:0]<=byte_data;
                    9'd12:bps[15:8]<=byte_data;
                    9'd13:spc<=byte_data;
                    9'd14:reserved[7:0]<=byte_data;
                    9'd15:reserved[15:8]<=byte_data;
                    9'd16:fat_count<=byte_data;
                    9'd17:root_entries[7:0]<=byte_data;
                    9'd18:root_entries[15:8]<=byte_data;
                    9'd19:tot16[7:0]<=byte_data;
                    9'd20:tot16[15:8]<=byte_data;
                    9'd22:fatsz16[7:0]<=byte_data;
                    9'd23:fatsz16[15:8]<=byte_data;
                    9'd32:tot32[7:0]<=byte_data;
                    9'd33:tot32[15:8]<=byte_data;
                    9'd34:tot32[23:16]<=byte_data;
                    9'd35:tot32[31:24]<=byte_data;
                    9'd36:fatsz32[7:0]<=byte_data;
                    9'd37:fatsz32[15:8]<=byte_data;
                    9'd38:fatsz32[23:16]<=byte_data;
                    9'd39:fatsz32[31:24]<=byte_data;
                    9'd42:fsver[7:0]<=byte_data;
                    9'd43:fsver[15:8]<=byte_data;
                    9'd44:rootclus[7:0]<=byte_data;
                    9'd45:rootclus[15:8]<=byte_data;
                    9'd46:rootclus[23:16]<=byte_data;
                    9'd47:rootclus[31:24]<=byte_data;
                    9'd48:fsinfo[7:0]<=byte_data;
                    9'd49:fsinfo[15:8]<=byte_data;
                    9'd50:backup[7:0]<=byte_data;
                    9'd51:backup[15:8]<=byte_data;
                    9'd510:sig55<=byte_data==8'h55;
                    default:begin end
                endcase
                if(byte_index==9'd511) begin
                    active<=0;done<=1;
                    if(!sig55 || byte_data!=8'haa)status<=2;
                    else if(exfat)status<=6;
                    else if(!bpb_shape)status<=3;
                    else if(!layout_ok)status<=4;
                    else if(!cluster_ok)status<=5;
                    else begin
                        status<=1;
                        fat_lba<=abs_fat[31:0];
                        data_lba<=abs_data[31:0];
                        root_lba<=abs_root[31:0];
                        cluster_count<=clusters[31:0];
                        total_sectors<=tot32;
                        fat_sectors<=fatsz32;
                        root_cluster<=rootclus;
                        sectors_per_cluster<=spc;
                    end
                end
            end
        end
    end
endmodule
