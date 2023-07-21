module clock_domain_crossing #(width=32) (
    input   wire                in_destination_clock,
    input   wire    [width-1:0] in_data,
    output  reg     [width-1:0] ou_data
);
    reg [width-1:0] crossing_data;

    always @(posedge in_destination_clock) begin
        crossing_data <= in_data;
        ou_data <= crossing_data;
    end
endmodule


module bram_128x32 (
    input   wire            clk,
    input   wire            in_wren,
    input   wire    [31:0]  in_data,
    input   wire    [6:0]   in_wr_addr,
    input   wire    [6:0]   in_rd_addr,
    output  wire    [31:0]  ou_data
);
    (* ram_style = "block", cascade_height = 1 *)
    reg     [31:0]  mem     [127:0];

    always @(posedge clk) begin
        if (in_wren)
            mem[in_wr_addr] <= in_data;
    end

    assign ou_data = mem[in_wr_addr];
endmodule


module frame_reader #(width=32) (
    input   wire                clk_100,
    input   wire                clk_10,

    input   wire                in_fifo1_wren,
    output  wire                ou_fifo1_full,
    input   wire    [width-1:0] in_fifo1_data,
    input   wire                in_fifo1_open,

    input   wire                in_fifo2_wren,
    output  wire                ou_fifo2_full,
    input   wire    [width-1:0] in_fifo2_data,
    input   wire                in_fifo2_open,

    input   wire                in_afifo_open,  // asyn fifo open -> user_r_read_32_open

    input   wire                in_frame_ready,
    output  wire                ou_frame_valid,
    output  wire                ou_frame_last,
    output  wire    [width-1:0] ou_frame1_data,
    output  wire    [width-1:0] ou_frame2_data
);
    wire    reset_fifo1, reset_fifo2, reset_counter;
    wire    reset_fifo1_10MHz, reset_fifo2_10MHz;

    (* direct_enable = "true" *)
    wire    enable_counter;

    wire    handshake, internal_frame_ready, internal_frame_valid;

    wire    internal_fifo1_rden, fifo1_rden, fifo1_empty;
    wire    result_fifo1_ready, result_fifo1_valid;

    wire    internal_fifo2_rden, fifo2_rden, fifo2_empty;
    wire    result_fifo2_ready, result_fifo2_valid;

    wire    bram_wren;
    reg     frame1_data_selector;

    wire    [6:0]   bram_rd_addr, bram_wr_addr;
    wire    [31:0]  bram_dout, fifo1_dout, fifo2_dout, result_fifo1_dout, result_fifo2_dout;
    reg     [6:0]   frame_cnt;

    assign reset_fifo1          = ~in_fifo1_open & ~in_afifo_open;
    assign reset_fifo2          = ~in_fifo2_open & ~in_afifo_open;
    assign reset_counter        = reset_fifo1_10MHz | reset_fifo2_10MHz;
    assign handshake            = in_frame_ready & ou_frame_valid;    
    assign ou_frame_valid       = ~reset_fifo1 & ~reset_fifo2 & result_fifo2_valid & (result_fifo1_valid | frame1_data_selector);
    assign ou_frame_last        = (frame_cnt == 127) ? 1'b1 : 1'b0;
    assign result_fifo1_ready   = ~reset_fifo1 & ~reset_fifo2 & in_frame_ready & result_fifo2_valid;
    assign result_fifo2_ready   = ~reset_fifo1 & ~reset_fifo2 & in_frame_ready & (result_fifo1_valid | frame1_data_selector);
    assign enable_counter       = handshake;
    assign bram_wr_addr         = frame_cnt;
    assign bram_rd_addr         = frame_cnt;
    assign bram_wren            = handshake;


    // RESET SIGNAL FROM 100MHz TO 10MHz
    /////////////////////////////////////////////////////////////////////////////////
    clock_domain_crossing #(.width(1)) reset_fifo1_signal_CDC (
        .in_destination_clock(clk_10),
        .in_data(reset_fifo1),
        .ou_data(reset_fifo1_10MHz)
    );

    clock_domain_crossing #(.width(1)) reset_fifo2_signal_CDC (
        .in_destination_clock(clk_10),
        .in_data(reset_fifo2),
        .ou_data(reset_fifo2_10MHz)
    );
    /////////////////////////////////////////////////////////////////////////////////


    // FRAME COUNTER
    /////////////////////////////////////////////////////////////////////////////////
    always @(posedge clk_10 or posedge reset_counter) begin
        if (reset_counter)
            frame_cnt <= 'b0;
        else if (enable_counter)
            frame_cnt <= frame_cnt + 'b1;
    end
    /////////////////////////////////////////////////////////////////////////////////
    

    // FRAME 1 READER
    /////////////////////////////////////////////////////////////////////////////////    
    // fifo_32x512 fifo_32_port1 (
    //     .clk(clk_100),
    //     .srst(reset_fifo1),
    //     .din(in_fifo1_data),
    //     .wr_en(in_fifo1_wren),
    //     .rd_en(fifo1_rden),
    //     .dout(fifo1_dout),
    //     .full(ou_fifo1_full),
    //     .empty(fifo1_empty)
    // );

    async_fifo_32 fifo_32_port1 (
        .rst(reset_fifo1),
        .wr_clk(clk_100),
        .rd_clk(clk_10),
        .din(in_fifo1_data),
        .wr_en(in_fifo1_wren),
        .rd_en(fifo1_rden),
        .dout(fifo1_dout),
        .full(ou_fifo1_full),
        .empty(fifo1_empty)
    );

    fifo_reader #(.width(32)) ip_read_port1 (
        .clk(clk_10 && !frame1_data_selector),
        .rst(reset_fifo1),
        .in_fifo_data(fifo1_dout),
        .in_fifo_empty(fifo1_empty),
        .ou_fifo_rden(fifo1_rden),
        .ou_result_data(result_fifo1_dout),    
        .in_result_ready(result_fifo1_ready),
        .ou_result_valid(result_fifo1_valid)
    );  

    bram_128x32 compared_frame (
        .clk(clk_10),
        .in_wren(bram_wren),
        .in_data(result_fifo1_dout),
        .in_wr_addr(bram_wr_addr),
        .in_rd_addr(bram_rd_addr),
        .ou_data(bram_dout)        
    );

    always @(posedge clk_10 or posedge reset_fifo1) begin
        if (reset_fifo1)
            frame1_data_selector <= 1'b0;
        else if (frame_cnt == 127 && handshake && !frame1_data_selector)
            frame1_data_selector <= 1'b1;
    end

    assign ou_frame1_data = (frame1_data_selector) ? bram_dout : result_fifo1_dout;
    /////////////////////////////////////////////////////////////////////////////////


    // FRAME 2 READER
    /////////////////////////////////////////////////////////////////////////////////  
    // fifo_32x512 fifo_32_port2 (
    //     .clk(clk_100),
    //     .srst(reset_fifo2),
    //     .din(in_fifo2_data),
    //     .wr_en(in_fifo2_wren),
    //     .rd_en(fifo2_rden),
    //     .dout(fifo2_dout),
    //     .full(ou_fifo2_full),
    //     .empty(fifo2_empty)
    // );

    async_fifo_32 fifo_32_port2 (
        .rst(reset_fifo2),
        .wr_clk(clk_100),
        .rd_clk(clk_10),
        .din(in_fifo2_data), 
        .wr_en(in_fifo2_wren),
        .rd_en(fifo2_rden),
        .dout(fifo2_dout),
        .full(ou_fifo2_full),
        .empty(fifo2_empty)
    );

    fifo_reader #(.width(32)) ip_read_port2 (
        .clk(clk_10),
        .rst(reset_fifo2),
        .in_fifo_data(fifo2_dout),
        .in_fifo_empty(fifo2_empty),
        .ou_fifo_rden(fifo2_rden),
        .ou_result_data(result_fifo2_dout),    
        .in_result_ready(result_fifo2_ready),
        .ou_result_valid(result_fifo2_valid)
    ); 

    assign ou_frame2_data = result_fifo2_dout;
    /////////////////////////////////////////////////////////////////////////////////
endmodule