
import drac_pkg::*;
import hpdcache_pkg::*;

module hwpf_fifo_tb (
);
    int i;
    localparam INSERTS = 2;
    logic clk;
    logic rst;

    logic flush;
    logic lock;

    req_cpu_dcache_t cpu_req;
    req_cpu_dcache_t cpu_req2;
    logic arbiter_req_ready;

    logic req_valid [INSERTS-1:0];
    req_cpu_dcache_t cpu_reqs [INSERTS-1:0];

    logic req_valid;
    req_cpu_dcache_t req_arb;

    logic req_hits [INSERTS-1:0];

    assign req_valid[0] = cpu_req.valid;
    assign req_valid[1] = cpu_req2.valid;

    assign cpu_reqs[0] = cpu_req;
    assign cpu_reqs[1] = cpu_req2;

   hwpf_fifo fifo
   (
    .clk_i(clk),
    .rst_ni(rst),

    .flush_i(flush),
    .lock_i(lock),

    // CPU request issued
    .take_req_i(cpu_req.valid),
    .cpu_req_i(cpu_req),

    // Read oldest element
    .read_i(arbiter_req_ready),

    // Requests emitted by the prefetcher
    .arbiter_req_valid_o(req_valid),
    .arbiter_req_o(req_arb),

    .req_hits_o(req_hits)
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
    cpu_req2 <= '0;
    arbiter_req_ready <= 1'b0;

    #20;
    rst <= ~rst;

    #30;
    lock <= 1'b1; //Disable Queue lock
    //Req Data when empty
    arbiter_req_ready <= 1'b1;
    CheckInitState: assert(req_arb == '0);
    else $error("Assertion CheckInitStateV failed!");
    CheckInitState: assert(req_valid == '0);
    else $error("Assertion CheckInitStateD failed!");

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
    CheckAssign: assert(req_valid == 1'b1);
    else $error("Assertion CheckAssign1V failed!");
    CheckAssign: assert(req_arb.data_rs1 == 64'hCAFECAFE && req_arb.rd == 7'h1);
    else $error("Assertion CheckAssign1D failed!");

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
    else $error("Assertion CheckAssign2V failed!");
    assert(req_arb.data_rs1 == 64'h1BEEF && req_arb.rd == 7'h2);
    else $error("Assertion CheckAssign2D failed!");

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
        else $error("Assertion CheckAssign3V failed!");
        assert(req_arb.data_rs1 == {32'hDEADBEEF, i[31:0]} && req_arb.rd == i);
        else $error("Assertion CheckAssign3D failed!");
        #10;
    end
    //Now queue is empty!

    //check overflow is lost
    arbiter_req_ready <= 1'b0;
    assert(req_valid == 1'b0);
        else $error("Assertion CheckEmptyV failed!");
    assert(req_arb <= '0);
        else $error("Assertion CheckEmptyD failed!");
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
    //Check flush!
    flush <= 1'b1;
    #10;
    //Now queue should be empty!
    assert(req_arb.valid == 1'b0);
        else $error("Assertion CheckEmptyV failed!");


    //Check double assign and order
    #10;
    arbiter_req_ready <= 1'b1;
    cpu_req.valid <= 1'b1;
    cpu_req.rd <= 6'h10;
    cpu_req.data <= 64'hC01ACA0;

    cpu_req2.valid <= 1'b1;
    cpu_req2.rd <= 6'h12;
    cpu_req2.data <= 64'h31337;

    #10;
    cpu_req <= '0;
    cpu_req2 <= '0;
    assert(req_arb.valid == 1'b1);
        else $error("Assertion CheckDoubleAssign1V failed!");
    assert(req_arb.data = 64'hC01ACA0);
        else $error("Assertion CheckDoubleAssign1D failed!");
    #10;
    assert(req_arb.valid == 1'b1);
        else $error("Assertion CheckDoubleAssign2V failed!");
    assert(req_arb.data = 64'h31337);
        else $error("Assertion CheckDoubleAssign2D failed!");
    arbiter_req_ready <= 1'b0;
    #30;

    //check assign reordering
    cpu_req.valid <= 1'b1;
    cpu_req.rd <= 6'h8;
    cpu_req.data <= 64'hBEEFA;

    cpu_req2.valid <= 1'b1;
    cpu_req2.rd <= 6'h9;
    cpu_req2.data <= 64'hDEADCAFE;

    #10;

    cpu_req.valid <= 1'b1;
    cpu_req.rd <= 6'h8;
    cpu_req.data <= 64'hDEADDEAD;
    arbiter_req_ready <= 1'b1;
    #10;
    assert(req_arb.valid == 1'b1);
        else $error("Assertion CheckReorder1V failed!");
    assert(req_arb.data = 64'hDEADCAFE);
        else $error("Assertion CheckReorder1D failed!");
    #10;
    assert(req_arb.valid == 1'b1);
        else $error("Assertion CheckReorder2V failed!");
    assert(req_arb.data = 64'hDEADDEAD);
        else $error("Assertion CheckReorder2D failed!");

    //Basic cases should be covered. Expect edge cases!
    $finish;
end

//Clock Driver
assign #5 clk = ~clk;

endmodule