//*****************  router fsm based on the moore state machine  ***************************

module router_fsm(clock,resetn,pkt_valid,data_in,fifo_full,fifo_empty_0,fifo_empty_1,fifo_empty_2,
                  soft_reset_0,soft_reset_1,soft_reset_2,parity_done,low_packet_valid,
                  write_enb_reg,detect_add,ld_state,laf_state,lfd_state,full_state,rst_int_reg,busy);

input clock,resetn,pkt_valid,fifo_full,fifo_empty_0,fifo_empty_1,fifo_empty_2;
input soft_reset_0,soft_reset_1,soft_reset_2,parity_done,low_packet_valid;
input [1:0] data_in; // sir said we have to create a temporary register to store it? for latching the address
output write_enb_reg,detect_add,ld_state,laf_state,lfd_state,full_state,rst_int_reg,busy;
  
// parameter declaration for the states   
parameter DECODE_ADDRESS     = 3'b000,
          LOAD_FIRST_DATA 	 = 3'b001,
          LOAD_DATA 		     = 3'b010,
          WAIT_TILL_EMPTY 	 = 3'b011,
          CHECK_PARITY_ERROR = 3'b100,
          LOAD_PARITY 		   = 3'b101,
          FIFO_FULL_STATE 	 = 3'b110,
          LOAD_AFTER_FULL 	 = 3'b111;


   //************* latch the address ********************
  //   reg [1:0] addr; // a temporary register to store the data_in
  // always @(posedge clock ) begin  // when the detect is one that time only the data_in is assigned to the internal address register "addr".
  //   if(!resetn) addr <= 2'b11;
  //   else if (soft_reset_0 || soft_reset_1 || soft_reset_2) 
  //     addr  <= 2'b11;

  //   else if (detect_add) // here it is used to latch the first byte as a header byte
  //       addr <= data_in;
      
  // end 
  /************************************************************/      


  // present state and next state
  reg [2:0] ps,ns;

   // present state and reset logic     
  always@(posedge clock)
    begin
      if(!resetn || soft_reset_0 || soft_reset_1 || soft_reset_2)
        ps <= DECODE_ADDRESS;
      else 
        ps <= ns;
    end
  
  //next state combinational logic
  always@(*) begin   // this block is written by using the state diagram given in the specification
  // here we have to use the latch address like when the latch address, or addr is not equal to 2'b11 then  this case block execute

   // if(addr != 2'b11) begin   //but it is creating more errors, which is just, i don't understand..
      case(ps)
        
        DECODE_ADDRESS : 
                  begin
                    if((pkt_valid && (data_in[1:0]==2'd0) && fifo_empty_0)||
                       (pkt_valid && (data_in[1:0]==2'd1) && fifo_empty_1)||
                       (pkt_valid && (data_in[1:0]==2'd2) && fifo_empty_2))
                      
                      ns = LOAD_FIRST_DATA;
                    
                    else if((pkt_valid && (data_in[1:0]==2'd0) && (!fifo_empty_0))||
                            (pkt_valid && (data_in[1:0]==2'd1) && (!fifo_empty_1))||
                            (pkt_valid && (data_in[1:0]==2'd2) && (!fifo_empty_2)))
                      
                      ns = WAIT_TILL_EMPTY;
                    
                    else
                      ns = DECODE_ADDRESS;  // default 
                  end
        
        LOAD_FIRST_DATA :  ns = LOAD_DATA;  // no condition then load_data, here there is only one way.
        
        LOAD_DATA       : 
                        begin
			      			if(fifo_full)
				 				ns=FIFO_FULL_STATE;
                          else if(!fifo_full && !pkt_valid)
				 				ns=LOAD_PARITY;
			      			else
				 				ns=LOAD_DATA;
			   			end 
        
        WAIT_TILL_EMPTY  : 
                        begin
                          if((!fifo_empty_0) || (!fifo_empty_1) || (!fifo_empty_2))
				 			ns=WAIT_TILL_EMPTY;
			      		  else if(fifo_empty_0||fifo_empty_1||fifo_empty_2)
				 			ns=LOAD_FIRST_DATA;
			      		  else
				 			ns=WAIT_TILL_EMPTY;
                         end
        
        CHECK_PARITY_ERROR:
          				begin
			    			if(fifo_full)
			      	 			ns=FIFO_FULL_STATE;
			    			else
			         			ns=DECODE_ADDRESS;

			   			 end

       LOAD_PARITY     	  :	ns=CHECK_PARITY_ERROR; // unconditional
			 

       FIFO_FULL_STATE	  :	   
          				begin
                        	if(!fifo_full)
			         			ns=LOAD_AFTER_FULL;
			      			else if(fifo_full)
			         			ns=FIFO_FULL_STATE;
			  		 		end
        
        LOAD_AFTER_FULL:	   
          				begin
          					if((!parity_done) && (!low_packet_valid))
			   					ns=LOAD_DATA;
          					else if((!parity_done) && (low_packet_valid))
			   					ns=LOAD_PARITY;
          					else if(parity_done)
			   					ns=DECODE_ADDRESS;
			   			 end
               default : ns = DECODE_ADDRESS;
        
      endcase

  //   end
  //  else ns <= DECODE_ADDRESS;  // ?



   end
  
  assign detect_add = ((ps==DECODE_ADDRESS) ? 1'b1 : 1'b0); 
  assign write_enb_reg=((ps==LOAD_DATA||ps==LOAD_PARITY||ps==LOAD_AFTER_FULL) ? 1'b1 : 1'b0);
  assign full_state=((ps==FIFO_FULL_STATE) ? 1'b1 : 1'b0);
  assign lfd_state=((ps==LOAD_FIRST_DATA) ? 1'b1 : 1'b0);
  assign busy=((ps==FIFO_FULL_STATE||ps==LOAD_AFTER_FULL||ps==WAIT_TILL_EMPTY|| ps==LOAD_FIRST_DATA||ps==LOAD_PARITY||ps==CHECK_PARITY_ERROR || !(ps==LOAD_DATA || ps==DECODE_ADDRESS)) ? 1'b1 : 1'b0);

   // the busy signal is deasserted in LOAD_DATA state and reset state(initial state).
  //assign busy=((ps==LOAD_DATA || ps==DECODE_ADDRESS) ? 1'b0 : 1'b1);  // i just add this condition in the above bussy statement
  assign ld_state=((ps==LOAD_DATA) ? 1'b1 : 1'b0);
  assign laf_state=((ps==LOAD_AFTER_FULL) ? 1'b1 : 1'b0);
  assign rst_int_reg=((ps==CHECK_PARITY_ERROR) ? 1'b1 : 1'b0);
  
endmodule






// //****************************** test bench ***************************************
// `timescale 1ns/1ns
// module router_fsm_tb();

// reg clock,resetn,pkt_valid,fifo_full,fifo_empty_0,fifo_empty_1,fifo_empty_2,soft_reset_0,soft_reset_1,soft_reset_2,parity_done,low_packet_valid;
// reg [1:0] data_in;
// wire write_enb_reg,detect_add,ld_state,laf_state,lfd_state,full_state,rst_int_reg,busy;

// parameter T = 10;

// router_fsm DUT(clock,resetn,pkt_valid,data_in,fifo_full,fifo_empty_0,fifo_empty_1,fifo_empty_2,soft_reset_0,soft_reset_1,soft_reset_2,parity_done,low_packet_valid,write_enb_reg,detect_add,ld_state,laf_state,lfd_state,full_state,rst_int_reg,busy);
  
//   parameter DECODE_ADDRESS     = 3'b000,
//             LOAD_FIRST_DATA 	 = 3'b001,
//             LOAD_DATA 		     = 3'b010,
//             WAIT_TILL_EMPTY 	 = 3'b011,
//             CHECK_PARITY_ERROR = 3'b100,
//             LOAD_PARITY 		   = 3'b101,
//             FIFO_FULL_STATE 	 = 3'b110,
//             LOAD_AFTER_FULL 	 = 3'b111;
  
//   reg [21*8:0]string_cmd;

//   always@(DUT.ps)  // it used to call the ps in the dut 
//       begin
//         case (DUT.ps)
// 	    DECODE_ADDRESS     :  string_cmd = "DECODER_ADDRESS_s1";
// 	    LOAD_FIRST_DATA    :  string_cmd = "LOAD_FIRST_DATA_s2";
// 	    LOAD_DATA    	     :  string_cmd = "LOAD_DATA_s3";
// 	    WAIT_TILL_EMPTY    :  string_cmd = "WAIT_TILL_EMPTY_si";
// 	    CHECK_PARITY_ERROR :  string_cmd = "CHECK_PARITY_ERROR_s8";
// 	    LOAD_PARITY    	   :  string_cmd = "LOAD_PARITY_TB";
// 	    FIFO_FULL_STATE    :  string_cmd = "FIFO_FULL_STATE_TB";
// 	    LOAD_AFTER_FULL    :  string_cmd = "LOAD_AFTER_FULL_TB";
// 	    endcase
//       end
  
  
  
//    initial begin
//     clock=1'b0;
//     forever #T clock = ~clock;
//    end

//    task initialize;
//     begin
//     {pkt_valid,fifo_empty_0,fifo_empty_1,fifo_empty_2,fifo_full,parity_done,low_packet_valid}=0;
//     end
//     endtask

//    task DA_LFA_LD_FFS_LAF_DA;
//    begin
//   {resetn,soft_reset_0,soft_reset_1,soft_reset_2} = 0;
//   data_in = 0;
//   {pkt_valid,low_packet_valid} = 2'b01;
//   fifo_full = 0;   // by checking the these 3 lines(191,192,193) during this case it goes from DECODER_ADDRES > LOAD_FIRST_DATA > LOAD_DATA > FIFO_FULL_STATE > LOAD_AFTER_FULL > DECODER_ADDRESS.
//   parity_done = 0;
//   {fifo_empty_0,fifo_empty_1,fifo_empty_2} = 3'b111;
//    end
//    endtask

//    task rst;
//    begin
//    @(negedge clock)
//     resetn=1'b0;
//    @(negedge clock)
//     resetn=1'b1;
//    end
//    endtask

//    task DA_LFD_LD_LP_CPE_DA;  // case scenario -1
//    begin
//    @(negedge clock)  // LOAD_FIRST_DATA_s2
//    begin
//    pkt_valid=1'b1;
//    data_in[1:0]=0;
//    fifo_empty_0=1;
//    end              
//    @(negedge clock) //LOAD_DATA_s3
//    @(negedge clock) //LOAD_PARITY_TB
//    begin
  
//    pkt_valid=0;
//    end
//    @(negedge clock) // CHECK_PARITY_ERROR_s8
//    @(negedge clock) // DECODER_ADDRESS_s1
//    fifo_full=0;
//    end
//    endtask

//    task DA_LFA_LD_FFS_LAF_LP_CPE_DA;  //case scenario - 2
//    begin
//    @(negedge clock)//LOAD_FIRST_DATA_s2
//    begin
//    pkt_valid=1;
//    data_in[1:0]=0;
//    fifo_empty_0=1;
//    end
//    @(negedge clock)//LOAD_DATA_s3
//    @(negedge clock)//FIFO_FULL_STATE_TB
//    fifo_full=1;
//    @(negedge clock)//LOAD_AFTER_FULL_TB
//    fifo_full=0;
//    @(negedge clock)//LOAD_PARITY_TB
//    begin
//    parity_done=0;
//    low_packet_valid=1;
//    end
//    @(negedge clock)//CHECK_PARITY_ERROR_s8
//    @(negedge clock)//DECODER_ADDRESS_s1
//    fifo_full=0;
//    end
//    endtask

//    task DA_LFD_LD_FFS_LAF_LD_LP_CPE_DA;  //case scenario - 3
//    begin
//    @(negedge clock) //LOAD_FIRST_DATA_s2
//    begin
//    pkt_valid=1;
//    data_in[1:0]=0;
//    fifo_empty_0=1;
//    end
//    @(negedge clock) //LOAD_DATA_s3
//    @(negedge clock) // FIFO_FULL_STATE_TB
//    fifo_full=1;
//    @(negedge clock) // LOAD_AFTER_FULL_TB
//    fifo_full=0;
//    @(negedge clock)  // LOAD_DATA_s3
//    begin
//       low_packet_valid=0;
// 	parity_done=0;

//    end  // LOAD_PARITY_TB
//    @(negedge clock)
//    begin
//    fifo_full=0;
//    pkt_valid=0;
//    end
//    @(negedge clock) // CHECK_PARITY_ERROR_s8
//    @(negedge clock) // DECODER_ADDRESS_s1
//    fifo_full=0;
//    end
//    endtask
   
//    task DA_LFD_LD_LP_CPE_FFS_LAF_DA;  //case scenario - 4
//    begin
//    @(negedge clock)  // LOAD_FIRST_DATA_s2
//    begin
//    pkt_valid=1;
//    data_in[1:0]=0;
//    fifo_empty_0=1;
//    end        
//    @(negedge clock)   // LOAD_DATA_s3
//    @(negedge clock)   // LOAD_PARITY_TB
//    begin
//    fifo_full=0;
//    pkt_valid=0;
//    end
//    @(negedge clock)   // CHECK_PARITY_ERROR_s8 
//    @(negedge clock)   // FIFO_FULL_STATE_TB
//    fifo_full=1;
//    @(negedge clock)   // LOAD_AFTER_FULL_TB
//    fifo_full=0;
//   @(negedge clock)    // DECODER_ADDRESS_s1
//    parity_done=1;
//    end
//    endtask
//    task soft_rst; begin    // for testing soft_reset whether working or not 
//     @(negedge clock) soft_reset_0 = 1'b1;
//     @(negedge clock) soft_reset_0 = 1'b0;
//     #15;
//     @(negedge clock) soft_reset_1 = 1'b1;
//     @(negedge clock) soft_reset_1 = 1'b0;
//     #15;
//     @(negedge clock) soft_reset_2 = 1'b1;
//     @(negedge clock) soft_reset_2 = 1'b0;
//     @(negedge clock) ;
//    end
//    endtask


//    initial
//    begin
//    rst;
//    DA_LFA_LD_FFS_LAF_DA;  // case scenario - 2 in notice
//    #20;
//    rst;
//    @(negedge clock);
//    initialize;
//    #20
//    $display("--------- DA_LFD_LD_LP_CPE_DA (1)--------"); // case scenario - 1 in notice.
  
//     DA_LFD_LD_LP_CPE_DA;
// 	rst;
// 	#30

//   // DA_LFD_LD_LP_CPE_DA;
// 	// rst;
// 	// #30
//   $display("--------- DA_LFA_LD_FFS_LAF_LP_CPE_DA (2)--------"); // case scenario -4 in notice
//     DA_LFA_LD_FFS_LAF_LP_CPE_DA;
// 	rst;
// 	#30
//   $display("--------- DA_LFD_LD_FFS_LAF_LD_LP_CPE_DA (3)--------"); // case scenario - 3 in notice
// 	DA_LFD_LD_FFS_LAF_LD_LP_CPE_DA;
// 	rst;
// 	#30
//   $display("--------- DA_LFD_LD_LP_CPE_FFS_LAF_DA (4)--------"); // case scenario - 5 in notice
//     DA_LFD_LD_LP_CPE_FFS_LAF_DA;
//   #30;
//    $display("---------three soft_reset conditions (5)--------");
// 	soft_rst;

   
//    end

//   initial $monitor("Reset=%b, State=%s, det_add=%b, write_enb_reg=%b, full_state=%b, lfd_state=%b, busy=%b, ld_state=%b, laf_state=%b, rst_int_reg=%b, low_packet_valid=%b",resetn,string_cmd,detect_add,write_enb_reg,full_state,lfd_state,busy,ld_state,laf_state,rst_int_reg,low_packet_valid);
   
//    initial
//    begin
//    $dumpfile("router_fsm.vcd");
//    $dumpvars();
//    #1000 $finish;
//    end
//    endmodule 
