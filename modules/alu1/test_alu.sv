`timescale 1ns / 1ns
module test_alu();
   reg clk;
   
   CPU cpu(.clk(clk));

   // generate the clock
   initial begin
      clk = 0'b0;
      forever #1 clk = ~clk;
   end

endmodule

/* test program - fibonacci
 1 1 2 3 5 8 13
 step r1 r2
 0    1  1
 1    1  2
 2    2  1  
 
 0  ldc r1 = 1         adc r1 = r0, #1    4101
 1  ldc r2 = 1         adc r2 = r0, #1    4201
 2  add r2 = r1, r2    add r2 = r1, r2    1212
 3  mov r3 = r1        add r3 = r1, r0    
 4  mov r1 = r2        add r1 = r2, r0
 5  mov r2 = r3        add r2 = r3, r0
 6  b   2              b   2
*/
 
 
 
