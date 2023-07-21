module LUT(
input           [3:0]  in_LUT_select,
output          [31:0] ou_LUT1, ou_LUT2
);

assign ou_LUT1 =    (in_LUT_select == 4'd0) ? 32'h3F800000 :
                    (in_LUT_select == 4'd1) ? 32'h00000000 :
                    (in_LUT_select == 4'd2) ? 32'hBF800000 :
                    (in_LUT_select == 4'd3) ? 32'h40000000 :
                    (in_LUT_select == 4'd4) ? 32'h00000000 :
                    (in_LUT_select == 4'd5) ? 32'hC0000000 :
                    (in_LUT_select == 4'd6) ? 32'h3F800000 :
                    (in_LUT_select == 4'd7) ? 32'h00000000 :
                    32'hBF800000;
assign ou_LUT2 =    (in_LUT_select == 4'd0) ? 32'h3F800000 :
                    (in_LUT_select == 4'd1) ? 32'h40000000 :
                    (in_LUT_select == 4'd2) ? 32'h3F800000 :
                    (in_LUT_select == 4'd3) ? 32'h00000000 :
                    (in_LUT_select == 4'd4) ? 32'h00000000 :
                    (in_LUT_select == 4'd5) ? 32'h00000000:
                    (in_LUT_select == 4'd6) ? 32'hBF800000 :
                    (in_LUT_select == 4'd7) ? 32'hC0000000 :
                    32'hBF800000;
// always @(*) begin
//     case(in_LUT_select)
//     4'd0: begin 
//     ou_LUT1 = 32'h3F800000;//1
//     ou_LUT2 = 32'h3F800000;//1
//     end
//     4'd1: begin
//     ou_LUT1 = 32'h00000000;//0
//     ou_LUT2 = 32'h40000000;//2
//     end
//     4'd2: begin
//     ou_LUT1 = 32'hBF800000;//-1
//     ou_LUT2 = 32'h3F800000;//1
//     end
//     4'd3: begin
//     ou_LUT1 = 32'h40000000;//2
//     ou_LUT2 = 32'h00000000;//0
//     end
//     4'd4: begin 
//     ou_LUT1 = 32'h00000000;//0
//     ou_LUT1 = 32'h00000000;//0
//     end
//     4'd5: begin
//     ou_LUT1 = 32'hC0000000;//-2
//     ou_LUT2 = 32'h00000000;//0
//     end
//     4'd6: begin
//     ou_LUT1 = 32'h3F800000;//1
//     ou_LUT2 = 32'hBF800000;//-1
//     end
//     4'd7: begin
//     ou_LUT1 = 32'h00000000;//0
//     ou_LUT2 = 32'hC0000000;//-2
//     end
//     4'd8: begin
//     ou_LUT1 = 32'hBF800000;//-1
//     ou_LUT2 = 32'hBF800000;//-1
//     end
//     endcase
// end
endmodule