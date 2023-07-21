
module lineBuffer #(parameter width = 640)(
input           clk,
input           rst,
input           [31:0] in_data,
input           in_re_read,
input           in_data_valid,
output          [31:0] ou_data_0,
output          [31:0] ou_data_1,
output          [31:0] ou_data_2,
input           in_rd_data,
output          ou_full,
output          ou_empty
);
// wire [9:0] next_rd_Pntr;
reg [31:0] line [width - 1:0]; //line buffer
reg [9:0] wrPntr;
reg [9:0] rdPntr;

genvar reg_idx;
generate
    for (reg_idx = 0; reg_idx <width; reg_idx = reg_idx+1) begin
        always @(posedge clk) begin
        if (rst)
            line[reg_idx] <= 'b0;
        else if (in_data_valid)
            line[reg_idx] <= (reg_idx != 0) ? line[reg_idx-1] :
                             (reg_idx == 0) ? in_data : line[reg_idx];
        else if (in_rd_data)
            line[reg_idx] <= (reg_idx != 0) ? line[reg_idx-1] :
                             (reg_idx == 0) ? line[width - 1] : line[reg_idx];
        end
    end
endgenerate

always @(posedge clk)
begin
    if(rst)
        wrPntr <= 'd0;    
    else if(in_data_valid)
        wrPntr <= wrPntr + 'd1;
end

assign ou_data_0    = line[width - 1];
assign ou_data_1    = (rdPntr == width - 1) ? 32'd0 : line[width - 2];
assign ou_data_2    = (rdPntr >= width - 2) ? 32'd0 : line[width - 3];

always @(posedge clk)
begin
    if (rst || in_re_read)
        rdPntr <= 10'd0;
    else if (in_rd_data) 
        rdPntr <= rdPntr + 10'd1;
end

assign ou_full      = (wrPntr == width) ? 1'b1 : 1'b0;    
assign ou_empty     = (rdPntr == width) ? 1'b1 : 1'b0;    
endmodule