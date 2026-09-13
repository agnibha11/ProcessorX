module regfile(input [4:0] rs1, rs2, rd, input [31:0] w_data, input w_en, clk, reset, output [31:0] data_1, data_2);
reg [31:0] REGS [31:0]; //32 32-bit Registers

//Read is Asynchronous as read does not change processor State
//extra MUX to ensure x0 always read as 0, even before reset
assign data_1 = (rs1 == 5'b0) ? 0 : REGS[rs1]; 
assign data_2 = (rs2 == 5'b0) ? 0 : REGS[rs2];

//Write is synchronous as write changes Processor State
integer i;
always @(posedge clk or posedge reset) begin
    if(reset) begin
        for(i = 0; i < 32; i = i + 1) begin
            REGS[i] <= 0; //Synthesizable as parallel resets
        end
    end
    else if(w_en && (rd != 0)) begin   //Write enable and cant override x0 reg
        REGS[rd] <= w_data;
    end
end

endmodule