module router_reg(clock,resetn,pkt_valid,data_in,fifo_full,detect_add,
                  ld_state,laf_state,full_state,lfd_state,rst_int_reg,err,
                  parity_done,low_packet_valid,dout);

input clock,resetn,pkt_valid,fifo_full,detect_add,ld_state,laf_state,full_state,lfd_state,rst_int_reg;
input [7:0]data_in;
output reg err,parity_done,low_packet_valid;
output reg [7:0]dout;
reg [7:0]header,int_reg,int_parity,ext_parity;
  
  
  //------------------------------DATA OUT LOGIC---------------------------------

	always@(posedge clock)
   	begin
      if(!resetn)
      	begin
	     dout  <=8'b0;
	     header <=8'b0;
	     int_reg<=8'b0;
       	end
      else if(detect_add && pkt_valid && data_in[1:0]!=2'b11)
	     header<=data_in;
      else if(lfd_state)
	     dout<=header;
      else if(ld_state && !fifo_full)
	     dout<=data_in;
      else if(ld_state && fifo_full)
	     int_reg<=data_in;
      else if(laf_state)
	     dout<=int_reg;
     end

  //---------------------------LOW PACKET VALID LOGIC----------------------------
	
      	always@(posedge clock)
	   		begin
              if(!resetn)
	 				low_packet_valid<=1'b0; 
         		else if(rst_int_reg)
	 				low_packet_valid<=1'b0;

              else if(ld_state && !pkt_valid) 
         			low_packet_valid<=1'b1;
			end
  //----------------------------PARITY DONE LOGIC--------------------------------
	
	always@(posedge clock)
	begin
      if(!resetn)
	  parity_done<=1'b0;
     else if(detect_add)
	  parity_done<=1'b0;
      else if((ld_state && !fifo_full && !pkt_valid)
              ||(laf_state && low_packet_valid && !parity_done))
	  parity_done<=1'b1;
	end

//---------------------------PARITY CALCULATE LOGIC----------------------------

	always@(posedge clock)
	begin
      if(!resetn)
	 int_parity<=8'b0;
	else if(detect_add)
	 int_parity<=8'b0;
	else if(lfd_state && pkt_valid)
	 int_parity<=int_parity^header;
	else if(ld_state && pkt_valid && !full_state)   // full_state kind of fifo_full, when the full_state is high that means fifo is full and there is a data left to be passed to the fifo, so in this case int_parity is calculated like this, but you may consider when full_state is 1 then ld_state is also 1 and vice versa. so, using full_state and ld_state both doesn't make any sense, but in reality there is a one clock pulse difference in between them
	 int_parity<=int_parity^data_in;
	else
	 int_parity<=int_parity;
	end
	 

//-------------------------------ERROR LOGIC-----------------------------------

	always@(posedge clock)
		begin
          if(!resetn)
	  			err<=1'b0;
	      else if(parity_done)
	       		begin
	 				if (int_parity == ext_parity)
	    				err<=1'b0;
	 				else 
	    			err<=1'b1;
	 			end
	 	   else
	    		err<=1'b0;
	      end

//-------------------------------EXTERNAL PARITY LOGIC-------------------------

	always@(posedge clock)
	begin
      if(!resetn)
	  		ext_parity<=8'b0;
      else if(detect_add)
	  		ext_parity<=8'b0;
      else if((ld_state && !fifo_full && !pkt_valid) || (laf_state && !parity_done && low_packet_valid))
	  		ext_parity<=data_in;
	 end

endmodule



// //******************** test bench ******************************

// module router_reg_tb();

// reg clock,resetn,pkt_valid,fifo_full,detect_add,ld_state,laf_state,full_state,lfd_state,rst_int_reg;
// reg [7:0]data_in;
// wire err,parity_done,low_packet_valid;
// wire [7:0]dout;
// integer i;
// parameter cycle=10;


// router_reg DUT(clock,resetn,pkt_valid,data_in,fifo_full,detect_add,ld_state,laf_state,full_state,lfd_state,rst_int_reg,err,parity_done,low_packet_valid,dout);

// initial
// begin
//   clock=1'b0;
//   forever #(cycle/2) clock=~clock;
// end

// task rst();
//   begin
//     @(negedge clock)
//     resetn=1'b0;
//     @(negedge clock)
//     resetn=1'b1;
//   end
// endtask

// task initialize();
//   begin
//    pkt_valid<=1'b0;
//    fifo_full<=1'b0;
//    detect_add<=1'b0;
//    ld_state<=1'b0;
//    laf_state<=1'b0;
//    full_state<=1'b0;
//    lfd_state<=1'b0;
//    rst_int_reg<=1'b0;
//   end
// endtask

// task good_pkt_gen_reg;

// reg[7:0]payload_data,parity1,header1;
// reg[5:0]payload_len;
// reg[1:0]addr;

// begin
//  @(negedge clock)
//  payload_len=6'd5;
//  addr=2'b10;
//  pkt_valid=1;
//  detect_add=1;
//  header1={payload_len,addr};
//  parity1=0^header1;
//  data_in=header1;
//  @(negedge clock);
//  detect_add=0;
//  lfd_state=1;
//  full_state=0;
//  fifo_full=0;
//  laf_state=0;
//  for(i=0;i<payload_len;i=i+1)
//  begin
//  @(negedge clock);
//   lfd_state=0;
//   ld_state=1;
//   payload_data={$random}%256;
//   data_in=payload_data;
//   parity1=parity1^data_in;
//  end
//  @(negedge clock);
//  pkt_valid=0;
//  data_in=parity1;
//  @(negedge clock);
//  ld_state=0;
//  end
//  endtask


// task bad_pkt_gen_reg;

// reg[7:0]payload_data,parity1,header1;
// reg[5:0]payload_len;
// reg[1:0]addr;

// begin
//  @(negedge clock)
//  payload_len=6'd5;
//  addr=2'b10;
//  pkt_valid=1;
//  detect_add=1;
//  header1={payload_len,addr};
//  parity1=0^header1;
//  data_in=header1;
//  @(negedge clock);
//  detect_add=0;
//  lfd_state=1;
//  full_state=0;
//  fifo_full=0;
//  laf_state=0;
//  for(i=0;i<payload_len;i=i+1)
//  begin
//  @(negedge clock);
//   lfd_state=0;
//   ld_state=1;
//   payload_data={$random}%256;
//   data_in=payload_data;
//   parity1=parity1^data_in;
//  end
//  @(negedge clock);
//  pkt_valid=0;
//  data_in=46;
//  @(negedge clock);
//  ld_state=0;
//  end
//  endtask
 
 
//  initial
//  begin
//  rst();
//  initialize();
//  good_pkt_gen_reg;
//  rst();
//  bad_pkt_gen_reg;
//  #20
 
//  $finish;
//  end

 
//  initial
//  begin
//  $dumpfile("router_reg.vcd");
//  $dumpvars();
//  end



//  endmodule
	
