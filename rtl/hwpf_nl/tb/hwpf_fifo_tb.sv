
import drac_pkg::*;
import hpdcache_pkg::*;

module hwpf_fifo_tb (
);
    int i;
    
    logic clk;
    logic rst;

    logic flush;
    logic lock;

    req_cpu_dcache_t cpu_req;
    logic arbiter_req_ready;

    logic kill;
    logic kill_tid;

    logic req_valid;
    req_cpu_dcache_t req_arb;

   hwpf_fifo fifo   
   (
    .clk_i(clk),
    .rst_ni(rst),

    .flush_i(flush),
    .lock_i(lock),

    // CPU request issued
    .take_req_i(cpu_req.valid),
    .tid_req_i(cpu_req.rd),
    .cpu_req_i(cpu_req),

    // Read oldest element
    .read_i(arbiter_req_ready),

    // Remove arbitrary element from queue by tid
    .remove_element_i(kill),
    .tid_remove_element_i(kill_tid),

    // Requests emitted by the prefetcher
    .arbiter_req_valid_o(req_valid),
    .arbiter_req_o(req_arb)
);

//Main tb signal driver
initial begin
    //General control Signals
    rst <= 1'b0;
    clk <= 1'b0;
    flush <= 1'b0;
    lock <= 1'b0;

    //Module-specific control signals
    cpu_req <= '0;
    arbiter_req_ready <= 1'b0;
    kill <= 1'b0;
    kill_tid <= '0;

    #20;
    rst <= ~rst;

    #30;
    lock <= 1'b1; //Disable Queue lock
    //Req Data when empty
    arbiter_req_ready <= 1'b1;
    assert(req_arb == '0);
    assert(req_valid == '0);

    #20;
    //Insert one data
    arbiter_req_ready <= 1'b0;
    cpu_req.valid <= 1'b1;
    cpu_req.rd <= 7'h1;
    cpu_req.data_rs1 <= 64'hCAFECAFE;

    #10;
    //Retrieve one data
    cpu_req <= '0;
    arbiter_req_ready <= 1'b1;
    assert(req_valid == 1'b1);
    assert(req_arb.data_rs1 == 64'hCAFECAFE && req_arb.rd == 7'h1);

    #10;
    arbiter_req_ready <= 1'b0;
    cpu_req.valid <= 1'b1;
    cpu_req.rd <= 7'h2;
    cpu_req.data_rs1 <= 64'h1BEEF;
    #10;
    //Insert and retrieve one data simultaneously
    arbiter_req_ready <= 1'b1;
    cpu_req.valid <= 1'b1;
    cpu_req.rd <= 7'h3;
    cpu_req.data_rs1 <= 64'hC0DE1111;

    assert(req_valid == 1'b1);
    assert(req_arb.data_rs1 == 64'h1BEEF && req_arb.rd == 7'h2);

    #10;
    //Now queue is empty
    //Fill queue
    arbiter_req_ready <= 1'b0;
    for(i = 0; i < 8+2; i = i+1) begin
        cpu_req.valid <= 1'b1;
        cpu_req.rd <= i;
        cpu_req.data <= {32'hDEADBEEF, i[31:0]};
        #10;
    end

    //Now queue is full and has lost rd 8 and 9 (intended)!
    cpu_req <= '0;
    arbiter_req_ready <= 1'b1;
    for(i = 0; i < 8; i = i+1) begin
        assert(req_valid == 1'b1);
        assert(req_arb.data_rs1 == {32'hDEADBEEF, i[31:0]} && req_arb.rd == i);
        #10;
    end
    //Now queue is empty!

    //check overflow is lost
    arbiter_req_ready <= 1'b0;
    assert(req_valid == 1'b0);
    assert(req_arb <= '0);
    #20;

    //Fill queue and remove element 2
    arbiter_req_ready <= 1'b0;
    for(i = 0; i < 8; i = i+1) begin
        cpu_req.valid <= 1'b1;
        cpu_req.rd <= i;
        cpu_req.data <= {32'hDEADBEEF, i[31:0]};
        #10;
    end

    arbiter_req_ready <= 1'b1;
    cpu_req <= '0;
    kill <= 1'b1;
    kill_tid <= 7'h2;
    #20; //Time req 2 would come if it was not removed
    assert(req_arb.data_rs1 == {32'hDEADBEEF, 32'h3} && req_arb.rd == 7'h3);
    //Check flush!
    flush <= 1'b1;
    #10;
    //Now queue should be empty!
    assert(req_arb.valid == 1'b0);
    arbiter_req_ready <= 1'b0;

    //Basic cases should be covered. Expect edge cases!
end

//Clock Driver
assign #5 clk = ~clk;

endmodule