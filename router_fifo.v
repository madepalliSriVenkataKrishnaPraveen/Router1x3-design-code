module router_fifo(clock,resetn,soft_reset,write_enb,read_enb,
                   lfd_state,data_in,full,empty,data_out);
  
  input clock,resetn,soft_reset;
  input write_enb,read_enb,lfd_state;
  input [7:0]data_in;
  
  output reg [7:0] data_out;
  output full,empty;
  
  reg [4:0] rd_pointer,wr_pointer; // here it is 4 bits(for address) + 1 bit.

  reg [6:0] count; //it's length is 7 bits due to the fact that, during the read operation when header byte is read, an internal counter is loaded with the payload length of the packet plus '1'(parity byte) and starts decrementing every clock cycle till it reaches 0. The counter holds 0 till it is reloaded back with a new packet payload length.
//fifo length = payload length of data + 1'b1(parity byte)

  reg [8:0] mem [15:0];//fifo memory declaration

  integer i;

  /******************************************************/
   reg lfd_temp;// guru prasad sir told to take this, time: 33:00
//delay lfd state by one cycle
  
  always@(posedge clock)
    begin
      if(!resetn)
        lfd_temp <= 1'b0;
      else
        lfd_temp <= lfd_state;
    end 
 /*********************************************************/  
  
  //logic for incrementing pointer for read and write operation, another approach to implement fifo.
  //----rd_pointer & wr_pointer generation block----

   always@(posedge clock) 
     begin
       if(!resetn)  // as said in specification active low reset for resetn and active high reset for the soft_reset.
        wr_pointer<=5'b0;
      else if(write_enb && (~full))
        wr_pointer<=wr_pointer+1;
     end
   
   always@(posedge clock) //Read address
     begin
       if(!resetn)
         rd_pointer<=5'b0;
       else if(read_enb && (~empty))
         rd_pointer<=rd_pointer+1;
     end
  
  
  //counter block while reading, logic for the 7 bit counter
  
  always@(posedge clock)
    begin
      if(read_enb && !empty)
        begin
          if((mem[rd_pointer[3:0]][8])==1'b1) //here we have to check for the header, to check whether it is header or not we take 8th bit if 8th bit is 1 the that mem[rd_ptr[3:0]] is a header
            count <= mem[rd_pointer[3:0]][7:2] + 1'b1;//this 1 bit is for parity
        //here fifo counter will be loaded with the payload length plus 1'b1 
          else if(count != 7'b0)
            count <= count - 1'b1;//starts decrementing the counter  
        end
    end

    // Read Operation
  always@(posedge clock) 
    begin
      if(!resetn)
          data_out <= 8'b0;
      else if(soft_reset) 
          data_out <= 8'bz;
      else if((read_enb) && (!empty))
        data_out <= mem[rd_pointer[3:0]][7:0];
      else if(count == 7'b0)   //when counter becomes zero it means data is completely read from the fifo
           data_out <= 8'bz;
    end
  
  // Write Operation
  always@(posedge clock) 
    begin
      if(!resetn || soft_reset)
         begin
            for(i=0;i<16;i=i+1)
            mem[i] <= 9'b0;
         end
      else if(write_enb && (~full))   
         begin
          {mem[wr_pointer[3:0]][8],mem[wr_pointer[3:0]][7:0]} <= {lfd_temp,data_in};
         end
     end
  //Full & empty condition
  
  assign empty = (rd_pointer == wr_pointer) ? 1'b1 : 1'b0;
  assign full  = (wr_pointer ==({~rd_pointer[4],rd_pointer[3:0]})) ? 1'b1 : 1'b0;
  
  
endmodule




// /********************************************************* test bench ***************************************************************************/
// `timescale 1ns/1ps
// module router_fifo_tb;
// reg clock,resetn,soft_reset,write_enb,read_enb,lfd_state;
// reg [7:0] data_in;
// wire empty,full;
// wire [7:0] data_out;

// //dut instantiation
// router_fifo dut (clock,resetn,soft_reset,write_enb,read_enb,lfd_state,data_in,full,empty,data_out);  

// //clock frequency generation
// initial begin
//     clock = 1'b0;
//     forever #10 clock = ~clock;     //time period of this clock is 20ns
// end

// //tasks
// task initialization; begin
//     resetn = 1'b0;  //active low reset, guruprasad sir take 0
//     soft_reset = 1'b1;  //active high reset. guruprasad sir take 0
//     write_enb = 1'b0;
//     read_enb = 1'b0;
// end
// endtask

// task reset; begin
//     @(negedge clock);
//     resetn = 1'b0;
//     @(negedge clock) resetn = 1'b1;    
// end
// endtask

// task soft_rst; begin
//     @(negedge clock) soft_reset = 1'b1;
//     @(negedge clock) soft_reset = 1'b0;
// end
// endtask

// //task for writing into memory location
// task write_fifo(); begin  : B1  //these are local variables
// reg [7:0] payload_data,parity,header;
// reg [5:0] payload_len;  //local port declaration
// reg [1:0] addr;
//     integer i; 
//     @(negedge clock) payload_len = 6'd14; //here the packet size is 16 byte so, the payload length will be 14, and 2 bit are required for address and 1 bit is for the specify that it is a header
//     addr = 2'b01; // anything from 00 to 11, ok
//     header = {payload_len,addr};  // in general it is given by the source network
//     data_in = header;
//     lfd_state = 1'b1; // when the header is sent as the data_in, in this case the lfd_state should be high. because lfd_state is 1 for the header byte only for remaining it is 1'b0
//     write_enb = 1'b1; // we want to write in fifo
// // in this above code from line 147 to 152, as we write data in the fifo(ie. we just write the header in the above step). so, obviously the empty=1'b0, after hitting this line of codes in this task.
   
//     for (i = 0; i<payload_len; i=i+1 ) begin
//       @(negedge clock);
//       lfd_state = 1'b0;
//       payload_data = {$random}%256;  // in 8 bit binary we can represent 0 to 255 numbers.
//       data_in = payload_data; 
//     end
//     @(negedge clock);
//     lfd_state = 1'b0;
//     parity = {$random}%256;  //parity checking happens in the register block, here we are just passing some random shit, to place data in the fifo where the parity has to be.
//     data_in = parity;
// end
// endtask
// //the above write task is writes the 16 bytes of data(packet) in the fifo so, obviously the full becomes high after this step.

// // now the task for reading the data from the memory(fifo)
// task read_fifo();begin
//     @(negedge clock);
//     write_enb = 1'b0;
//     read_enb = 1'b1 ;
// end
// endtask

// //Task for delay
// task delay; begin
//     #50;
// end
// endtask

// //Process to call all the tasks for writing and reading
// initial begin : B2
// integer i;
//   initialization;
//   delay;
//   reset;
//   soft_rst;
//   write_fifo;  // internally this task has a for loop so no need to implement a for-loop again

//   for (i = 0;i<17 ;i = i+1 ) begin
//     read_fifo;  //here we run the for 17 times because to check the empty = 1'b0 case.
//   end

//   delay;

//   read_enb = 1'b0;
// end

// initial begin
//    $monitor($time,"-> data_out =%0b,full =%0b,empty =%0b,data_in =%0b,resetn =%0b,soft_reset =%0b,write_enb =%0b,read_enb =%0b,lfd_state =%0b",data_out,full,empty,data_in,resetn,soft_reset,write_enb,read_enb,lfd_state); 
//    $dumpfile("router_fifo_tb.vcd");
//    $dumpvars;

//    #2000 $finish;
// end

// endmodule
