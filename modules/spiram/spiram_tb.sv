`timescale 1ns / 1ps

import axi_vip_pkg::*;
import design_1_axi_vip_0_0_pkg::*;


module spiram_tb(

                 );
   
   bit clock;
   bit reset_n = 0;

   design_1_wrapper DUT
     (
      .aclk_0(clock),
      .aresetn_0(reset_n)
      );
   
   design_1_axi_vip_0_0_mst_t  master_agent;
   axi_transaction                         wr_txn;
   axi_transaction                         rd_txn;
   logic [31:0] write_data [4]; // Array of 4 words (32-bit example)

   always #5ns clock <= ~clock;
   
   initial begin
      // Step 4 - Create a new agent
      master_agent = new("master vip agent" ,DUT.design_1_i.axi_vip_0.inst.IF);
      // set tag for agents for easy debug
      master_agent.set_agent_tag("Master VIP");
      // set print out verbosity level.
      master_agent.set_verbosity(400);
      // Step 5 - Start the agent
      master_agent.start_master();

      #10
      reset_n = 1;
      
      #10
        
        // write first. then read back from same address.
         
        // write test
        
      wr_txn = master_agent.wr_driver.create_transaction("write transaction");
      wr_txn.set_write_cmd(32'h200,		   // addr
			   XIL_AXI_BURST_TYPE_INCR, // burst type
			   0,			   // id
                           3,			   // len
			   XIL_AXI_SIZE_4BYTE);	   // size
      wr_txn.set_data_block({32'hDEADBEEF, 32'hCAFEF00D, 32'h12345678, 32'h9ABCDEF0}); // Data to write
      master_agent.wr_driver.send(wr_txn);

      #2700ns
        
      // read test
      
      rd_txn = master_agent.rd_driver.create_transaction("read transaction");
      rd_txn.set_read_cmd(32'h200,		   // addr
			  XIL_AXI_BURST_TYPE_INCR, // burst type
			  0,			   // id
                          3,			   // len
			  XIL_AXI_SIZE_4BYTE);	   // size
      master_agent.rd_driver.send(rd_txn);

   end // initial begin
   
   
endmodule
