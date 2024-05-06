/*
 *  Authors       : Xavier Salva, Pol Marcet
 *  Creation Date : April, 2024
 *  Description   : Next line prefetcher for the Sargantana processor
 *  History       :
 */
import drac_pkg::addr_t;

module hwpf_fifo
    //  Parameters
    //  {{{
#(
    integer LANE_SIZE = 64, // Size of the cache line
    integer QUEUE_DEPTH = 8, // Number of positions in queue
    type cpu_addr_t = addr_t, // Type of the structure to be used
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
    input cpu_addr_t                      cpu_req_i           [INSERTS-1:0],

    output cpu_addr_t                      data_cpu_o    [QUEUE_DEPTH-1:0],
    output logic                           data_valid_o  [QUEUE_DEPTH-1:0]
);


//Fields of non-shifting queue
cpu_addr_t                      data_cpu    [QUEUE_DEPTH-1:0];
logic                           data_valid  [QUEUE_DEPTH-1:0];

assign data_cpu_o = data_cpu;
assign data_valid_o = data_valid;

//Fields of shifting queue
typedef logic [$clog2(QUEUE_DEPTH)-1:0] pointer_t;
typedef logic [$clog2(QUEUE_DEPTH):0] pointer_inv_t;
pointer_t                       pointer_queue [QUEUE_DEPTH-1:0];

// start of the shifting queue
pointer_t                       start_pointer;

//Queue management data
pointer_inv_t                   queue_pos_to_remove [INSERTS-1:0];
pointer_inv_t                   rel_pointer_pos_to_remove   [INSERTS-1:0];

//Queue read/writes
always@(posedge clk_i, negedge rst_ni)
begin
  // in case of reset
  if(~rst_ni) begin
    for(int unsigned i = 0; i < QUEUE_DEPTH; i=i+1) begin
      data_cpu[i] <= '0;
      data_valid[i] <= '0;
      pointer_queue[i] <= i;
      start_pointer = '0;
    end
  end
  // in case of flush
  else if(flush_i) begin
    for(int unsigned i = 0; i < QUEUE_DEPTH; i=i+1) begin
      data_cpu[i] <= '0;
      data_valid[i] <= '0;
      pointer_queue[i] <= i;
      start_pointer = '0;
    end
  end
  //Queue is locked
  else if(lock_i) begin
  end
  // nothing cycle
  else if(!take_req_i[0]) begin
  end
  // normal cycle; we have 1 or more pushes
  else begin
    pointer_t max_pos_shift = '0;
    int unsigned displacement = 0;
    int start_pointer_shift = 0;
    pointer_t set_to = '0;
    pointer_t set_from = '0;

    // Find the position to remove
    for (int i = 0; i < INSERTS; i = i+1) begin
    queue_pos_to_remove[i] = QUEUE_DEPTH;
    if (take_req_i[i]) begin
      for (int j = 0; j < QUEUE_DEPTH; j = j+1) begin
        if (data_valid[j] && cpu_req_i[i] == data_cpu[j]) begin
          queue_pos_to_remove[i] = j;
        end
      end
    end
  end

    // Find the pointer to a remove position
    for (int unsigned i = 0; i < INSERTS; i = i+1) begin
      rel_pointer_pos_to_remove[i] = QUEUE_DEPTH;
      if (take_req_i[i] && queue_pos_to_remove[i] != QUEUE_DEPTH) begin
        for (int j = 0; j < QUEUE_DEPTH; j = j+1) begin
          if (pointer_queue[j] == queue_pos_to_remove[i]) begin
            rel_pointer_pos_to_remove[i] = (j - start_pointer + QUEUE_DEPTH) % QUEUE_DEPTH;
          end
        end
      end
    end

    // Find to which position to move the data to
    for (int unsigned i = 0; i < INSERTS; i = i+1) begin
      if (take_req_i[i] && queue_pos_to_remove[i] != QUEUE_DEPTH) begin
        max_pos_shift = (max_pos_shift < rel_pointer_pos_to_remove[i]) ? rel_pointer_pos_to_remove[i] : max_pos_shift;
      end
    end

    // Move data in queue to the right as many positions as needed to cover the empty slots
    for(int j = max_pos_shift; j >= 0; j = j-1) begin
      for (int unsigned i = 0; i < INSERTS; i = i+1) begin
        if (take_req_i[i] && rel_pointer_pos_to_remove[i] == j) begin
          displacement = displacement + 1;
          continue;
        end
      end
      set_from = (start_pointer + j) % QUEUE_DEPTH;
      set_to = (start_pointer + j + displacement) % QUEUE_DEPTH;
      $display("Setting: %d to %d with vaule: %d previously had: %d", set_to, set_from, pointer_queue[set_from], pointer_queue[set_to]);
      pointer_queue[set_to] = pointer_queue[set_from];
    end

    // Set the moved data to the start of the queue
    for (int unsigned i = 0; i < INSERTS; i = i+1) begin
      if (take_req_i[i] && queue_pos_to_remove[i] != QUEUE_DEPTH) begin
        displacement = displacement - 1;
        set_to = (start_pointer + displacement) % QUEUE_DEPTH;
        $display("[D: %d] Repointing: %d at pos: %d previously had: %d", displacement, queue_pos_to_remove[i], set_to, pointer_queue[set_to]);
        pointer_queue[set_to] = queue_pos_to_remove[i];
      end
    end

    // Add missing data that was not already in queue
    for(int unsigned i = 0; i < INSERTS; i = i+1) begin
      if(take_req_i[i] && queue_pos_to_remove[i] == QUEUE_DEPTH) begin
        start_pointer_shift += 1;
        set_to = (start_pointer - start_pointer_shift + QUEUE_DEPTH) % QUEUE_DEPTH;
        $display("Adding data to queue at: %d pointing at: %d inserting %h vs %h", set_to, pointer_queue[set_to], cpu_req_i[i], data_cpu[pointer_queue[set_to]]);
        data_cpu[pointer_queue[set_to]] = cpu_req_i[i];
        data_valid[pointer_queue[set_to]] = 1'b1;
      end
    end
    start_pointer = (start_pointer - start_pointer_shift + QUEUE_DEPTH) % QUEUE_DEPTH;
  end
end

endmodule
