/*
 *  Authors       : Xavier Salva, Pol Marcet
 *  Creation Date : April, 2024
 *  Description   : Next line prefetcher for the Sargantana processor
 *  History       :
 */

import drac_pkg::*;
import hpdcache_pkg::*;

module hwpf_nl_tb
(
);
    logic clk;
    logic rst;

    logic flush;
    logic lock;

    req_cpu_dcache_t               nl_cpu_req_i;
    logic                          nl_arbiter_req_ready_i;
    logic                          nl_arbiter_req_valid_o;
    hpdcache_req_t                 nl_arbiter_req_o;

    // local variables
    hpdcache_req_t expected_req;
    logic expected_valid;


    hwpf_nl nl (
        .clk_i(clk),
        .rst_ni(rst),

        .flush_i(flush),
        .lock_i(lock),

        // CPU request issued
        .cpu_req_i(nl_cpu_req_i),

        // Requests emitted by the prefetcher
        .arbiter_req_valid_o(nl_arbiter_req_valid_o),
        .arbiter_req_ready_i(nl_arbiter_req_ready_i),
        .arbiter_req_o(nl_arbiter_req_o)
    );

initial begin
    $dumpfile("./wave_hwpf_nl_tb.vcd");
    $dumpvars;

    rst <= 1'b0;
    clk <= 1'b0;
    flush <= 1'b0;
    lock <= 1'b0;
    nl_cpu_req_i <= 1'b0;
    nl_arbiter_req_ready_i <= 0;
    #20;
    rst <= ~rst;
    #20;
    $display("Starting test");
    CheckInitState: assert (nl_arbiter_req_valid_o == 1'b0);
      else $error("Assertion CheckInitState failed!");

    // Prepare insertion
    $display("Check insertion first encounter");
    nl_cpu_req_i.valid <= 1'b1;
    nl_cpu_req_i.io_base_addr <= 40'hCAFE0000;
    nl_cpu_req_i.rd <= 1;

    #10;
    nl_cpu_req_i.valid <= 1'b0;

    // Check nothing comes out
    CheckInsertionFEValid1: assert (nl_arbiter_req_valid_o == 1'b0);
      else $error("Assertion CheckInsertionFEValid1 failed!");

    $display("Check insertion first encounter, arbiter gives way");
    nl_arbiter_req_ready_i <= 1'b1;
    #10;
    nl_arbiter_req_ready_i <= 1'b0;

    // Check nothing comes out
    CheckInsertionFEValid2: assert (nl_arbiter_req_valid_o == 1'b0);
      else $error("Assertion CheckInsertionFEValid2 failed!");

    $display("Check insertion same rd");
    nl_cpu_req_i.valid <= 1'b1;
    nl_cpu_req_i.io_base_addr <= 40'hCAFE0000;
    nl_cpu_req_i.rd <= 1;
    #10
    nl_cpu_req_i.valid <= 1'b0;

    // Check nothing comes out
    CheckInsertionSameRDValid1: assert (nl_arbiter_req_valid_o == 1'b0);
      else $error("Assertion CheckInsertionSameRDValid1 failed!");

    $display("Check insertion same rd, arbiter gives way");
    nl_arbiter_req_ready_i <= 1'b1;
    #10;
    nl_arbiter_req_ready_i <= 1'b0;

    // Check nothing comes out
    CheckInsertionSameRDValid2: assert (nl_arbiter_req_valid_o == 1'b0);
      else $error("Assertion CheckInsertionSameRDValid2 failed!");

    $display("Check insertion second encounter different rd");
    nl_cpu_req_i.valid <= 1'b1;
    nl_cpu_req_i.io_base_addr <= 40'hCAFE0000;
    nl_cpu_req_i.rd <= 2;
    #10;
    nl_cpu_req_i.valid <= 1'b0;

    // Check that the request comes out
    CheckInsertionSEValid1: assert (nl_arbiter_req_valid_o == 1'b1);
      else $error("Assertion CheckInsertionSEValid1 failed!");
    CheckInsertionSEValue1: assert (nl_arbiter_req_o.addr == 40'hCAFE0040);
      else $error("Assertion CheckInsertionSEValue1 failed!");

    #10;
    $display("Check that request is sent once when arbiter gives way");
    CheckInsertionSEValid2: assert (nl_arbiter_req_valid_o == 1'b1);
      else $error("Assertion CheckInsertionSEValid2 failed!");
    CheckInsertionSEValue2: assert (nl_arbiter_req_o.addr == 40'hCAFE0040);
      else $error("Assertion CheckInsertionSEValue2 failed!");
    #10;
    CheckInsterionSEValid3: assert (nl_arbiter_req_valid_o == 1'b1);
      else $error("Assertion CheckInsterionSEValid3 failed!");
    CheckInsterionSEValue3: assert (nl_arbiter_req_o.addr == 40'hCAFE0040);
      else $error("Assertion CheckInsterionSEValue3 failed!");
    nl_arbiter_req_ready_i <= 1'b1;
    #10;
    nl_arbiter_req_ready_i <= 1'b0;
    // Hold for one cycle!
    CheckInsterionSEValid4: assert (nl_arbiter_req_valid_o == 1'b1);
      else $error("Assertion CheckInsterionSEValid4 failed!");
    CheckInsterionSEValue4: assert (nl_arbiter_req_o.addr == 40'hCAFE0040);
      else $error("Assertion CheckInsterionSEValue4 failed!");
    #10;
    CheckInsterionSEValid5: assert (nl_arbiter_req_valid_o == 1'b0);
      else $error("Assertion CheckInsterionSEValid5 failed!");

    $display("Check insertion third encounter different rd");
    nl_cpu_req_i.valid <= 1'b1;
    nl_cpu_req_i.io_base_addr <= 40'hCAFE0000;
    nl_cpu_req_i.rd <= 3;
    #10;
    nl_cpu_req_i.valid <= 1'b0;

    // Check that the request doesn't come out; it's already issued!
    CheckInsertionTEValid1: assert (nl_arbiter_req_valid_o == 1'b0);
      else $error("Assertion CheckInsertionTEValid1 failed!");

    $display("Check insertion next line first encounter different rd");
    nl_cpu_req_i.valid <= 1'b1;
    nl_cpu_req_i.io_base_addr <= 40'hCAFE0040;
    nl_cpu_req_i.rd <= 4;
    #10;
    nl_cpu_req_i.valid <= 1'b0;

    // Check that the request comes out
    CheckInsertionNLFEValid1: assert (nl_arbiter_req_valid_o == 1'b1);
      else $error("Assertion CheckInsertionNLFEValid1 failed!");
    CheckInsertionNLFEValue1: assert (nl_arbiter_req_o.addr == 40'hCAFE0080);
      else $error("Assertion CheckInsertionNLFEValue1 failed!");
    // Let's hold for a cycle
    nl_arbiter_req_ready_i <= 1'b1;
    #10;
    nl_arbiter_req_ready_i <= 1'b0;
    // Check that the request comes out
    CheckInsertionNLFEValid2: assert (nl_arbiter_req_valid_o == 1'b1);
      else $error("Assertion CheckInsertionNLFEValid2 failed!");
    CheckInsertionNLFEValue2: assert (nl_arbiter_req_o.addr == 40'hCAFE0080);
      else $error("Assertion CheckInsertionNLFEValue2 failed!");
    #10;
    CheckInsertionNLFEValid3: assert (nl_arbiter_req_valid_o == 1'b0);
      else $error("Assertion CheckInsertionNLFEValid3 failed!");

    $display("Check insertion next line second encounter different rd");
    nl_cpu_req_i.valid <= 1'b1;
    nl_cpu_req_i.io_base_addr <= 40'hCAFE0040;
    nl_cpu_req_i.rd <= 5;
    #10;
    nl_cpu_req_i.valid <= 1'b0;

    // Check that the request doesn't come out; it's already issued!
    CheckInsertionNLSEValid1: assert (nl_arbiter_req_valid_o == 1'b0);
      else $error("Assertion CheckInsertionNLSEValid1 failed!");

    $display("Check insertion next line first encounter different rd arbiter ready");

    nl_arbiter_req_ready_i <= 1'b1;
    nl_cpu_req_i.valid <= 1'b1;
    nl_cpu_req_i.io_base_addr <= 40'hCAFE0040;
    nl_cpu_req_i.rd <= 6;
    #10;
    nl_cpu_req_i.valid <= 1'b0;
    nl_arbiter_req_ready_i <= 1'b0;

    // Check that the request comes out
    CheckInsertionNLFEDirectValid1: assert (nl_arbiter_req_valid_o == 1'b1);
      else $error("Assertion CheckInsertionNLFEDirectValid1 failed!");
    CheckInsertionNLFEDirectValue1: assert (nl_arbiter_req_o.addr == 40'hCAFE00C0);
      else $error("Assertion CheckInsertionNLFEDirectValue1 failed!");
    #10;
    CheckInsertionNLFEDirectValid2: assert (nl_arbiter_req_valid_o == 1'b0);
      else $error("Assertion CheckInsertionNLFEDirectValid2 failed!");

    $finish;
end

assign #5 clk = ~clk;

endmodule
