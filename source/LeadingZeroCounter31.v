//====================================================
// Author      : Ayush Yadav
// Version     : 0.1
//
// Description
// - Counts Leading Zeroes in the input
//====================================================

module LeadingZeroCounter31 (
    input  wire [31:0] X,
    output wire [ 4:0] Y
);

    // dividing the input into 4 sets of 8 bits
    wire [7:0] piece [3:0];
    
    assign piece[3] = X[31:24];
    assign piece[2] = X[23:16];
    assign piece[1] = X[15: 8];
    assign piece[0] = X[ 7: 0];

    // counting and storing the Leading zeroes in each set
    wire [3:0] p_count [3:0];
    wire [7:0] t [3:0];

    generate
        // for each piece
        for (genvar j = 0; j < 4; j = j + 1) begin
            for (genvar i = 7; i >= 0; i = i - 1) begin
                if (i == 7) begin 
                    assign t[j][7] = ~piece[j][7]; 
                end else begin
                    assign t[j][i] = t[j][i+1] & ~piece[j][i];
                end
            end

            // adding the t bits to get the LZC
            assign p_count[j] = t[j][0] + t[j][1] + t[j][2] + t[j][3] + t[j][4] + t[j][5] + t[j][6] + t[j][7]; 
        end
    endgenerate

    // determining if a piece is worth adding to toal

    wire [3:0] to_count;

    assign to_count[3] = 1'b1;
    assign to_count[2] = (p_count[3] == 4'd8);
    assign to_count[1] = to_count[2] && (p_count[2] == 4'd8);
    assign to_count[0] = to_count[1] && (p_count[1] == 4'd8);

    // adding the piece counts

    wire [4:0] f0, f1, f2, f3;

    assign f3 = {1'b0, p_count[3]};
    assign f2 = to_count[2] ? f3 + {1'b0, p_count[2]} : f3;
    assign f1 = to_count[1] ? f2 + {1'b0, p_count[1]} : f2;
    assign f0 = to_count[0] ? f1 + {1'b0, p_count[0]} : f1;

    assign Y = f0;

endmodule