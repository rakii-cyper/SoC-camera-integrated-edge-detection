module threshold #(parameter thres = 75)(
input [7:0] in_pxl,
output [7:0]ou_pxl
);
assign ou_pxl = (in_pxl <= thres) ? 'd0 : 'd255;
endmodule