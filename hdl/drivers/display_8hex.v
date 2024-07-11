`timescale 1ns / 1ps

// provided in previous labs
// displays 8 hex numbers on the 7 segment display
// designed by gim hom
module display_8hex(
    input clk,                 // system clock
    input [31:0] data,         // 8 hex numbers, msb first
    output reg [6:0] seg,      // seven segment display output
    output reg [7:0] strobe    // digit strobe
    );

    localparam bits = 13;
    reg [bits:0] counter = 0;  // clear on power up

    wire [6:0] segments[15:0]; // 16 7 bit memorys
    assign segments[0]  = 7'b100_0000;
    assign segments[1]  = 7'b111_1001;
    assign segments[2]  = 7'b010_0100;
    assign segments[3]  = 7'b011_0000;
    assign segments[4]  = 7'b001_1001;
    assign segments[5]  = 7'b001_0010;
    assign segments[6]  = 7'b000_0010;
    assign segments[7]  = 7'b111_1000;
    assign segments[8]  = 7'b000_0000;
    assign segments[9]  = 7'b001_1000;
    assign segments[10] = 7'b000_1000;
    assign segments[11] = 7'b000_0011;
    assign segments[12] = 7'b010_0111;
    assign segments[13] = 7'b010_0001;
    assign segments[14] = 7'b000_0110;
    assign segments[15] = 7'b000_1110;

    // data and alt values being strobed in
    reg [3:0] current_data;

    always @(*) begin
    case (counter[bits:bits-2])
        3'b000: begin
            current_data = data[31:28];
        end
        3'b001: begin
            current_data = data[27:24];
        end
        3'b010: begin
            current_data = data[23:20];
        end
        3'b011: begin
            current_data = data[19:16];
        end
        3'b100: begin
            current_data = data[15:12];
        end
        3'b101: begin
            current_data = data[11:8];
        end
        3'b110: begin
            current_data = data[7:4];
        end
        3'b111: begin
            current_data = data[3:0];
        end
    endcase
    end

    always @(posedge clk) begin
    counter <= counter + 1;
    seg <= segments[current_data];
    case (counter[bits:bits-2])
        3'b000: begin
            strobe <= 8'b0111_1111;
        end
        3'b001: begin
            strobe <= 8'b1011_1111;
        end
        3'b010: begin
            strobe <= 8'b1101_1111;
        end
        3'b011: begin
            strobe <= 8'b1110_1111;
        end
        3'b100: begin
            strobe <= 8'b1111_0111;
        end
        3'b101: begin
            strobe <= 8'b1111_1011;
        end
        3'b110: begin
            strobe <= 8'b1111_1101;
        end
        3'b111: begin
            strobe <= 8'b1111_1110;
        end
    endcase
    end

endmodule
