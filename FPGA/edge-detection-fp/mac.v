module mac(
    input   wire        clk,
    input   wire        rst,
    input   wire        in_last_pixel,
    input   wire [31:0] in_grayscale_fp,
    input   wire [31:0] in_kernel_coeff,
    input   wire        in_data_last,
    input   wire        in_data_valid,
    input   wire        in_result_ready,
    output  wire        ou_result_valid,
    output  wire        ou_data_ready,
    output  wire        ou_result_last,
    output  wire        ou_last_pixel,
    output  wire [31:0] ou_feature_extraction
);
    wire            tready_a, tready_b, fp_mul_valid, accumulator_ready, fp_mul_last, fp_mul_last_pixel;
    wire    [31:0]  fp_mul_result;
    reg     [31:0]  acc_din;
    
    assign ou_data_ready = tready_a & tready_b;

    // MAC module
    // fp_mac fp_mac_inst (
    //     .aclk(clk),
    //     .s_axis_a_tvalid(in_data_valid),
    //     .s_axis_a_tready(tready_a),
    //     .s_axis_a_tdata(in_grayscale_fp),
    //     .s_axis_a_tlast(in_data_last),
    //     .s_axis_b_tvalid(in_data_valid),
    //     .s_axis_b_tready(tready_b),
    //     .s_axis_b_tdata(in_kernel_coeff),
    //     .s_axis_c_tvalid(in_data_valid),
    //     .s_axis_c_tready(tready_c),
    //     .s_axis_c_tdata(buffer),
    //     .m_axis_result_tvalid(ou_result_valid),
    //     .m_axis_result_tready(in_result_ready),
    //     .m_axis_result_tdata(fp_mac_result),
    //     .m_axis_result_tlast(ou_result_last)
    // );

    fp_mul fp_mul_block(
        .aclk(clk),
        .s_axis_a_tvalid(in_data_valid),
        .s_axis_a_tready(tready_a),
        .s_axis_a_tdata(in_grayscale_fp),
        .s_axis_a_tuser(in_last_pixel),
        .s_axis_a_tlast(in_data_last),
        .s_axis_b_tvalid(in_data_valid),
        .s_axis_b_tready(tready_b),
        .s_axis_b_tdata(in_kernel_coeff),
        .m_axis_result_tvalid(fp_mul_valid),
        .m_axis_result_tready(accumulator_ready),
        .m_axis_result_tdata(fp_mul_result),
        .m_axis_result_tuser(fp_mul_last_pixel),
        .m_axis_result_tlast(fp_mul_last)
    );

    floating_point_0 accumulator(
        .aclk(clk),
        .s_axis_a_tvalid(fp_mul_valid),
        .s_axis_a_tready(accumulator_ready),
        .s_axis_a_tdata(fp_mul_result),
        .s_axis_a_tuser(fp_mul_last_pixel),
        .s_axis_a_tlast(fp_mul_last),
        .m_axis_result_tvalid(ou_result_valid),
        .m_axis_result_tready(in_result_ready),
        .m_axis_result_tdata(ou_feature_extraction),
        .m_axis_result_tuser(ou_last_pixel),
        .m_axis_result_tlast(ou_result_last)
    );
endmodule