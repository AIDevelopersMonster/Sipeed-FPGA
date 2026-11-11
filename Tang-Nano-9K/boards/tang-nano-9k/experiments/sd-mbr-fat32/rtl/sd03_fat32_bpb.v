// SD-03.4 v0.2: sequential FAT32 BPB validator with bounded arithmetic.
// Input: a 512-byte VBR stream. Output: validated FAT/data/root LBAs.
// No CPU, SD writes, directory access, or combinational 64-bit datapath.
// Replaces one-cycle 64-bit add/shift/compare chains with serialized steps.
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
    // 0 waiting, 1 FAT32 accepted, 2 missing 55AA,
    // 3 inconsistent FAT32 BPB, 4 layout/partition/32-bit LBA overflow,
    // 5 cluster count/FAT capacity invalid, 6 exFAT unsupported.
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

    wire bpb_shape =
        (jump==8'heb || jump==8'he9) &&
        bps==16'd512 && spc_valid && reserved!=0 &&
        (fat_count==8'd1 || fat_count==8'd2) &&
        root_entries==0 && tot16==0 && fatsz16==0 &&
        tot32!=0 && fatsz32!=0 && fsver==0 &&
        rootclus>=2 &&
        (fsinfo==16'hffff || fsinfo<reserved) &&
        (backup==16'hffff || backup<reserved);
    wire exfat = oem==64'h4558464154202020; // "EXFAT   "

    // All arithmetic registered across multiple cycles:
    // fat_region: 34 bits for 2*FATSz32; rel_data includes ReservedSectors.
    // root_delta/root_relative allow up to 7 repeated one-bit left shifts.
    reg [33:0] fat_region,rel_data;
    reg [31:0] data_sectors,working_clusters,calculated_clusters;
    reg [32:0] entries_needed,absolute_end;
    reg [25:0] fat_sectors_needed;
    reg [35:0] root_delta;
    reg [36:0] root_relative;
    reg [2:0] shifts_left;
    reg [3:0] calc_state;
    localparam [3:0] C_IDLE=0,
        C_FAT_REGION=1, C_REL_DATA=2, C_LAYOUT=3,
        C_SHIFT_SETUP=4, C_SHIFT=5, C_CLUSTER_CHECK=6,
        C_REQ_ENTRIES=7, C_REQ_SECTORS=8, C_FAT_CHECK=9,
        C_ROOT_SHIFT=10, C_ROOT_REL=11, C_ROOT_CHECK=12,
        C_END_ADDR=13, C_END_CHECK=14, C_OUT=15;

    always @(posedge clk or negedge reset_n) begin
        if(!reset_n) begin
            active<=0;done<=0;status<=0;sig55<=0;calc_state<=C_IDLE;
            oem<=0;jump<=0;spc<=0;fat_count<=0;
            bps<=0;reserved<=0;root_entries<=0;tot16<=0;fatsz16<=0;
            tot32<=0;fatsz32<=0;rootclus<=0;fsver<=0;fsinfo<=0;backup<=0;
            base_lba<=0;bound<=0;fat_region<=0;rel_data<=0;
            data_sectors<=0;working_clusters<=0;calculated_clusters<=0;
            entries_needed<=0;absolute_end<=0;fat_sectors_needed<=0;
            root_delta<=0;root_relative<=0;shifts_left<=0;
            fat_lba<=0;data_lba<=0;root_lba<=0;cluster_count<=0;
            total_sectors<=0;fat_sectors<=0;root_cluster<=0;
            sectors_per_cluster<=0;
        end else begin
            done<=0;
            if(start) begin
                active<=1;status<=0;sig55<=0;calc_state<=C_IDLE;
                oem<=0;jump<=0;spc<=0;fat_count<=0;
                bps<=0;reserved<=0;root_entries<=0;tot16<=0;fatsz16<=0;
                tot32<=0;fatsz32<=0;rootclus<=0;fsver<=0;
                fsinfo<=16'hffff;backup<=16'hffff;
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
                    active<=0;
                    if(!sig55 || byte_data!=8'haa)begin
                        status<=2;done<=1;calc_state<=C_IDLE;
                    end else if(exfat)begin
                        status<=6;done<=1;calc_state<=C_IDLE;
                    end else if(!bpb_shape)begin
                        status<=3;done<=1;calc_state<=C_IDLE;
                    end else calc_state<=C_FAT_REGION;
                end
            end else begin
                case(calc_state)
                    C_FAT_REGION:begin
                        fat_region <= fat_count==8'd1
                            ? {2'd0,fatsz32} : {1'd0,fatsz32,1'd0};
                        calc_state<=C_REL_DATA;
                    end
                    C_REL_DATA:begin
                        rel_data<=fat_region+{18'd0,reserved};
                        calc_state<=C_LAYOUT;
                    end
                    C_LAYOUT:begin
                        if(rel_data[33:32]!=0 || rel_data[31:0]>=tot32 ||
                           (bound!=0 && tot32>bound))begin
                            status<=4;done<=1;calc_state<=C_IDLE;
                        end else begin
                            data_sectors<=tot32-rel_data[31:0];
                            calc_state<=C_SHIFT_SETUP;
                        end
                    end
                    C_SHIFT_SETUP:begin
                        working_clusters<=data_sectors;
                        shifts_left<=spc_shift;
                        calc_state<=C_SHIFT;
                    end
                    C_SHIFT:begin
                        if(shifts_left!=0)begin
                            working_clusters<=working_clusters>>1;
                            shifts_left<=shifts_left-1'b1;
                        end else begin
                            calculated_clusters<=working_clusters;
                            calc_state<=C_CLUSTER_CHECK;
                        end
                    end
                    C_CLUSTER_CHECK:begin
                        if(calculated_clusters<32'd65525 ||
                           calculated_clusters>32'h0fffffef ||
                           (rootclus-32'd2)>=calculated_clusters)begin
                            status<=5;done<=1;calc_state<=C_IDLE;
                        end else calc_state<=C_REQ_ENTRIES;
                    end
                    C_REQ_ENTRIES:begin
                        entries_needed<={1'b0,calculated_clusters}+33'd2;
                        calc_state<=C_REQ_SECTORS;
                    end
                    C_REQ_SECTORS:begin
                        // ceil((ClusterCount+2)/128) sectors per FAT.
                        fat_sectors_needed<=entries_needed[32:7] +
                            {25'd0,(|entries_needed[6:0])};
                        calc_state<=C_FAT_CHECK;
                    end
                    C_FAT_CHECK:begin
                        if({6'd0,fat_sectors_needed}>fatsz32)begin
                            status<=5;done<=1;calc_state<=C_IDLE;
                        end else begin
                            root_delta<={4'd0,rootclus}-36'd2;
                            shifts_left<=spc_shift;
                            calc_state<=C_ROOT_SHIFT;
                        end
                    end
                    C_ROOT_SHIFT:begin
                        if(shifts_left!=0)begin
                            root_delta<=root_delta<<1;
                            shifts_left<=shifts_left-1'b1;
                        end else calc_state<=C_ROOT_REL;
                    end
                    C_ROOT_REL:begin
                        root_relative<={5'd0,rel_data[31:0]}+{1'd0,root_delta};
                        calc_state<=C_ROOT_CHECK;
                    end
                    C_ROOT_CHECK:begin
                        if(root_relative[36:32]!=0 ||
                           root_relative[31:0]>=tot32)begin
                            status<=4;done<=1;calc_state<=C_IDLE;
                        end else calc_state<=C_END_ADDR;
                    end
                    C_END_ADDR:begin
                        absolute_end<={1'd0,base_lba}+{1'd0,tot32};
                        calc_state<=C_END_CHECK;
                    end
                    C_END_CHECK:begin
                        // Exclusive end may be exactly 2^32, but not beyond it.
                        if(absolute_end[32] && absolute_end[31:0]!=0)begin
                            status<=4;done<=1;calc_state<=C_IDLE;
                        end else calc_state<=C_OUT;
                    end
                    C_OUT:begin
                        fat_lba<=base_lba+{16'd0,reserved};
                        data_lba<=base_lba+rel_data[31:0];
                        root_lba<=base_lba+root_relative[31:0];
                        cluster_count<=calculated_clusters;
                        total_sectors<=tot32;
                        fat_sectors<=fatsz32;
                        root_cluster<=rootclus;
                        sectors_per_cluster<=spc;
                        status<=1;done<=1;calc_state<=C_IDLE;
                    end
                    default:calc_state<=C_IDLE;
                endcase
            end
        end
    end
endmodule
