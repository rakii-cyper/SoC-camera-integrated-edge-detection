module convol #(parameter width = 640) (
    input   wire        clk,
    input   wire        rst,
    input   wire        in_data_valid,
    input   wire        in_last_pixel,
    input   wire        in_result_ready,
    input   wire [31:0] in_slide_window_0,
    input   wire [31:0] in_slide_window_1,
    input   wire [31:0] in_slide_window_2,
    input   wire [31:0] in_slide_window_3,
    input   wire [31:0] in_slide_window_4,
    input   wire [31:0] in_slide_window_5,
    input   wire [31:0] in_slide_window_6,
    input   wire [31:0] in_slide_window_7,
    input   wire [31:0] in_slide_window_8,
    input   wire [31:0] in_kernel_coeff_x, 
    input   wire [31:0] in_kernel_coeff_y,
    output  wire        ou_last_pixel,
    output  wire        ou_data_ready,
    output  wire        ou_feature_extraction_valid,
    output  wire [7:0]  ou_feature_extraction,
    output  wire [3:0]  ou_kernel_address
);
    //////////////////////////////////////////
    //  controller of convolutional module  //
    //////////////////////////////////////////
      
    // localparam initial_state            = 2'd0;
    // localparam waiting_pipeline_state   = 2'd1;
    // localparam execute_state            = 2'd2;

    // reg     [1:0]   current_state;
    // wire    [1:0]   next_state;
    wire            result_ready, data_ready_x, data_ready_y, counter_en, data_last;
    reg     [3:0]   counter, feature_cnt;

    // // current state
    // always @(posedge clk) begin
    //     if (rst)
    //         current_state <= 2'd0;
    //     else
    //         current_state <= next_state;
    // end

    // // next state
    // assign next_state = (current_state == initial_state && in_data_valid == 1'b1)                           ? waiting_pipeline_state :
    //                     (current_state == initial_state && (in_data_valid == 1'b0 || data_ready == 1'b0))   ? initial_state :
    //                     (current_state == waiting_pipeline_state && result_valid == 1'b0)                   ? waiting_pipeline_state :
    //                     (current_state == waiting_pipeline_state && result_valid == 1'b1)                   ? execute_state :
    //                     (current_state == execute_state &&  (in_data_valid == 1'b0 || data_ready == 1'b0))  ? initial_state :
    //                     execute_state;

    // // output
    assign result_ready = 1'b1;
    assign counter_en   = in_data_valid & data_ready_x & data_ready_y;
    assign data_last    = (counter == 4'd8) ? 1'b1 : 1'b0;

                                     
    //////////////////////////////////////    
    // datapth of convolutional module  //
    //////////////////////////////////////   
    wire    [31:0]  grayscale_fp;

    assign  grayscale_fp =  (counter == 4'd0) ? in_slide_window_0 : 
                            (counter == 4'd1) ? in_slide_window_1 : 
                            (counter == 4'd2) ? in_slide_window_2 : 
                            (counter == 4'd3) ? in_slide_window_3 : 
                            (counter == 4'd4) ? in_slide_window_4 : 
                            (counter == 4'd5) ? in_slide_window_5 : 
                            (counter == 4'd6) ? in_slide_window_6 : 
                            (counter == 4'd7) ? in_slide_window_7 :
                            in_slide_window_8;

    always @(posedge clk) begin
        if (rst)
            counter <= 4'd0;
        else if (counter_en) begin
            if (counter == 4'd8)
                counter <= 4'd0;
            else
                counter <= counter + 4'd1;
        end
    end

    assign ou_kernel_address    = counter;
    assign ou_data_ready        = (counter == 4'd8) & data_ready_x & data_ready_y;
    
    wire        abs_data_ready_x, abs_valid_x, ftoi_ready_x, abs_last_x, mac_result_last_x, result_valid_x, feature_valid_x, feature_last_x;
    wire        mac_last_pixel_x, abs_last_pixel_x, ftoi_last_pixel_x, ftoi_result_valid_x;
    wire [8:0]  feature_data_x;
    wire [31:0] mac_result_x, abs_data_x;
    wire        abs_data_ready_y, abs_valid_y, ftoi_ready_y, abs_last_y, mac_result_last_y, result_valid_y, feature_valid_y, feature_last_y;
    wire        mac_last_pixel_y, abs_last_pixel_y, ftoi_last_pixel_y, ftoi_result_valid_y;
    wire [8:0]  feature_data_y;
    wire [31:0] mac_result_y, abs_data_y;

    //////////////////////////////////////    
    //          GX CONVOLUTION          //
    //////////////////////////////////////   
    mac mac_block_x(
        .clk(clk),
        .rst(rst),
        .in_last_pixel(in_last_pixel),
        .in_grayscale_fp(grayscale_fp),
        .in_kernel_coeff(in_kernel_coeff_x),
        .in_data_last(data_last),
        .in_data_valid(in_data_valid),
        .in_result_ready((result_ready | abs_data_ready_x) & ftoi_ready_x),
        .ou_result_valid(result_valid_x),
        .ou_data_ready(data_ready_x),
        .ou_result_last(mac_result_last_x),
        .ou_last_pixel(mac_last_pixel_x),
        .ou_feature_extraction(mac_result_x)
    );

    fp_abs abs_block_x(
        .s_axis_a_tvalid(result_valid_x),
        .s_axis_a_tready(abs_data_ready_x),
        .s_axis_a_tdata(mac_result_x),
        .s_axis_a_tuser(mac_last_pixel_x),
        .s_axis_a_tlast(mac_result_last_x),
        .m_axis_result_tvalid(abs_valid_x),
        .m_axis_result_tready(ftoi_ready_x),
        .m_axis_result_tdata(abs_data_x),
        .m_axis_result_tuser(abs_last_pixel_x),
        .m_axis_result_tlast(abs_last_x)
    );

    float_to_int ftoi_block_x(
        .aclk(clk),
        .s_axis_a_tvalid(abs_valid_x),
        .s_axis_a_tready(ftoi_ready_x),
        .s_axis_a_tdata(abs_data_x),
        .s_axis_a_tuser(abs_last_pixel_x),
        .s_axis_a_tlast(abs_last_x),
        .m_axis_result_tvalid(ftoi_result_valid_x),
        .m_axis_result_tready(in_result_ready),
        .m_axis_result_tdata(feature_data_x),
        .m_axis_result_tuser(ftoi_last_pixel_x),
        .m_axis_result_tlast(feature_valid_x)
    );

    //////////////////////////////////////    
    //          GY CONVOLUTION          //
    //////////////////////////////////////   
    mac mac_block_y(
        .clk(clk),
        .rst(rst),
        .in_last_pixel(in_last_pixel),
        .in_grayscale_fp(grayscale_fp),
        .in_kernel_coeff(in_kernel_coeff_y),
        .in_data_last(data_last),
        .in_data_valid(in_data_valid),
        .in_result_ready((result_ready | abs_data_ready_y) & ftoi_ready_x),
        .ou_result_valid(result_valid_y),
        .ou_data_ready(data_ready_y),
        .ou_result_last(mac_result_last_y),
        .ou_last_pixel(mac_last_pixel_y),
        .ou_feature_extraction(mac_result_y)
    );

    fp_abs abs_block_y(
        .s_axis_a_tvalid(result_valid_y),
        .s_axis_a_tready(abs_data_ready_y),
        .s_axis_a_tdata(mac_result_y),
        .s_axis_a_tuser(mac_last_pixel_y),
        .s_axis_a_tlast(mac_result_last_y),
        .m_axis_result_tvalid(abs_valid_y),
        .m_axis_result_tready(ftoi_ready_y),
        .m_axis_result_tdata(abs_data_y),
        .m_axis_result_tuser(abs_last_pixel_y),
        .m_axis_result_tlast(abs_last_y)
    );

    float_to_int ftoi_block_y(
        .aclk(clk),
        .s_axis_a_tvalid(abs_valid_y),
        .s_axis_a_tready(ftoi_ready_y),
        .s_axis_a_tdata(abs_data_y),
        .s_axis_a_tuser(abs_last_pixel_y),
        .s_axis_a_tlast(abs_last_y),
        .m_axis_result_tvalid(ftoi_result_valid_y),
        .m_axis_result_tready(in_result_ready),
        .m_axis_result_tdata(feature_data_y),
        .m_axis_result_tuser(ftoi_last_pixel_y),
        .m_axis_result_tlast(feature_valid_y)
    );

    assign ou_feature_extraction        = feature_data_x[7:0] + feature_data_y[7:0];
    assign ou_feature_extraction_valid  = feature_valid_x & ftoi_result_valid_x & feature_valid_y & ftoi_result_valid_y ;
    assign ou_last_pixel                = ftoi_last_pixel_x & ftoi_last_pixel_y;
endmodule