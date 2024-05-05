/*
 *  Authors       : Xavier Salva, Pol Marcet
 *  Creation Date : April, 2024
 *  Description   : Next line prefetcher for the Sargantana processor
 *  History       :
 */
import drac_pkg::*;
import hpdcache_pkg::*;

module hwpf_nl
    //  Parameters
    //  {{{
#(
    integer LANE_SIZE = 64 // Size of the cache line
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
    input  req_cpu_dcache_t               cpu_req_i,

    // Requests emitted by the prefetcher
    output logic                          arbiter_req_valid_o,
    input  logic                          arbiter_req_ready_i,
    output hpdcache_req_t                 arbiter_req_o
);
    // }}}
    // Local signals
    int i;
    // {{{
    // Logic to decide if we feed from the CPU
    typedef logic [6:0] tid_t;
    tid_t tid_q;

    // Data of the line being fed from the CPU
    // Keep the same size for now
    typedef addr_t cpu_addr_t;
    cpu_addr_t cpu_addr;

    // Next lane being sent to the queue
    logic insert_queue;
    cpu_addr_t insert_value_queue;
    // }}}

    // Stack instance
    // {{{
    // Stack
    logic stack_push_i;
    cpu_addr_t stack_val_i;
    logic stack_pop_i;
    logic stack_valid_o;
    cpu_addr_t stack_req_o;

    hwpf_stack stack (
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .flush_i(flush_i),
        .lock_i(lock_i),

        // CPU push gate
        .push_i(stack_push_i),
        .val_i(stack_val_i),
        // CPU pop gate
        .pop_i(stack_pop_i),

        // Request emission
        .valid_o(stack_valid_o),
        .req_o(stack_req_o)
    );

    logic fifo_push_i[2];
    cpu_addr_t fifo_req_i[2];
    logic fifo_hits_o[2];

    hwpf_fifo fifo(
        .clk_i(clk_i),
        .rst_ni(rst_ni),
        .flush_i(flush_i),
        .lock_i(lock_i),

        // CPU request issued
        .take_req_i(fifo_push_i),
        .cpu_req_i(fifo_req_i),

        // Requests emitted by the prefetcher
        .req_hits_o(fifo_hits_o),

        // UNEEDED
        .read_i(1'b0),
        .arbiter_req_valid_o(),
        .arbiter_req_o()
    );
    // }}}

    // Arbiter default assignations
    assign arbiter_req_o.uncacheable = 1'b0;
    assign arbiter_req_o.sid = '0;
    assign arbiter_req_o.tid = '0;
    assign arbiter_req_o.need_rsp = 1'b0;

    // Decide if we have data to send to the arbiter.
    // We will try to send the latest value that would have been
    // inserted into the queue if available.
    assign arbiter_req_valid_o = ~lock_i && (stack_valid_o || insert_queue);
    assign arbiter_req_o.addr = insert_queue ? insert_value_queue : stack_req_o;

    function logic cpu_feed_res(req_cpu_dcache_t cpu_req_i, logic lock_i, ref tid_t tid_q);
        if (tid_q != cpu_req_i.rd) begin
            tid_q = cpu_req_i.rd; // Assign the new tid being fed
            return ~lock_i; // If the prefetcher is not locked, it can feed from the CPU request now
        end
        else begin
            return 1'b0; // We already fetched this line
        end
    endfunction

    always@(posedge clk_i, negedge rst_ni) begin
      logic cpu_feed;

      if(~rst_ni) begin
        tid_q = '0; // Reset the tid being processed
        cpu_feed = 1'b0; // Don't feed from the CPU
      end
      else begin
        cpu_feed = cpu_feed_res(cpu_req_i, lock_i, tid_q);
      end


      if (cpu_feed) begin
        // Save the address from the CPU request (do downsizing here if needed, remove lane size bits and top bits)
        integer next_lane_size = LANE_SIZE;
        cpu_addr = cpu_req_i.io_base_addr;

        // We are going to insert the new entry in the FIFO
        fifo_push_i[0] = 1'b1;
        fifo_req_i[0] = cpu_addr;

        // How do I look up the cpu_addr in the FIFO?


        if (!fifo_hits_o[0]) begin
            // It's the first time we see this new entry;
            // we are going to push it to the FIFO and await another match to start prefetching.
        end
        else begin
            // Match! Now lets see if we had already prefetched the next line
            cpu_addr_t next_addr = cpu_addr+next_lane_size;

            // We are also going to push this entry into the FIFO
            fifo_push_i[1] = 1'b1;
            fifo_req_i[1] = next_addr;

            if (!fifo_hits_o[1]) begin
                // Send this to the list of addresses to prefetch
                insert_queue = 1'b1;
                insert_value_queue = next_addr;
            end
        end
      end

      if (~lock_i && insert_queue && arbiter_req_ready_i) begin
        // Skip the queue and send it directly
      end
      else if (~lock_i && insert_queue) begin
        // Send the next address in the queue
        stack_val_i = insert_value_queue;
        stack_push_i = 1'b1;
        insert_queue = 1'b0;
      end
      else if (~lock_i && arbiter_req_ready_i) begin
        // Extract a value from the queue
        stack_pop_i = 1'b1;
      end
    end

endmodule
