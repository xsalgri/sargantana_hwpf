/*
 *  Authors       : Xavier Salva, Pol Marcet
 *  Creation Date : April, 2024
 *  Description   : Next line prefetcher for the Sargantana processor
 *  History       :
 */
import drac_pkg::*;
import hpdcache_pkg::*;

module hwpf_fifo
    //  Parameters
    //  {{{
#(
    integer LANE_SIZE = 64, // Size of the cache line
    integer QUEUE_DEPTH = 8, // Number of positions in queue
    type cpu_addr_t = req_cpu_dcache_t // Type of the structure to be used
)
    //  }}}
    //  Signals
    //  {{{
(
    input  logic                          clk_i,
    input  logic                          rst_ni,

    input  logic                          flush_i,
    input  logic                          lock_i,

    // CPU request issued
    input logic take_req_i,
    input logic [6:0] tid_req_i,
    input cpu_addr_t                      cpu_req_i,

    // Read oldest element
    input logic read_i,

    // Remove arbitrary element from queue by tid
    input logic remove_element_i,
    input logic [6:0] tid_remove_element_i,

    // Requests emitted by the prefetcher
    output logic                          arbiter_req_valid_o,
    output cpu_addr_t                     arbiter_req_o,
);
int i, j;


//Fields of non-shifting queue
logic                           data_valid  [QUEUE_DEPTH-1:0];
cpu_addr_t                      data_cpu    [QUEUE_DEPTH-1:0];
logic [6:0]                     data_tid    [QUEUE_DEPTH-1:0];

//Fields of shifting queue
logic [$log2(QUEUE_DEPTH)-1:0]  pointer_queue [QUEUE_DEPTH-1:0];
logic                           pointer_valid [QUEUE_DEPTH-1:0];

//Queue management data
logic [$log2(QUEUE_DEPTH)-1:0]  last_in_queue;
logic                           queue_contains_something;
logic                           queue_is_full;

logic [$log2(QUEUE_DEPTH)-1:0] first_empty_slot_pointer;
logic [$log2(QUEUE_DEPTH)-1:0] queue_head_data_idx;
logic [$log2(QUEUE_DEPTH)-1:0] position_to_remove;

logic                          arbiter_req_valid;
cpu_addr_t                     arbiter_req;

  //Find first empty slot for when next valid petition arrives
  always_comb begin
    for(i = 0; i < QUEUE_DEPTH; i = i+1) begin
      if(data_cpu[i].valid) begin
        first_empty_slot_pointer = i;
        break;
      end
    end
  end

  //Find pointer to pointer to data with tid to remove
  always_comb 
  begin
    for(i = 0; i < QUEUE_DEPTH; i = i+1) begin
      if(remove_element_i && data_tid[i] == tid_remove_element_i) begin
        for(j = 0; j < QUEUE_DEPTH; j = j+1) begin
          if(pointer_queue[j] == i) begin
            position_to_remove = j;
          end
        end
      end
    end
  end
  //Sets queue as full when pointer to last points to last position in queue
  assign queue_is_full = (last_in_queue == QUEUE_DEPTH-1);

  //Finds address for data to output
  assign queue_head_data_idx = (queue_contains_something) ? pointer_queue[0] : '0;

  //Queue read/writes
  always@(posedge clk_i, negedge rst_ni) 
    int displacement;
  begin
    displacement = 0;
    // in case of reset
    if(~rst_ni) begin
      last_in_queue <= '0;
      queue_contains_something <= '0;
      for(i = 0; i < QUEUE_DEPTH; i=i+1) begin
        data_cpu[i] <= '0;
        data_tid[i] <= '0;
        data_valid[i] <= '0;
        pointer_queue[i] <= '0;
        pointer_valid[i] <= '0;
      end
    end
    else begin
      // in case of flush
      if(flush_i) begin
        last_in_queue <= '0;
        queue_contains_something <= '0;
        for(i = 0; i < QUEUE_DEPTH; i=i+1) begin
          data_cpu[i] <= '0;
          data_tid[i] <= '0;
          data_valid[i] <= '0;

          pointer_queue[i] <= '0;
          pointer_valid[i] <= '0;

          arbiter_req_valid <= '0;
          arbiter_req <= '0;
        end
      end
      else begin
        //Queue is locked
        if(lock_i) begin
        end
        // normal cycle
        else begin
          if(read_i) begin
            displacement = displacement + 1;
            //Set queue outputting
            arbiter_req_valid <= data_cpu[queue_head_data_idx].valid;
            arbiter_req <= data_cpu[queue_head_data_idx];
              
            //Remove Outputting element
            data_valid[pointer_queue[0]] <= 1'b0;
            for(i = 0; i < QUEUE_DEPTH; i = i+1) begin
              //Remove arbitrary element from queue
              if(remove_element_i && position_to_remove == i+displacement) begin
                displacement = displacement + 1;
                data_valid[i+displacement] <= 1'b0;
              end
              //Displace all elements right within queue
              if(i <= last_in_queue) begin
                pointer_queue[i] <= (i+displacement < QUEUE_DEPTH) ? pointer_queue[i+displacement] : '0;
                pointer_valid[i] <= (i+displacement < QUEUE_DEPTH) ? pointer_valid[i+displacement] : '0;
              end
            end
          end
          //Insert element to last position
          //Note: If queue overflows data will be lost
          if(take_req_i && (last_in_queue-displacement+1 < QUEUE_DEPTH)) begin
            pointer_queue[i] <= first_empty_slot_pointer;
            pointer_valid[i] <= take_req_i;

            data_valid[i] <= 1'b1;
            data_cpu[i] <= cpu_req_i;
            data_tid[i] <= cpu_req_i.rd;

            displacement = displacement - 1;
          end

          //Update pointer to last position
          last_in_queue <= last_in_queue + displacement;
        end
      end
    end
  end

  assign queue_is_full = (last_in_queue == QUEUE_DEPTH-1);

  //Output assignments
  assign arbiter_req_valid_o = arbiter_req_valid;
  assign arbiter_req_o = arbiter_req;

endmodule