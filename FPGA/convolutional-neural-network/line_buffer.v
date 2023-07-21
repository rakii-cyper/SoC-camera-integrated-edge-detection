module line_buffer #(parameter length       = 640, 
                     parameter stride       = 1,        // Stride = 1 || 2  
                     parameter padding      = 0,
                     parameter kernel_size  = 3)        // Max kernel_size = 3
(
    input   wire            clk,
    (* direct_reset = "true" *)  
    input   wire            rst,
    input   wire            use_as_padding,
    input   wire [31:0]     din,
    input   wire            din_valid,              // Capture din when input valid and circuit ready
    output  wire            din_ready,
    output  wire [31:0]     dout_a,                 // [a, b, c, d, e, f]
    output  wire [31:0]     dout_b,                 // [a, b, c, d, e, f]
    output  wire [31:0]     dout_c,                 // [a, b, c, d, e, f]
    input   wire            dout_ready,             // Release dout when output ready and circuit valid
    output  wire            dout_valid,
    output  wire            din_last,
    output  wire            dout_last
);

    reg     [31:0]  line [length - 1:0];
    reg     [9:0]   wrPntr;
    reg     [9:0]   rdPntr;
    wire            en_write, en_read;
    wire            buf_wr_done;

    assign din_ready    = ~buf_wr_done & !use_as_padding;               // Buffer in ready while reg_file is not full and not in padding
    assign en_write     = din_ready & din_valid & !use_as_padding;
    
    assign dout_valid   = buf_wr_done;                                  // Buffer out valid when writing is done
    assign en_read      = dout_ready & dout_valid;

    assign buf_wr_done  = (wrPntr == length) ? 1'b1 : 1'b0;  
    assign din_last     = ((wrPntr == length - 1) || use_as_padding) ? 1'b1 : 1'b0;  
    assign dout_last    = (rdPntr == length - stride) ? 1'b1 : 1'b0;    

    always @(posedge clk) begin                         // Detect when write is done
        if(rst)
            wrPntr <= 'd0;    
        else if (use_as_padding)                        // Skip write to this line
            wrPntr <= length;
        else if (en_write)
            wrPntr <= wrPntr + 'd1;
        else
            wrPntr <= wrPntr;
    end

    always @(posedge clk) begin                         // Detect when read is done
        if (rst)
            rdPntr <= 'd0;
        else if (en_read)
            rdPntr <= (rdPntr == length - stride) ? 'd0 : rdPntr + stride;
        else
            rdPntr <= rdPntr;
    end


    genvar reg_idx;
    generate
        for (reg_idx = 0; reg_idx <length; reg_idx = reg_idx+1) begin
            always @(posedge clk) begin
                if (rst)
                    line[reg_idx] <= 'b0;
                else if (en_write)
                    line[reg_idx] <=    (reg_idx != 0) ? line[reg_idx - 1]        // Shift data
                                        : (reg_idx == 0) ? din
                                        : line[reg_idx];
                else if (en_read)
                    line[reg_idx] <=    (reg_idx != 0) ?
                                            ((reg_idx - stride) < 0) ? line[length + (reg_idx - stride)]
                                            : line[reg_idx - stride]
                                        : (reg_idx == 0) ? line[length - stride]
                                        : line[reg_idx];
                else
                    line[reg_idx] <= line[reg_idx];
            end
        end
    endgenerate

    assign dout_a    =  (padding != 0) ?
                            (rdPntr < padding) ? 'd0
                            : line[0]
                        : line[length - 1];
    assign dout_b    =  (kernel_size > 1) ? (padding != 0) ? line[length - 1] : line[length - 2] : 'dz;
    assign dout_c    =  (kernel_size > 2) ? 
                            (padding != 0) ?
                                (rdPntr + padding > length - 1) ? 'd0
                                : line[length - 2]
                            : line[length - 3]
                        : 'dz;
endmodule