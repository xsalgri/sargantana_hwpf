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
    type cpu_addr_t = req_cpu_dcache_t, // Type of the structure to be used
    integer INSERTS = 2
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
    input logic                           take_req_i          [INSERTS-1:0],
    input logic [6:0]                     tid_req_i           [INSERTS-1:0],
    input cpu_addr_t                      cpu_req_i           [INSERTS-1:0],

    // Read oldest element
    input logic read_i,

    // Requests emitted by the prefetcher
    output logic                          req_hits_o          [INSERTS-1:0],
    output logic                          arbiter_req_valid_o,
    output cpu_addr_t                     arbiter_req_o
);
int i, j, k;


//Fields of non-shifting queue
logic                           data_valid  [QUEUE_DEPTH-1:0];
cpu_addr_t                      data_cpu    [QUEUE_DEPTH-1:0];
logic [6:0]                     data_tid    [QUEUE_DEPTH-1:0];

//Fields of shifting queue
logic [$clog2(QUEUE_DEPTH)-1:0]  pointer_queue [QUEUE_DEPTH-1:0];
logic                           pointer_valid [QUEUE_DEPTH-1:0];

//Queue management data
logic [$clog2(QUEUE_DEPTH)-1:0]  last_in_queue;
logic                           queue_contains_something;
logic                           queue_is_full;

logic [$clog2(QUEUE_DEPTH)-1:0] first_empty_slot_pointer      [INSERTS-1:0];
logic [$clog2(QUEUE_DEPTH)-1:0] queue_head_data_idx;
logic [$clog2(QUEUE_DEPTH)-1:0] position_to_remove            [INSERTS-1:0];
logic                           remove_valid                  [INSERTS-1:0];

logic                          arbiter_req_valid;
cpu_addr_t                     arbiter_req;

  //Find first empty slot for when next valid petition arrives
  always_comb begin
    j = 0;
    for(i = 0; i < QUEUE_DEPTH; i = i+1) begin
      if(data_cpu[i].valid && j < INSERTS) begin
        first_empty_slot_pointer[j] = i;
        j = j+1;
      end
    end
  end

  //Find pointer to pointer to data with tid to remove
  always_comb 
  begin
    for(i = 0; i < QUEUE_DEPTH; i = i+1) begin
      for(j = 0; j < INSERTS; j = j+1) begin
        remove_valid[j] = 1'b0;
        position_to_remove[j] = '0;

        if(take_req_i[j] && data_tid[i] == cpu_req_i[j].rd) begin //request is found a duplicate
          for(k = 0; k < QUEUE_DEPTH; k = k+1) begin
            if(pointer_queue[k] == i) begin
              remove_valid[j] = 1'b1;
              position_to_remove[j] = k;
            end
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
  begin
    int displacement;
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
            data_valid[queue_head_data_idx] <= 1'b0;
            pointer_valid[0] <= 1'b0;
          end

          //Remove arbitrary element from queue
          for(i = 0; i < INSERTS; i = i+1) begin
            if(remove_valid) begin
              displacement = displacement + 1;
              data_valid[pointer_queue[position_to_remove[i]]] <= 1'b0;
              pointer_valid[position_to_remove[i]] <= 1'b0;
            end
          end

          //Displace all elements right within queue
          for(i = 0; i < QUEUE_DEPTH; i = i+1) begin
            int local_displacement;
            local_displacement = 0;

            if(!pointer_valid[i]) begin
              local_displacement = local_displacement + 1;
            end

            if(i <= last_in_queue) begin
              pointer_queue[i] <= (i+local_displacement < QUEUE_DEPTH) ? pointer_queue[i+local_displacement] : '0;
              pointer_valid[i] <= (i+local_displacement < QUEUE_DEPTH) ? pointer_valid[i+local_displacement] : '0;
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

  assign req_hits_o = remove_valid;

endmodule