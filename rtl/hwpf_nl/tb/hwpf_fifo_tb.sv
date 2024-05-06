
import drac_pkg::addr_t;

module hwpf_fifo_tb (
);
    int i;
    localparam INSERTS = 2;
    localparam QUEUE_DEPTH = 3;
    logic clk;
    logic rst;

    logic flush;
    logic lock;

    logic fifo_take_req_i [INSERTS-1:0];
    addr_t fifo_cpu_req_i [INSERTS-1:0];

    addr_t                      fifo_data_cpu_o    [QUEUE_DEPTH-1:0];
    logic                       fifo_data_valid_o    [QUEUE_DEPTH-1:0];

    function automatic logic findDataImpl;
    input addr_t                      data_cpu    [QUEUE_DEPTH-1:0];
    input logic                       data_valid  [QUEUE_DEPTH-1:0];
    input addr_t                      cpu_req_i;
    begin
        for (int j = 0; j < QUEUE_DEPTH; j = j+1) begin
        if (data_valid[j] && cpu_req_i == data_cpu[j]) begin
            return '1;
        end
        end
    end
    return '0;
    endfunction

    `define findData(x) findDataImpl(fifo_data_cpu_o, fifo_data_valid_o, x)

   hwpf_fifo #(
    .QUEUE_DEPTH(QUEUE_DEPTH),
    .INSERTS(INSERTS)
   ) fifo
   (
    .clk_i(clk),
    .rst_ni(rst),

    .flush_i(flush),
    .lock_i(lock),

    // CPU request issued
    .take_req_i(fifo_take_req_i),
    .cpu_req_i(fifo_cpu_req_i),
    .data_cpu_o(fifo_data_cpu_o),
    .data_valid_o(fifo_data_valid_o)
);

//Main tb signal driver
initial begin
    $dumpfile("./wave_hwpf_fifo_tb.vcd");
    $dumpvars;
    //General control Signals
    rst = 1'b0;
    clk = 1'b0;
    flush = 1'b0;
    lock = 1'b0;

    //Module-specific control signals
    fifo_take_req_i[0] = '0;
    fifo_cpu_req_i[0] = '0;
    fifo_take_req_i[1] = '0;
    fifo_cpu_req_i[1] = '0;

    #20;
    rst = ~rst;
    #20;
    $display("Starting test");
    CheckInitState: assert (!`findData(fifo_cpu_req_i[0]) && !`findData(fifo_cpu_req_i[1]));
      else $error("Assertion CheckInitState failed!");

    $display("Check lock");
    lock = 1'b1;
    fifo_cpu_req_i[0] = 40'hCAFE0000;
    fifo_take_req_i[0] = 1'b1;
    CheckLock1: assert (`findData(fifo_cpu_req_i[0])== 0);
      else $error("Assertion CheckLock1 failed!");
    #10;
    CheckLock2: assert (`findData(fifo_cpu_req_i[0]) == 0);
      else $error("Assertion CheckLock2 failed!");

    $display("Check simple insertion");
    lock = 1'b0;
    fifo_cpu_req_i[0] = 40'hCAFE0000;
    fifo_take_req_i[0] = 1'b1;
    SimpleInsertion1: assert (`findData(fifo_cpu_req_i[0]) == 0);
    else $error("Assertion SimpleInsertion1 failed!");
    #10
    SimpleInsertion2: assert (`findData(fifo_cpu_req_i[0]) == 1);
    else $error("Assertion SimpleInsertion2 failed!");
    fifo_take_req_i[0] = 1'b0;
    #10

    $display("Check flush");
    flush = 1'b1;
    #10
    CheckFlush1: assert (`findData(fifo_cpu_req_i[0]) == 0);
    else $error("Assertion CheckFlush1 failed!");
    fifo_take_req_i[0] = 1'b1;
    fifo_cpu_req_i[0] = 40'hCAFE0000;
    #10
    CheckFlush2: assert (`findData(fifo_cpu_req_i[0]) == 0);
    else $error("Assertion CheckFlush2 failed!");
    fifo_take_req_i[0] = 1'b0;
    flush = 1'b0;

    $display("Check multiple insertions");
    fifo_cpu_req_i[0] = 40'hCAFE0000;
    fifo_take_req_i[0] = 1'b1;
    fifo_cpu_req_i[1] = 40'hCAFE0001;
    fifo_take_req_i[1] = 1'b1;
    #10
    MultipleInsertions1: assert (`findData(fifo_cpu_req_i[0]) == 1);
    else $error("Assertion MultipleInsertions1 failed!");
    MultipleInsertions2: assert (`findData(fifo_cpu_req_i[1]) == 1);
    else $error("Assertion MultipleInsertions2 failed!");
    fifo_cpu_req_i[0] = 40'hCAFE0002;
    fifo_take_req_i[0] = 1'b1;
    fifo_take_req_i[1] = 1'b0;
    #10
    MultipleInsertions3: assert (`findData(fifo_cpu_req_i[0]) == 1);
    else $error("Assertion MultipleInsertions3 failed!");
    MultipleInsertions4: assert (`findData(40'hCAFE0000) == 1);
    else $error("Assertion MultipleInsertions4 failed!");
    MultipleInsertions5: assert (`findData(40'hCAFE0001) == 1);
    else $error("Assertion MultipleInsertions5 failed!");
    $display("Check inserting already exisiting data");
    fifo_cpu_req_i[0] = 40'hCAFE0000;
    fifo_take_req_i[0] = 1'b1;
    fifo_cpu_req_i[1] = 40'hCAFE0001;
    fifo_take_req_i[1] = 1'b1;
    #10
    MultipleInsertions6: assert (`findData(fifo_cpu_req_i[0]) == 1);
    else $error("Assertion MultipleInsertions6 failed!");
    MultipleInsertions7: assert (`findData(fifo_cpu_req_i[1]) == 1);
    else $error("Assertion MultipleInsertions7 failed!");
    MultipleInsertions8: assert (`findData(40'hCAFE0002) == 1);
    else $error("Assertion MultipleInsertions8 failed!");

    //Basic cases should be covered.
    $finish;
end

//Clock Driver
assign #5 clk = ~clk;

endmodule
