/*
 *  Authors       : Xavier Salva, Pol Marcet
 *  Creation Date : April, 2024
 *  Description   : Next line prefetcher for the Sargantana processor
 *  History       :
 */

import drac_pkg::addr_t;

module hwpf_stack_tb
(
);
    logic clk;
    logic rst;

    logic flush;
    logic lock;

    logic stack_push_i;
    addr_t stack_val_i;
    logic stack_pop_i;
    logic stack_valid_o;
    addr_t stack_req_o;

    // local variables
    addr_t stack_expected_req;


    hwpf_stack #(
    .STACK_DEPTH(2), // Number of positions in queue
    .cpu_addr_t(addr_t) // Type of the structure to be used
    ) stack (
        .clk_i(clk),
        .rst_ni(rst),

        .flush_i(flush),
        .lock_i(lock),

        // CPU push gate
        .push_i(stack_push_i),
        .val_i(stack_val_i),
        // CPU pop gate
        .pop_i(stack_pop_i),

        // Request emission
        .valid_o(stack_valid_o),
        .req_o(stack_req_o)
    );

initial begin
    $dumpfile("./wave_hwpf_stack_tb.vcd");
    $dumpvars;

    rst <= 1'b0;
    clk <= 1'b0;
    flush <= 1'b0;
    lock <= 1'b0;
    stack_push_i <= 1'b0;
    stack_val_i <= 0;
    stack_pop_i <= 1'b0;
    #20;
    rst <= ~rst;
    #20;
    $display("Starting test");
    CheckInitState: assert (stack_valid_o == 1'b0);
      else $error("Assertion CheckInitState failed!");

    // Prepare insertion
    $display("Check insertion");
    stack_push_i <= 1'b1;
    stack_val_i <= 40'hCAFE0001;
    stack_expected_req <= stack_val_i;
    #10;
    stack_push_i <= 1'b0;
    // Check insertion
    CheckInsertionValid: assert (stack_valid_o == 1'b1);
      else $error("Assertion CheckInsertionValid failed!");
    CheckInsertionValue: assert (stack_req_o == stack_expected_req);
      else $error("Assertion CheckInsertionValue failed!");

    // Prepare extraction
    $display("Check extraction");
    stack_pop_i <= 1'b1;
    #10;
    // Check extraction
    stack_pop_i <= 1'b0;
    CheckExtractionValid: assert (stack_valid_o == 1'b0);
      else $error("Assertion CheckExtractionValid failed!");

    // Prepare insertion for simultaneous push and pop
    $display("Check simultaneous push and pop");
    stack_push_i <= 1'b1;
    stack_val_i <= 40'hCAFE0002;
    stack_expected_req <= stack_val_i;
    #10;
    // Check insertion
    CheckSimultaneousPushPopPrevValid: assert (stack_valid_o == 1'b1);
      else $error("Assertion CheckSimultaneousPushPopPrevValid failed!");
    CheckSimultaneousPushPopPrevValue: assert (stack_req_o == stack_expected_req);
      else $error("Assertion CheckSimultaneousPushPopPrevValue failed!");

    // Do push and pop simultaneously
    stack_push_i <= 1'b1;
    stack_pop_i <= 1'b1;
    stack_val_i <= 40'hCAFE0003;
    stack_expected_req <= stack_val_i;
    #10;
    // Check insertion
    CheckSimultaneousPushPopValid: assert (stack_valid_o == 1'b1);
      else $error("Assertion CheckSimultaneousPushPopValid failed!");
    CheckSimultaneousPushPopValue: assert (stack_req_o == stack_expected_req);
      else $error("Assertion CheckSimultaneousPushPopValue failed!");
    // Do final pop to check the queue is empty
    stack_push_i <= 1'b0;
    stack_pop_i <= 1'b1;
    #10;
    // Check extraction
    stack_pop_i <= 1'b0;
    CheckFinalExtractionValid: assert (stack_valid_o == 1'b0);
      else $error("Assertion CheckFinalExtractionValid failed!");

    // Check overflow
    $display("Check overflow");
    stack_push_i <= 1'b1;
    stack_val_i <= 40'hCAFE0004;
    stack_expected_req <= stack_val_i;
    #10;
    CheckOverflowValid1: assert (stack_valid_o == 1'b1);
      else $error("Assertion CheckOverflowValid1 failed!");
    CheckOverflowValue1: assert (stack_req_o == stack_expected_req);
      else $error("Assertion CheckOverflowValue1 failed! %h expected %h", stack_req_o, stack_expected_req);
    stack_val_i <= 40'hCAFE0005;
    stack_expected_req <= stack_val_i;
    #10;
    CheckOverflowValid2: assert (stack_valid_o == 1'b1);
      else $error("Assertion CheckOverflowValid2 failed!");
    CheckOverflowValue2: assert (stack_req_o == stack_expected_req);
      else $error("Assertion CheckOverflowValue2 failed! %h expected %h", stack_req_o, stack_expected_req);
    stack_val_i <= 40'hCAFE0006;
    stack_expected_req <= stack_val_i;
    #10;
    CheckOverflowValid3: assert (stack_valid_o == 1'b1);
      else $error("Assertion CheckOverflowValid3 failed!");
    CheckOverflowValue3: assert (stack_req_o == stack_expected_req);
      else $error("Assertion CheckOverflowValue3 failed! %h expected %h", stack_req_o, stack_expected_req);

    stack_pop_i <= 1'b1;
    stack_val_i <= 40'hCAFE0007;
    stack_expected_req <= stack_val_i;
    #10;
    CheckOverflowValid4: assert (stack_valid_o == 1'b1);
      else $error("Assertion CheckOverflowValid4 failed!");
    CheckOverflowValue4: assert (stack_req_o == stack_expected_req);
      else $error("Assertion CheckOverflowValue4 failed! %h expected %h", stack_req_o, stack_expected_req);
    stack_push_i <= 1'b0;
    stack_expected_req <= 40'hCAFE0005;
    #10;
    CheckOverflowValid5: assert (stack_valid_o == 1'b1);
      else $error("Assertion CheckOverflowValid5 failed!");
    CheckOverflowValue5: assert (stack_req_o == stack_expected_req);
      else $error("Assertion CheckOverflowValue5 failed! %h expected %h", stack_req_o, stack_expected_req);
    #10;
    CheckOverflowValid6: assert (stack_valid_o == 1'b0);
      else $error("Assertion CheckOverflowValid6 failed!");

    // Check underflow
    $display("Check underflow");
    stack_pop_i <= 1'b1;
    #10;
    CheckUnderflowValid1: assert (stack_valid_o == 1'b0);
      else $error("Assertion CheckUnderflowValid1 failed!");

    // Check underflow with push
    $display("Check underflow with push");
    stack_push_i <= 1'b1;
    stack_pop_i <= 1'b1;
    stack_val_i <= 40'hCAFE0008;
    stack_expected_req <= stack_val_i;
    #10;
    CheckUnderflowValid2: assert (stack_valid_o == 1'b1);
      else $error("Assertion CheckUnderflowValid2 failed!");
    CheckUnderflowValue2: assert (stack_req_o == stack_expected_req);
      else $error("Assertion CheckUnderflowValue2 failed! %h expected %h", stack_req_o, stack_expected_req);
    stack_push_i <= 1'b0;
    stack_pop_i <= 1'b1;
    #10;
    CheckUnderflowValid3: assert (stack_valid_o == 1'b0);
      else $error("Assertion CheckUnderflowValid3 failed!");
    stack_pop_i <= 1'b0;
    #10;
    CheckUnderflowValid4: assert (stack_valid_o == 1'b0);
      else $error("Assertion CheckUnderflowValid4 failed!");

    $display("Check flush");
    stack_push_i <= 1'b1;
    stack_val_i <= 40'hCAFE0009;
    stack_expected_req <= stack_val_i;
    #10;
    CheckFlushValid1: assert (stack_valid_o == 1'b1);
      else $error("Assertion CheckFlushValid1 failed!");
    CheckFlushValue1: assert (stack_req_o == stack_expected_req);
      else $error("Assertion CheckFlushValue1 failed! %h expected %h", stack_req_o, stack_expected_req);
    flush <= 1'b1;
    #10;
    CheckFlushValid2: assert (stack_valid_o == 1'b0);
      else $error("Assertion CheckFlushValid2 failed!");
    flush <= 1'b0;

    $finish;
end

assign #5 clk = ~clk;

endmodule
