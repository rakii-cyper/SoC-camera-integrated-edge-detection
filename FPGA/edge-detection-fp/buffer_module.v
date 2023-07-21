module buffer_module #(parameter width = 640) (
input           clk,
input           rst,
input           [3:0]  rst_line,
input           [31:0] in_data,
input           in_data_valid,
input           in_rden,
input           [3:0] in_re_read,
input           [1:0] in_load_new_frame,
input           [1:0] line_en_selection,
input           [1:0] in_buffer_select,
output  wire    [31:0] ou_row00, ou_row01, ou_row02,
output  wire    [31:0] ou_row10, ou_row11, ou_row12,
output  wire    [31:0] ou_row20, ou_row21, ou_row22,
output  wire    [3:0]  ou_full,
output  wire    [3:0]  ou_empty
);

wire data_valid_0, data_valid_1, data_valid_2, data_valid_3;
wire in_rd_data_0, in_rd_data_1, in_rd_data_2, in_rd_data_3;
wire line0_ou_full, line1_ou_full, line2_ou_full, line3_ou_full;
wire line0_ou_empty, line1_ou_empty, line2_ou_empty, line3_ou_empty;
wire [31:0] line0_ou_data_0, line0_ou_data_1, line0_ou_data_2;
wire [31:0] line1_ou_data_0, line1_ou_data_1, line1_ou_data_2;
wire [31:0] line2_ou_data_0, line2_ou_data_1, line2_ou_data_2;
wire [31:0] line3_ou_data_0, line3_ou_data_1, line3_ou_data_2;

assign ou_full = {line3_ou_full, line2_ou_full, line1_ou_full, line0_ou_full};
assign ou_empty = {line3_ou_empty, line2_ou_empty, line1_ou_empty, line0_ou_empty};

assign data_valid_0 = (in_data_valid == 1'b1 && line_en_selection == 2'd0) ? 1'b1 : 1'b0;
assign data_valid_1 = (in_data_valid == 1'b1 && line_en_selection == 2'd1) ? 1'b1 : 1'b0;
assign data_valid_2 = (in_data_valid == 1'b1 && line_en_selection == 2'd2) ? 1'b1 : 1'b0;
assign data_valid_3 = (in_data_valid == 1'b1 && line_en_selection == 2'd3) ? 1'b1 : 1'b0;

