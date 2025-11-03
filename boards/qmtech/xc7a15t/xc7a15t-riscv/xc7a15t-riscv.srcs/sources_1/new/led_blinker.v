`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/26/2025 08:15:37 AM
// Design Name: 
// Module Name: led_blinker
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module led_blinker(
    input CLK_50,
    output led
);
    localparam MIN_BRIGHT = 5;

    reg [31:0] cnt;
    reg [6:0] brightness = MIN_BRIGHT, duty;
    reg led_on;
    reg down = 0;
    
    assign led = led_on;
    
    always @(posedge CLK_50) begin
       cnt <= cnt + 1;
        // for given brightness, apply duty cycle to led
        duty <= duty + 1;
        led_on <= duty < brightness;
    end
    
    always @(posedge cnt[17])
    begin
        // update brightness a few times per second
        if (down) begin
          if (brightness > MIN_BRIGHT) brightness <= brightness - 1;
          else down <= 0;
        end else begin  // counting up
          if (&brightness != 1'b1) brightness <= brightness + 1;
          else down <= 1;
        end
        
    end
endmodule
