module edge_detector #(parameter FRAME_WIDTH = 640) (
    input   wire            bus_clk,
    input   wire            rst,
    input   wire            in_fifo_host_to_fpga_empty,
    input   wire            in_fifo_fpga_to_host_full,
    input   wire    [31:0]  in_fifo_host_to_fpga_dout,
    output  wire            ou_fifo_host_to_fpga_rden, 
    output  wire            ou_fifo_fpga_to_host_wren, 
    output  wire    [31:0]  ou_fifo_fpga_to_host_din
    );
    ////////////////////
    // SIGNAL INITIAL //
    ////////////////////
    // constant value
    localparam  LINE_0_EN   = 2'd0;
    localparam  LINE_1_EN   = 2'd1;
    localparam  LINE_2_EN   = 2'd2;
    localparam  LINE_3_EN   = 2'd3;

    localparam  NO_LINE_RST = 4'd0;
    localparam  LINE_0_RST  = 4'b0001;
    localparam  LINE_1_RST  = 4'b0010;
    localparam  LINE_2_RST  = 4'b0100;
    localparam  LINE_3_RST  = 4'b1000;

    localparam  BUFF_012    = 2'd0;
    localparam  BUFF_123    = 2'd1;
    localparam  BUFF_230    = 2'd2;
    localparam  BUFF_301    = 2'd3;
    // control signal
    wire            ou_gsc_data_ready, ou_gsc_result_valid, ou_gsc_first, ou_gsc_last, ou_gsc_pre;
    wire            ctl_gsc_data_valid, ctl_gsc_result_ready;
    
    wire    [3:0]   ou_buff_full, ou_buff_empty;
    wire            buff_done_rd;
    wire    [2:0]   number_of_line_full, number_of_line_empty;
    wire            ctl_buff_rden, ctl_buff_wren;
    wire    [1:0]   ctl_buff_line_select, ctl_buff_buffer_select, ctl_buff_new;
    wire    [3:0]   ctl_buff_rst_line, ctl_re_read;

    wire            ou_convol_data_ready, ou_convol_result_valid, ou_convol_last_pixel;
    wire            ctl_convol_valid, ctl_convol_last_pixel, ctl_convol_result_ready; 

    wire            ctl_counter_en, ctl_buffer_ready, ctl_first, ctl_not_shift, buff_rd;
    wire    [2:0]   ctl_pre, ctl_last;
    // datapath signal
    wire    [31:0]  in_gsc_din;
    wire    [31:0]  ou_gsc_dout;
    wire    [31:0]  ou_buff_row00, ou_buff_row01, ou_buff_row02, 
                    ou_buff_row10, ou_buff_row11, ou_buff_row12, 
                    ou_buff_row20, ou_buff_row21, ou_buff_row22;
    wire    [3:0]   in_kernel_addr;
    wire    [31:0]  ou_kernel_x, ou_kernel_y;
    wire    [7:0]   ou_convol_dout;
    wire    [7:0]   ou_thres_dout;

    assign  in_gsc_din = in_fifo_host_to_fpga_dout;
    /////////////////////////////////////    
    //           CONTROLLER            //
    /////////////////////////////////////   
    localparam  INITIAL_STATE = 2'd0;
    localparam  EXECUTE_STATE = 2'd2;
    localparam  READING_STATE = 2'd1;
    localparam  WRITING_STATE = 2'd3;

    // finite-state-machine signal
    reg     [1:0]   current_state, counter;
    reg             first_flag, not_shift;
    reg     [2:0]   last_flag, pre_flag;
    wire    [1:0]   next_state;

    // counter register
    always @(posedge bus_clk) begin
        if (rst)
            counter <= 2'd0;
        else if (ctl_counter_en)
            counter <= counter + 2'd1;
    end
    
    // flag register
    // {first, pre, last} == 1-0-0 --> don't care
    // {first, pre, last} == 1-1-0 --> don't care
    // {first, pre, last} == 1-0-1 --> store first status --> if done_rd then last_flag=0
    // {first, pre, last} == 1-1-1 --> store first status --> if done_rd then pre_flag=0
    // {first, pre, last} == 0-0-0 --> don't care
    // {first, pre, last} == 0-1-0 --> store pre stataus
    // {first, pre, last} == 0-1-1 --> store last status
    // {first, pre, last} == 0-0-1 --> don't care
    always @(posedge bus_clk) begin
        if (rst) begin
            first_flag <= 1'b0;
            last_flag <= 3'd0;
            pre_flag   <= 3'd0;
            not_shift <= 1'b1;
        end
        else begin 
            first_flag  <= ctl_first;
            pre_flag    <= ctl_pre;
            last_flag   <= ctl_last;
            not_shift   <= ctl_not_shift;
        end

    end

    // current state
    always @(posedge bus_clk) begin
        if (rst)
            current_state <= INITIAL_STATE;
        else
            current_state <= next_state;
    end

    // next state
    assign next_state = (current_state == INITIAL_STATE && in_fifo_host_to_fpga_empty == 1'b1)  ? INITIAL_STATE :
                        (current_state == INITIAL_STATE && in_fifo_host_to_fpga_empty == 1'b0)  ? READING_STATE :
                        (current_state == READING_STATE && ctl_buffer_ready)                    ? EXECUTE_STATE :
                        (current_state == READING_STATE && !ctl_buffer_ready)                   ? READING_STATE :
                        (current_state == EXECUTE_STATE && !ctl_buffer_ready)                   ? READING_STATE :
                        ((current_state == READING_STATE || current_state == EXECUTE_STATE)
                        && in_fifo_fpga_to_host_full == 1'b1)                                   ? WRITING_STATE :
                        (current_state == WRITING_STATE && in_fifo_fpga_to_host_full == 1'b0)   ? READING_STATE :
                                                                                                  current_state ;

    // output
    assign ctl_not_shift                = (not_shift == 1'b1 && buff_rd) ? 1'b0 : not_shift;
    assign ctl_first                    = (ou_gsc_first && (last_flag == 1'b1 || pre_flag == 1'b1)) ? 1'b1 : 1'b0;
    assign ctl_pre                      = (ou_gsc_pre && ctl_buff_wren) ? {1'b1, ctl_buff_line_select} : 
                                          (buff_done_rd == 1'b1 && ctl_buff_buffer_select == pre_flag) ? 3'd0 : pre_flag;
    assign ctl_last                     = (ou_gsc_last && ctl_buff_wren) ? {1'b1, ctl_buff_line_select} :
                                          (buff_done_rd == 1'b1 && ctl_buff_buffer_select == last_flag) ? 3'd0 : last_flag;
    assign ctl_buffer_ready             = (buff_done_rd == 1'b1) ? 1'b0 :
                                          (first_flag) ? 1'b1 :
                                          ({1'b1, ctl_buff_buffer_select} == pre_flag) ? 1'b1 :  
                                          ({1'b1, ctl_buff_buffer_select} == last_flag) ? 1'b1 :
                                          (number_of_line_full >= 3'd3) ? 1'b1 : 1'b0;

    assign ou_fifo_host_to_fpga_rden    = (current_state == INITIAL_STATE && rst == 1'b0) ? 1'b1 : 
                                          ((current_state == READING_STATE || current_state == EXECUTE_STATE) && ou_gsc_data_ready == 1'b1) ? 1'b1 : 1'b0;
    assign ou_fifo_fpga_to_host_wren    = (current_state == WRITING_STATE || ou_convol_result_valid == 1'b1) ? 1'b1 : 1'b0;

    assign ctl_gsc_data_valid           = ((current_state == READING_STATE || current_state == EXECUTE_STATE) && in_fifo_host_to_fpga_empty == 1'b0) ? 1'b1 : 1'b0;
    assign ctl_gsc_result_ready         = ((current_state == READING_STATE || current_state == EXECUTE_STATE) && number_of_line_full != 3'd4 ) ? 1'b1 : 1'b0;

    assign ctl_buff_wren                = ((current_state == READING_STATE || current_state == EXECUTE_STATE) && number_of_line_full != 3'd4 
                                                                                                              && ou_gsc_result_valid == 1'b1) ? 1'b1 : 1'b0;
    assign buff_rd                      = ((current_state == READING_STATE || current_state == EXECUTE_STATE) && ctl_buffer_ready == 1'b1
                                                                                                              && ou_convol_data_ready == 1'd1) ? 1'b1 : 1'b0;
    assign ctl_buff_rden                = buff_rd;
    assign ctl_buff_line_select         = (ou_buff_full[0] == 1'b0) ? LINE_0_EN : 
                                          (ou_buff_full[1] == 1'b0) ? LINE_1_EN : 
                                          (ou_buff_full[2] == 1'b0) ? LINE_2_EN : 
                                          (ou_buff_full[3] == 1'b0) ? LINE_3_EN : 
                                          LINE_0_EN;
    assign ctl_counter_en               = (buff_done_rd == 1'b1) ? 1'b1 : 1'b0;
    assign ctl_buff_buffer_select       = counter;
    assign ctl_buff_rst_line            = (number_of_line_full < 3'd3 && pre_flag[2] == 1'b0 && last_flag[2] == 1'b0)   ? NO_LINE_RST :
                                          (ctl_buff_buffer_select == BUFF_012 && buff_done_rd == 1'b1)                  ? LINE_0_RST  :
                                          (ctl_buff_buffer_select == BUFF_123 && buff_done_rd == 1'b1)                  ? LINE_1_RST  :
                                          (ctl_buff_buffer_select == BUFF_230 && buff_done_rd == 1'b1)                  ? LINE_2_RST  :
                                          (ctl_buff_buffer_select == BUFF_301 && buff_done_rd == 1'b1)                  ? LINE_3_RST  : 
                                          NO_LINE_RST;
    assign ctl_re_read                  = (number_of_line_full < 3'd3 && pre_flag[2] == 1'b0 && last_flag[2] == 1'b0)   ? NO_LINE_RST : 
                                          (ctl_buff_buffer_select == BUFF_012 && buff_done_rd == 1'b1)                  ? 4'b0110 :
                                          (ctl_buff_buffer_select == BUFF_123 && buff_done_rd == 1'b1)                  ? 4'b1100 :
                                          (ctl_buff_buffer_select == BUFF_230 && buff_done_rd == 1'b1)                  ? 4'b1001 :
                                          (ctl_buff_buffer_select == BUFF_301 && buff_done_rd == 1'b1)                  ? 4'b0011 : 
                                          NO_LINE_RST;

    assign ctl_buff_new                 = ({1'b1, ctl_buff_buffer_select} == pre_flag)  ? 2'd2 :
                                          ({1'b1, ctl_buff_buffer_select} == last_flag) ? 2'd1 : 2'd0;

    assign ctl_convol_valid             = ((current_state == READING_STATE || current_state == EXECUTE_STATE) && ctl_buffer_ready == 1'b1) ? 1'b1 : 1'b0;
    assign ctl_convol_result_ready      = ~in_fifo_fpga_to_host_full;
    assign ctl_convol_last_pixel        = (buff_done_rd == 1'b1 && {1'b1, ctl_buff_buffer_select} == last_flag) ? 1'b1 : 1'b0;
    ////////////////////////////////////    
    //            DATAPATH            //
    ////////////////////////////////////   
    grayscale_converter gsc_block(
        .clk(bus_clk),
        .rst(rst),
        .in_data_valid(ctl_gsc_data_valid),
        .in_result_ready(ctl_gsc_result_ready),
        .in_rgb_pixel(in_gsc_din),
        .ou_data_ready(ou_gsc_data_ready),
        .ou_result_valid(ou_gsc_result_valid),
        .ou_grayscale_pixel(ou_gsc_dout),
        .ou_first_frame(ou_gsc_first),
        .ou_pre_last(ou_gsc_pre),
        .ou_last_frame(ou_gsc_last)
        );

    buffer_module #(.width(FRAME_WIDTH)) buff_block(
        .clk(bus_clk),
        .rst(rst),
        .rst_line(ctl_buff_rst_line),
        .in_data(ou_gsc_dout),
        .in_data_valid(ctl_buff_wren),
        .in_rden(ctl_buff_rden),
        .in_re_read(ctl_re_read),
        .in_load_new_frame(ctl_buff_new),
        .line_en_selection(ctl_buff_line_select),
        .in_buffer_select(ctl_buff_buffer_select),
        .ou_row00(ou_buff_row00), 
        .ou_row01(ou_buff_row01), 
        .ou_row02(ou_buff_row02),
        .ou_row10(ou_buff_row10), 
        .ou_row11(ou_buff_row11), 
        .ou_row12(ou_buff_row12),
        .ou_row20(ou_buff_row20), 
        .ou_row21(ou_buff_row21), 
        .ou_row22(ou_buff_row22),
        .ou_full(ou_buff_full),
        .ou_empty(ou_buff_empty)
        );

    assign number_of_line_full  = {2'b00, ou_buff_full[0]} + 
                                  {2'b00, ou_buff_full[1]} + 
                                  {2'b00, ou_buff_full[2]} + 
                                  {2'b00, ou_buff_full[3]};

    assign number_of_line_empty = {2'b00, ou_buff_empty[0]} + 
                                  {2'b00, ou_buff_empty[1]} + 
                                  {2'b00, ou_buff_empty[2]} + 
                                  {2'b00, ou_buff_empty[3]};
    assign buff_done_rd         = (number_of_line_empty == 3'd3) ? 1'b1 : 1'b0;
    
    LUT kernel_block ( 
        .in_LUT_select(in_kernel_addr),
        .ou_LUT1(ou_kernel_x), 
        .ou_LUT2(ou_kernel_y)
        );

    convol convolution_block(
        .clk(bus_clk),
        .rst(rst),
        .in_data_valid(ctl_convol_valid),
        .in_last_pixel(ctl_convol_last_pixel),
        .in_result_ready(ctl_convol_result_ready),
        .in_slide_window_0(ou_buff_row00),
        .in_slide_window_1(ou_buff_row01),
        .in_slide_window_2(ou_buff_row02),
        .in_slide_window_3(ou_buff_row10),
        .in_slide_window_4(ou_buff_row11),
        .in_slide_window_5(ou_buff_row12),
        .in_slide_window_6(ou_buff_row20),
        .in_slide_window_7(ou_buff_row21),
        .in_slide_window_8(ou_buff_row22),
        .in_kernel_coeff_x(ou_kernel_x),
        .in_kernel_coeff_y(ou_kernel_y),
        .ou_data_ready(ou_convol_data_ready),
        .ou_feature_extraction_valid(ou_convol_result_valid),
        .ou_feature_extraction(ou_convol_dout),
        .ou_last_pixel(ou_convol_last_pixel),
        .ou_kernel_address(in_kernel_addr)
        );

    threshold #(.thres(75)) thres_block(
        .in_pxl(ou_convol_dout),
        .ou_pxl(ou_thres_dout)
        );
    
    assign ou_fifo_fpga_to_host_din = {16'd0, ou_thres_dout , {7'd0, ou_convol_last_pixel}};
endmodule