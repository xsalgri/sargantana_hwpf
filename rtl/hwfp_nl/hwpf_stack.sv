/*
 *  Authors       : Xavier Salva, Pol Marcet
 *  Creation Date : April, 2024
 *  Description   : Next line prefetcher for the Sargantana processor
 *  History       :
 */
import drac_pkg::*;
import hpdcache_pkg::*;

module hwpf_stack
    //  Parameters
    //  {{{
#(
    integer LANE_SIZE = 64, // Size of the cache line
    integer STACK_DEPTH = 8, // Number of positions in queue
    type cpu_addr_t=logic[$size(req_cpu_dcache_t::io_base_addr)-1:0] // Type of the structure to be used
)
    //  }}}
    //  Signals
    //  {{{
(
    input  logic                          clk_i,
    input  logic                          rst_ni,

    input  logic                          flush_i,
    input  logic                          lock_i,

    // CPU push gate
    input logic                           push_i,
    input cpu_addr_t                      val_i,
    // CPU pop gate
    input logic                          pop_i,

    // Request emission
    output logic                          valid_o,
    output cpu_addr_t                     req_o,
);

  //Fields of non-shifting queue
  cpu_addr_t                      data_cpu [STACK_DEPTH-1:0];
  
  // Shifting pointers
  typedef logic [$log2(STACK_DEPTH)-1:0] pointer_t;
  pointer_t                       pointers[STACK_DEPTH-1:0];


  //Fields of shifting queue
  pointer_t                       counter;
  logic                           empty;
  logic                           full;

  // assign empty and full
  assign empty = counter == 0;
  assign full = counter == STACK_DEPTH-1;

  // Output matches the last element of the queue. It is valid if the size of the queue is not 0
  assign valid_o = !empty;
  assign req_o = empty ? 0 : data_cpu[counter-1];

  function void push(input cpu_addr_t val, output )
  endfunction

  //Queue read/writes
  always@(posedge clk_i, negedge rst_ni) begin
    // in case of reset
    if(~rst_ni) begin
      counter <= '0;
      for(int i = 0; i < QUEUE_DEPTH; i=i+1) begin
        data_cpu[i] <= '0;
        pointers[i] <= i;
      end
    end
    // in case of flush
    else if(flush_i) begin
      counter <= '0;
    end
    else if (lock_i) begin
      // do nothing
    end
    // normal cycle
    else begin
      // we have a push/pop
      if (push_i && pop_i) begin
        // We are empty! we will perform just a push
        if (empty) begin
          counter <= 1;
          data_cpu[pointers[0]] <= val_i;
        end
        else begin
          // we just swap the last pointed to element
          data_cpu[pointers[counter-1]] <= val_i;
        end
      end
      // We have a pop
      else if (pop_i) begin
        // We are empty! we will do nothing
        if (empty) begin
          counter <= 0;
        end
        else begin
          // we just decrement the counter
          counter <= counter - 1;
        end
      end
      // We have a push
      else if (push_i) begin
        // We are full! we want to drop the oldest element. We can do this by
        // rotating all of the pointers to the left, and then just modifying
        // the last pointed-to element.
        if (full) begin
          pointer_t tmp = pointers[0];
          for(int i = 0; i < QUEUE_DEPTH-1; i=i+1) begin
            pointers[i] <= pointers[i+ 1];
          end
          pointers[QUEUE_DEPTH-1] <= tmp;
          data_cpu[tmp] <= val_i;
        end
        else begin
          // we just increment the counter
          data_cpu[pointers[counter]] <= val_i;
          counter <= counter + 1;
        end
      end
    end
  end

endmodule