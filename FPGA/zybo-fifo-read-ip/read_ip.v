module fifo_reader #(parameter width=32, parameter num_buffs=3) (
    input   wire                clk,
    (* direct_reset = "true" *)  
    input   wire                rst,
    
    input   wire    [width-1:0] in_fifo_data,
    input   wire                in_fifo_empty,
    output  wire                ou_fifo_rden,

    input   wire    [width-1:0] ou_result_data,    
    input   wire                in_result_ready,
    output  wire                ou_result_valid
);  

    reg     [width - 1:0]   buff [num_buffs-1:0];       // Buffer
    (* direct_enable = "true" *)
    wire                    enable_buff;                // Buffer enable signal
    wire                    rd_en;                      // Enable reading when both ready and valid singal enable
    reg     [2:0]           Pntr;                       // Shift Register
    reg                     empty_flag;                 // Delay empty signal 1 clock

    assign rd_en = ou_result_valid & in_result_ready;

    always @(posedge clk) begin
        if (rst)
            empty_flag <= 1'b1;
        else
            empty_flag <= in_fifo_empty;
    end

    always @(negedge clk) begin
        if (rst)
            Pntr <= 'b0;
        else begin
            if (enable_buff == 1'b1 && in_result_ready == 1'b0 && Pntr != 3'd4)
                Pntr <= Pntr + 'b1;
            else if (rd_en && empty_flag == 1'b1)
                Pntr <= Pntr - 'b1;
        end
    end

    genvar reg_idx;
    generate
        for (reg_idx = 0; reg_idx < num_buffs; reg_idx = reg_idx + 1) begin
            always @(posedge clk) begin
                if (rst)
                    buff[reg_idx] <= 'b0;
                else if (enable_buff)
                    buff[reg_idx] <= (reg_idx != 0) ? buff[reg_idx-1] : in_fifo_data;
            end
        end
    endgenerate

    assign enable_buff      = (!empty_flag && ou_fifo_rden) ? 1'b1 : 1'b0;
    assign ou_fifo_rden     = (Pntr < 3'd4 || in_result_ready) ? 1'b1 : 1'b0;
    assign ou_result_valid  = ((ou_fifo_rden && !empty_flag && Pntr == 3'd0) || Pntr > 3'd0) ? 1'b1 : 1'b0;
    assign ou_result_data   = (rd_en) ? 
                                    (Pntr == 3'd0) ? in_fifo_data   :
                                    (Pntr == 3'd1) ? buff[0]        :
                                    (Pntr == 3'd2) ? buff[1]        :
                                                     buff[2]        :
                              {width-1{1'b0}};
endmodule