/*
    localparam  BUFF_012    = 2'd0;
    localparam  BUFF_123    = 2'd1;
    localparam  BUFF_230    = 2'd2;
    localparam  BUFF_301    = 2'd3;
*/
assign in_rd_data_0 = (in_rden && ( in_buffer_select == 2'd0 || 
                                    in_buffer_select == 2'd2 ||
                                    in_buffer_select == 2'd3))  ? 1'b1 : 1'b0;
assign in_rd_data_1 = (in_rden && ( in_buffer_select == 2'd0 || 
                                    in_buffer_select == 2'd1 ||
                                    in_buffer_select == 2'd3))  ? 1'b1 : 1'b0;
assign in_rd_data_2 = (in_rden && ( in_buffer_select == 2'd0 || 
                                    in_buffer_select == 2'd1 ||
                                    in_buffer_select == 2'd2))  ? 1'b1 : 1'b0;
assign in_rd_data_3 = (in_rden && ( in_buffer_select == 2'd1 || 
                                    in_buffer_select == 2'd2 ||
                                    in_buffer_select == 2'd3))  ? 1'b1 : 1'b0;                                    

lineBuffer #(.width(width)) line0(
    clk, 
    rst | rst_line[0], 
    in_data, 
    in_re_read[0],
    data_valid_0, 
    line0_ou_data_0, 
    line0_ou_data_1,
    line0_ou_data_2, 
    in_rd_data_0, 
    line0_ou_full,
    line0_ou_empty);

lineBuffer #(.width(width)) line1(
    clk, 
    rst | rst_line[1], 
    in_data, 
    in_re_read[1],
    data_valid_1, 
    line1_ou_data_0, 
    line1_ou_data_1,
    line1_ou_data_2, 
    in_rd_data_1, 
    line1_ou_full,
    line1_ou_empty);

lineBuffer #(.width(width)) line2(
    clk, 
    rst | rst_line[2], 
    in_data, 
    in_re_read[2],
    data_valid_2, 
    line2_ou_data_0, 
    line2_ou_data_1,
    line2_ou_data_2, 
    in_rd_data_2, 
    line2_ou_full,
    line2_ou_empty);

lineBuffer #(.width(width)) line3(
    clk, 
    rst | rst_line[3], 
    in_data, 
    in_re_read[3],
    data_valid_3, 
    line3_ou_data_0, 
    line3_ou_data_1,
    line3_ou_data_2, 
    in_rd_data_3, 
    line3_ou_full,
    line3_ou_empty);

// line 0
assign ou_row00 =   (in_buffer_select == 2'd0) ? line0_ou_data_0 : 
                    (in_buffer_select == 2'd1) ? line1_ou_data_0 : 
                    (in_buffer_select == 2'd2) ? line2_ou_data_0 : 
                    line3_ou_data_0;
assign ou_row01 =   (in_buffer_select == 2'd0) ? line0_ou_data_1 : 
                    (in_buffer_select == 2'd1) ? line1_ou_data_1 : 
                    (in_buffer_select == 2'd2) ? line2_ou_data_1 : 
                    line3_ou_data_1;
assign ou_row02 =   (in_buffer_select == 2'd0) ? line0_ou_data_2 : 
                    (in_buffer_select == 2'd1) ? line1_ou_data_2 : 
                    (in_buffer_select == 2'd2) ? line2_ou_data_2 : 
                    line3_ou_data_2;

// line 1
assign ou_row10 =   (in_load_new_frame == 2'd1)? 32'd0           :
                    (in_buffer_select == 2'd0) ? line1_ou_data_0 : 
                    (in_buffer_select == 2'd1) ? line2_ou_data_0 : 
                    (in_buffer_select == 2'd2) ? line3_ou_data_0 : 
                    line0_ou_data_0;

assign ou_row11 =   (in_load_new_frame == 2'd1)? 32'd0           :
                    (in_buffer_select == 2'd0) ? line1_ou_data_1 : 
                    (in_buffer_select == 2'd1) ? line2_ou_data_1 : 
                    (in_buffer_select == 2'd2) ? line3_ou_data_1 : 
                    line0_ou_data_1;

assign ou_row12 =   (in_load_new_frame == 2'd1)? 32'd0           :
                    (in_buffer_select == 2'd0) ? line1_ou_data_2 : 
                    (in_buffer_select == 2'd1) ? line2_ou_data_2 : 
                    (in_buffer_select == 2'd2) ? line3_ou_data_2 : 
                    line0_ou_data_2;

// line 2
assign ou_row20 =   (in_load_new_frame == 2'd1)? 32'd0           :
                    (in_load_new_frame == 2'd2)? 32'd0           :
                    (in_buffer_select == 2'd0) ? line2_ou_data_0 : 
                    (in_buffer_select == 2'd1) ? line3_ou_data_0 : 
                    (in_buffer_select == 2'd2) ? line0_ou_data_0 : 
                    line1_ou_data_0;

assign ou_row21 =   (in_load_new_frame == 2'd1)? 32'd0           :
                    (in_load_new_frame == 2'd2)? 32'd0           :
                    (in_buffer_select == 2'd0) ? line2_ou_data_1 : 
                    (in_buffer_select == 2'd1) ? line3_ou_data_1 : 
                    (in_buffer_select == 2'd2) ? line0_ou_data_1 : 
                    line1_ou_data_1;

assign ou_row22 =   (in_load_new_frame == 2'd1)? 32'd0           :
                    (in_load_new_frame == 2'd2)? 32'd0           :
                    (in_buffer_select == 2'd0) ? line2_ou_data_2 : 
                    (in_buffer_select == 2'd1) ? line3_ou_data_2 : 
                    (in_buffer_select == 2'd2) ? line0_ou_data_2 : 
                    line1_ou_data_2;
endmodule
