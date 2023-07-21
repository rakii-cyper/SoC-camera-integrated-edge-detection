module ReLu(
    input   wire    [31:0]  din,
    output  wire    [31:0]  dout
);
    assign dout = (din[31]) ? 'd0 : din;
endmodule

module max_pooling #(parameter kernel_size = 2) (
    input   wire [31:0]     din_line_0_0, 
    input   wire [31:0]     din_line_0_1,
    input   wire [31:0]     din_line_0_2,
    input   wire [31:0]     din_line_1_0,
    input   wire [31:0]     din_line_1_1,
    input   wire [31:0]     din_line_1_2,
    input   wire [31:0]     din_line_2_0,
    input   wire [31:0]     din_line_2_1,
    input   wire [31:0]     din_line_2_2,
    output  wire [31:0]     dout
);
    

endmodule

module soft_max

endmodule