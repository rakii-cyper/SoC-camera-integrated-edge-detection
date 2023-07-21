module grayscale_converter(
    input   wire        clk,
    input   wire        rst,
    input   wire        in_data_valid,
    input   wire        in_result_ready,
    input   wire [31:0] in_rgb_pixel,
    output  wire        ou_data_ready,
    output  wire        ou_result_valid,
    output  wire [31:0] ou_grayscale_pixel,
    output  wire        ou_first_frame,
    output  wire        ou_pre_last,
    output  wire        ou_last_frame
    );  

    wire    [7:0]   red_channel, green_channel, blue_channel, footer, grayscale_int;
    wire            first_frame, last_frame, pre_last;

    localparam START_FRAME      = 8'd1;
    localparam PRE_END_FRAME    = 8'd2;
    localparam END_FRAME        = 8'd3;   

    assign blue_channel     = in_rgb_pixel[7:0];
    assign green_channel    = in_rgb_pixel[15:8];
    assign red_channel      = in_rgb_pixel[23:16];
    assign footer           = in_rgb_pixel[31:24];

    assign first_frame   = (footer == START_FRAME)      ? 1'b1 : 1'b0;
    assign last_frame       = (footer == END_FRAME)     ? 1'b1 : 1'b0;
    assign pre_last         = (footer == PRE_END_FRAME) ? 1'b1 : 1'b0; 

    assign grayscale_int = (blue_channel   >> 5) + (blue_channel   >> 4) + 
                           (green_channel  >> 4) + (green_channel  >> 1) + 
                           (red_channel    >> 5) + (red_channel    >> 2);

    int_to_float itof_block(
        .aclk(clk),
        .s_axis_a_tvalid(in_data_valid),
        .s_axis_a_tready(ou_data_ready),
        .s_axis_a_tdata(grayscale_int),
        .s_axis_a_tuser({first_frame, pre_last, last_frame}),
        .m_axis_result_tvalid(ou_result_valid),
        .m_axis_result_tready(in_result_ready),
        .m_axis_result_tdata(ou_grayscale_pixel),
        .m_axis_result_tuser({ou_first_frame, ou_pre_last, ou_last_frame})
    );
endmodule