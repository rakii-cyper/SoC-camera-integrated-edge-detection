module buffer_block #(parameter width       = 640,      // Number value per row
                      parameter height      = 480,      // Number of rows
                      parameter stride      = 1,        // Stride = 1 || 2  
                      parameter padding     = 0,        // Number of padding
                      parameter kernel_size = 3)        // Max size of kernel is 3
(
    input   wire            clk,
    (* direct_reset = "true" *)  
    input   wire            rst,
    input   wire [31:0]     din,    
    input   wire            din_valid,              // Capture din when input valid and circuit ready
    output  wire            din_ready,    
    output  wire [31:0]     dout_line_0_0, 
    output  wire [31:0]     dout_line_0_1,
    output  wire [31:0]     dout_line_0_2,
    output  wire [31:0]     dout_line_1_0,
    output  wire [31:0]     dout_line_1_1,
    output  wire [31:0]     dout_line_1_2,
    output  wire [31:0]     dout_line_2_0,
    output  wire [31:0]     dout_line_2_1,
    output  wire [31:0]     dout_line_2_2,
    input   wire            dout_ready,             // Release dout when output ready and circuit valid
    output  wire            dout_valid,
    output  wire            dout_last,
    output  wire            dout_eof
);
    reg                                     padding_ctl_rst;
    reg     [stride+(kernel_size-1):0]      padding_controller;
    reg     [9:0]                           line_r_counter, line_w_counter;
    wire    [9:0]                           line_w_counter_next;
    reg     [stride+(kernel_size-1):0]      line_w_selector;
    reg     [stride+(kernel_size-1):0]      output_decoder      [2:0];
    wire    [stride+(kernel_size-1):0]      output_decoder_next [2:0];
    wire    [stride+(kernel_size-1):0]      line_r_selector, line_r_selector_next, line_w_ready, line_r_valid;
    wire    [7:0]                           line_r_valid_count, line_w_ready_count;
    wire    [31:0]                          line_dout_a [stride+(kernel_size-1):0];   
    wire    [31:0]                          line_dout_b [stride+(kernel_size-1):0];   
    wire    [31:0]                          line_dout_c [stride+(kernel_size-1):0];
    wire    [stride+(kernel_size-1):0]      line_reset;     
    wire    [stride+(kernel_size-1):0]      line_din_valid;   
    wire    [stride+(kernel_size-1):0]      line_din_ready;  
    wire    [stride+(kernel_size-1):0]      line_dout_valid;  
    wire    [stride+(kernel_size-1):0]      line_dout_ready;  
    wire    [stride+(kernel_size-1):0]      line_dout_last;  
    wire    [stride+(kernel_size-1):0]      line_din_last; 
    wire                                    r_next_line, w_next_line;

    // Handle while eof
    always @(posedge r_next_line, posedge rst) begin
        if (rst) 
            line_r_counter <= 'd0;
        else
            line_r_counter <= line_r_counter + stride;
    end

    assign line_w_counter_next = (w_next_line) ? line_w_counter + 'd1 : 'd0;
    always @(posedge w_next_line, posedge rst) begin
        if (rst) begin
            line_w_counter <= 'd0;
        end
        else begin
            line_w_counter <= line_w_counter_next;
        end
    end

    reg [9:0] debug;
    always @(posedge w_next_line) begin
        debug <= line_w_counter_next;
    end

    always @(posedge clk) begin
        if (rst)
            padding_ctl_rst <= 1'b1;
        else if (padding_controller != 'd0)
            padding_ctl_rst <= 1'b0;
        else
            padding_ctl_rst <= 1'b1;
    end

    always @(posedge clk, negedge padding_ctl_rst) begin
        if (!padding_ctl_rst)
            padding_controller <= 'd0;
        else if (rst)
            padding_controller <= 'd0;
        else if (padding != 0)
            padding_controller <=   (line_w_counter < padding) ? line_w_selector
                                    : ((line_w_counter > height) && (line_w_counter <= height + padding)) ? ((line_w_selector << 1) | (line_w_selector >> (stride+kernel_size-1))) 
                                    : 'd0;
        else
            padding_controller <= padding_controller;
    end
    assign dout_eof = (line_r_counter >= height) ? 1'b1 : 1'b0;
    ///////////////////////////////////////////////////////////////////////////////////////////


    // Control when read next line and write next line
    assign w_next_line  = (line_w_counter <= height + padding) ? 
                            (|line_dout_last && ~(|(line_w_selector & line_w_ready))) ? 1'b1 
                            : (|line_din_last && line_w_ready_count != 'd1) ? 1'b1
                            : 1'b0 
                          : 1'b0;
    assign r_next_line  = |line_dout_last && dout_ready;
    ///////////////////////////////////////////////////////////////////////////////////////////


    // Control which line is enable for reading
    genvar r_slt_idx;
    generate
        for (r_slt_idx = 0; r_slt_idx < 3; r_slt_idx = r_slt_idx + 1) begin: l_r_slt_tmp
            wire [stride+(kernel_size-1):0] or_of_two;
            wire [stride+(kernel_size-1):0] or_of_two_next;
        end
    endgenerate

    genvar next_read_lines_idx;
    generate 
        for (next_read_lines_idx = 0; next_read_lines_idx < 3; next_read_lines_idx = next_read_lines_idx + 1) begin: next_read_lines
            assign output_decoder_next[next_read_lines_idx] = (output_decoder[next_read_lines_idx] << stride) | 
                                                              (output_decoder[next_read_lines_idx] >> kernel_size);
        end
    endgenerate 

    genvar out_decoder_idx;
    generate
        for (out_decoder_idx = 0; out_decoder_idx < 3; out_decoder_idx = out_decoder_idx + 1) begin
            if (out_decoder_idx == 0) begin
                assign l_r_slt_tmp[out_decoder_idx].or_of_two = output_decoder[out_decoder_idx][stride+(kernel_size-1):0];
                assign l_r_slt_tmp[out_decoder_idx].or_of_two_next = output_decoder_next[out_decoder_idx][stride+(kernel_size-1):0];
            end
            else begin
                assign l_r_slt_tmp[out_decoder_idx].or_of_two = l_r_slt_tmp[out_decoder_idx-1].or_of_two | output_decoder[out_decoder_idx][stride+(kernel_size-1):0];
                assign l_r_slt_tmp[out_decoder_idx].or_of_two_next = l_r_slt_tmp[out_decoder_idx-1].or_of_two_next | output_decoder_next[out_decoder_idx][stride+(kernel_size-1):0];
            end

            always @(posedge clk) begin
                if (rst)
                    output_decoder[out_decoder_idx] <=  (out_decoder_idx < kernel_size) ? 
                                                            (out_decoder_idx == 0) ? 'd1 
                                                            : (out_decoder_idx == 1) ? {{stride+1{1'b0}},2'b10} 
                                                            : (out_decoder_idx == 2) ? {{stride{1'b0}},3'b100} 
                                                            : 'd0
                                                        : 'd0;
                else if (r_next_line && dout_valid && dout_ready)
                    output_decoder[out_decoder_idx] <= output_decoder_next[out_decoder_idx];
                else
                    output_decoder[out_decoder_idx] <= output_decoder[out_decoder_idx];
            end
        end
    endgenerate   

    assign line_r_selector      = l_r_slt_tmp[2].or_of_two;
    assign line_r_selector_next = l_r_slt_tmp[2].or_of_two_next;
    assign line_dout_ready      = line_r_selector & {(stride+kernel_size){dout_ready}} & {(stride+kernel_size){dout_valid}};
    assign line_r_valid         = line_r_selector & line_dout_valid;

    genvar sum_of_two_r_idx;
    generate
        for (sum_of_two_r_idx = 0; sum_of_two_r_idx < stride + kernel_size; sum_of_two_r_idx = sum_of_two_r_idx + 1) begin: valid_count_r_tmp
            wire [7:0] sum_of_two_r;
        end
    endgenerate    

    genvar count_valid_line_r_idx;
    generate
        for (count_valid_line_r_idx = 0; count_valid_line_r_idx < stride + kernel_size; count_valid_line_r_idx = count_valid_line_r_idx + 1) begin: count_num_of_valid_line
            if (count_valid_line_r_idx == 0)
                assign valid_count_r_tmp[count_valid_line_r_idx].sum_of_two_r = {7'b0, line_r_valid[count_valid_line_r_idx]};
            else 
                assign valid_count_r_tmp[count_valid_line_r_idx].sum_of_two_r = valid_count_r_tmp[count_valid_line_r_idx - 1].sum_of_two_r + {7'b0, line_r_valid[count_valid_line_r_idx]};
        end
    endgenerate    

    assign line_r_valid_count = valid_count_r_tmp[stride+(kernel_size-1)].sum_of_two_r;
    assign dout_valid       = (line_r_valid_count >= kernel_size) ? 1'b1 : 1'b0;
    ///////////////////////////////////////////////////////////////////////////////////////////


    // Control which line is enable for reading
    always @(posedge clk) begin
        if (rst)
            line_w_selector <= 'b1;
        else if (w_next_line && (din_valid || line_w_counter > height))
            line_w_selector <= (line_w_selector << 1) | (line_w_selector >> (stride+kernel_size-1));
        else 
            line_w_selector <= line_w_selector;
    end

    genvar sum_of_two_w_idx;
    generate
        for (sum_of_two_w_idx = 0; sum_of_two_w_idx < stride + kernel_size; sum_of_two_w_idx = sum_of_two_w_idx + 1) begin: ready_count_w_tmp
            wire [7:0] sum_of_two_w;
        end
    endgenerate    

    genvar count_ready_line_w_idx;
    generate
        for (count_ready_line_w_idx = 0; count_ready_line_w_idx < stride + kernel_size; count_ready_line_w_idx = count_ready_line_w_idx + 1) begin: count_num_of_ready_line
            if (count_ready_line_w_idx == 0)
                assign ready_count_w_tmp[count_ready_line_w_idx].sum_of_two_w = {7'b0, line_din_ready[count_ready_line_w_idx]};
            else 
                assign ready_count_w_tmp[count_ready_line_w_idx].sum_of_two_w = ready_count_w_tmp[count_ready_line_w_idx - 1].sum_of_two_w + {7'b0, line_din_ready[count_ready_line_w_idx]};
        end
    endgenerate    

    assign line_w_ready_count   = ready_count_w_tmp[stride+(kernel_size-1)].sum_of_two_w;
    assign line_din_valid       = line_w_selector & {(stride+kernel_size){din_valid}};    
    assign line_w_ready         = line_w_selector & line_din_ready;
    assign din_ready            = |line_w_ready;
    ///////////////////////////////////////////////////////////////////////////////////////////


    // Control which line is reset
    assign line_reset = (rst) ? {(stride+kernel_size){1'b1}} : (|line_dout_last && dout_ready) ? ~line_r_selector_next : 'd0;
    ///////////////////////////////////////////////////////////////////////////////////////////


    // Output
    genvar out_internal_idx;
    generate
        for (out_internal_idx = 0; out_internal_idx < stride + kernel_size; out_internal_idx = out_internal_idx + 1) begin: out_select
            wire [31:0] line_0_0;
            wire [31:0] line_0_1;
            wire [31:0] line_0_2;
            wire [31:0] line_1_0;
            wire [31:0] line_1_1;
            wire [31:0] line_1_2;
            wire [31:0] line_2_0;
            wire [31:0] line_2_1;
            wire [31:0] line_2_2;
        end
    endgenerate

    genvar out_idx;
    generate
        for (out_idx = 0; out_idx < stride + kernel_size; out_idx = out_idx + 1) begin : dout_line_generator
            if (out_idx == 0) begin
                assign out_select[out_idx].line_0_0 = (output_decoder[0][out_idx]) ? line_dout_a[out_idx] : 'dz;
                assign out_select[out_idx].line_0_1 = (output_decoder[0][out_idx]) ? line_dout_b[out_idx] : 'dz;
                assign out_select[out_idx].line_0_2 = (output_decoder[0][out_idx]) ? line_dout_c[out_idx] : 'dz;

                assign out_select[out_idx].line_1_0 = (output_decoder[1][out_idx]) ? line_dout_a[out_idx] : 'dz;
                assign out_select[out_idx].line_1_1 = (output_decoder[1][out_idx]) ? line_dout_b[out_idx] : 'dz;
                assign out_select[out_idx].line_1_2 = (output_decoder[1][out_idx]) ? line_dout_c[out_idx] : 'dz;

                assign out_select[out_idx].line_2_0 = (output_decoder[2][out_idx]) ? line_dout_a[out_idx] : 'dz;
                assign out_select[out_idx].line_2_1 = (output_decoder[2][out_idx]) ? line_dout_b[out_idx] : 'dz;
                assign out_select[out_idx].line_2_2 = (output_decoder[2][out_idx]) ? line_dout_c[out_idx] : 'dz;
            end

            else begin
                assign out_select[out_idx].line_0_0 = (output_decoder[0][out_idx]) ? line_dout_a[out_idx] : out_select[out_idx-1].line_0_0;
                assign out_select[out_idx].line_0_1 = (output_decoder[0][out_idx]) ? line_dout_b[out_idx] : out_select[out_idx-1].line_0_1;
                assign out_select[out_idx].line_0_2 = (output_decoder[0][out_idx]) ? line_dout_c[out_idx] : out_select[out_idx-1].line_0_2;

                assign out_select[out_idx].line_1_0 = (output_decoder[1][out_idx]) ? line_dout_a[out_idx] : out_select[out_idx-1].line_1_0;
                assign out_select[out_idx].line_1_1 = (output_decoder[1][out_idx]) ? line_dout_b[out_idx] : out_select[out_idx-1].line_1_1;
                assign out_select[out_idx].line_1_2 = (output_decoder[1][out_idx]) ? line_dout_c[out_idx] : out_select[out_idx-1].line_1_2;

                assign out_select[out_idx].line_2_0 = (output_decoder[2][out_idx]) ? line_dout_a[out_idx] : out_select[out_idx-1].line_2_0;
                assign out_select[out_idx].line_2_1 = (output_decoder[2][out_idx]) ? line_dout_b[out_idx] : out_select[out_idx-1].line_2_1;
                assign out_select[out_idx].line_2_2 = (output_decoder[2][out_idx]) ? line_dout_c[out_idx] : out_select[out_idx-1].line_2_2;
            end
        end
    endgenerate

    assign dout_line_0_0 = out_select[stride+(kernel_size-1)].line_0_0;
    assign dout_line_0_1 = out_select[stride+(kernel_size-1)].line_0_1;
    assign dout_line_0_2 = out_select[stride+(kernel_size-1)].line_0_2;
    
    assign dout_line_1_0 = (kernel_size > 1) ? out_select[stride+(kernel_size-1)].line_1_0 : 'dz;
    assign dout_line_1_1 = (kernel_size > 1) ? out_select[stride+(kernel_size-1)].line_1_1 : 'dz;
    assign dout_line_1_2 = (kernel_size > 1) ? out_select[stride+(kernel_size-1)].line_1_2 : 'dz;

    assign dout_line_2_0 = (kernel_size > 2) ? out_select[stride+(kernel_size-1)].line_2_0 : 'dz;
    assign dout_line_2_1 = (kernel_size > 2) ? out_select[stride+(kernel_size-1)].line_2_1 : 'dz;
    assign dout_line_2_2 = (kernel_size > 2) ? out_select[stride+(kernel_size-1)].line_2_2 : 'dz;

    assign dout_last = |line_dout_last;   
    ///////////////////////////////////////////////////////////////////////////////////////////

    genvar i;
    generate
        for (i = 0; i < stride + kernel_size; i = i + 1) begin : line_buff
            line_buffer #(.length(width), .stride(stride), .padding(padding), .kernel_size(kernel_size)) line_buff_module (
                .clk(clk),
                .rst(line_reset[i]),
                .use_as_padding(padding_controller[i]),
                .din(din),
                .din_valid(line_din_valid[i]),
                .din_ready(line_din_ready[i]),
                .dout_a(line_dout_a[i][31:0]),
                .dout_b(line_dout_b[i][31:0]), 
                .dout_c(line_dout_c[i][31:0]),
                .dout_ready(line_dout_ready[i]),
                .dout_valid(line_dout_valid[i]),
                .din_last(line_din_last[i]),
                .dout_last(line_dout_last[i])
            );
        end
    endgenerate       
endmodule