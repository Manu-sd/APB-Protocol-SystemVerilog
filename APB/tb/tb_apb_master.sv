//============================================================
// APB4 TESTBENCH
//
// Exercises:
//     1. Full-word writes / read-back
//     2. Sparse (byte-lane) writes using PSTRB
//     3. PPROT privilege checking on CONFIG_REG
//     4. Write to read-only STATUS_REG -> PSLVERR
//     5. Unmapped address -> PSLVERR
//     6. Back-to-back transactions
//============================================================

`timescale 1ns/1ps

module tb_apb_master;

    localparam int ADDR_WIDTH = 32;
    localparam int DATA_WIDTH = 32;
    localparam int STRB_WIDTH = DATA_WIDTH / 8;

    //========================================================
    // PPROT CONVENIENCE ENCODINGS
    //     [0] 0 = normal      1 = privileged
    //     [1] 0 = secure      1 = non-secure
    //     [2] 0 = data        1 = instruction
    //========================================================

    localparam logic [2:0] PROT_NORMAL = 3'b000;
    localparam logic [2:0] PROT_PRIV   = 3'b001;

    //========================================================
    // CLOCK & RESET
    //========================================================

    logic PCLK;
    logic PRESETn;

    //========================================================
    // MASTER REQUEST INTERFACE
    //========================================================

    logic                  req;
    logic                  write;
    logic [ADDR_WIDTH-1:0] addr;
    logic [DATA_WIDTH-1:0] wdata;
    logic [STRB_WIDTH-1:0] strb;
    logic [2:0]            prot;

    logic [DATA_WIDTH-1:0] rdata;
    logic                  done;
    logic                  error;

    //========================================================
    // APB BUS
    //========================================================

    logic [ADDR_WIDTH-1:0] PADDR;
    logic                  PSEL;
    logic                  PENABLE;
    logic                  PWRITE;
    logic [DATA_WIDTH-1:0] PWDATA;
    logic [STRB_WIDTH-1:0] PSTRB;
    logic [2:0]            PPROT;

    logic [DATA_WIDTH-1:0] PRDATA;
    logic                  PREADY;
    logic                  PSLVERR;

    //========================================================
    // SCOREBOARD
    //========================================================

    int   pass_count;
    int   fail_count;

    // error is combinational and only valid during the
    // completing ACCESS cycle, so tasks latch it here.
    logic last_error;

    //========================================================
    // DUT - MASTER
    //========================================================

    apb_master #(
        .ADDR_WIDTH (ADDR_WIDTH),
        .DATA_WIDTH (DATA_WIDTH)
    ) master (

        .PCLK    (PCLK),
        .PRESETn (PRESETn),

        .req     (req),
        .write   (write),
        .addr    (addr),
        .wdata   (wdata),
        .strb    (strb),
        .prot    (prot),

        .rdata   (rdata),
        .done    (done),
        .error   (error),

        .PADDR   (PADDR),
        .PSEL    (PSEL),
        .PENABLE (PENABLE),
        .PWRITE  (PWRITE),
        .PWDATA  (PWDATA),
        .PSTRB   (PSTRB),
        .PPROT   (PPROT),

        .PRDATA  (PRDATA),
        .PREADY  (PREADY),
        .PSLVERR (PSLVERR)

    );

    //========================================================
    // DUT - SLAVE
    //========================================================

    apb_slave #(
        .ADDR_WIDTH  (ADDR_WIDTH),
        .DATA_WIDTH  (DATA_WIDTH),
        .WAIT_STATES (2)
    ) slave (

        .PCLK    (PCLK),
        .PRESETn (PRESETn),

        .PADDR   (PADDR),
        .PSEL    (PSEL),
        .PENABLE (PENABLE),
        .PWRITE  (PWRITE),
        .PWDATA  (PWDATA),
        .PSTRB   (PSTRB),
        .PPROT   (PPROT),

        .PRDATA  (PRDATA),
        .PREADY  (PREADY),
        .PSLVERR (PSLVERR)

    );

    //========================================================
    // CLOCK
    //========================================================

    always #5 PCLK = ~PCLK;

    //========================================================
    // CHECK HELPER
    //========================================================

    task automatic check (
        input string             name,
        input logic [DATA_WIDTH-1:0] got,
        input logic [DATA_WIDTH-1:0] exp
    );

        begin

            if (got === exp) begin

                pass_count++;
                $display("  [PASS] %-34s got=%h", name, got);

            end

            else begin

                fail_count++;
                $display("  [FAIL] %-34s got=%h exp=%h", name, got, exp);

            end

        end

    endtask

    task automatic check_bit (
        input string name,
        input logic  got,
        input logic  exp
    );

        begin

            if (got === exp) begin

                pass_count++;
                $display("  [PASS] %-34s got=%b", name, got);

            end

            else begin

                fail_count++;
                $display("  [FAIL] %-34s got=%b exp=%b", name, got, exp);

            end

        end

    endtask

    //========================================================
    // WRITE TASK
    //========================================================

    task automatic apb_write (
        input logic [ADDR_WIDTH-1:0] address,
        input logic [DATA_WIDTH-1:0] data,
        input logic [STRB_WIDTH-1:0] strobe = {STRB_WIDTH{1'b1}},
        input logic [2:0]            protection = PROT_NORMAL
    );

        begin

            wait (done == 1'b0);

            @(negedge PCLK);

            req   = 1'b1;
            write = 1'b1;
            addr  = address;
            wdata = data;
            strb  = strobe;
            prot  = protection;

            //============================================
            // done is combinational and rises during the
            // final ACCESS cycle. Drop req immediately so
            // the master does not latch an unintended
            // back-to-back transfer on the completing edge.
            //============================================

            wait (done == 1'b1);

            // settle combinational PSLVERR/error before sampling
            #1;

            last_error = error;
            req        = 1'b0;

            @(posedge PCLK);   // transfer completes here

            @(negedge PCLK);

            write = 1'b0;
            strb  = '0;

        end

    endtask

    //========================================================
    // READ TASK
    //========================================================

    task automatic apb_read (
        input  logic [ADDR_WIDTH-1:0] address,
        input  logic [2:0]            protection = PROT_NORMAL
    );

        begin

            wait (done == 1'b0);

            @(negedge PCLK);

            req   = 1'b1;
            write = 1'b0;
            addr  = address;
            wdata = '0;
            strb  = '0;
            prot  = protection;

            wait (done == 1'b1);

            // settle combinational PSLVERR/error before sampling
            #1;

            last_error = error;
            req        = 1'b0;

            @(posedge PCLK);   // transfer completes, rdata captured

            @(negedge PCLK);   // rdata now stable

        end

    endtask

    //========================================================
    // PSTRB PROTOCOL ASSERTION
    //
    // APB4: PSTRB must be LOW during read transfers.
    //========================================================

`ifdef ENABLE_SVA
    property p_pstrb_low_on_read;
        @(posedge PCLK) disable iff (!PRESETn)
        (PSEL && !PWRITE) |-> (PSTRB == '0);
    endproperty

    assert property (p_pstrb_low_on_read)
        else $error("PSTRB asserted during a read transfer");

    //========================================================
    // PADDR STABILITY ASSERTION
    //
    // APB: address and control must remain stable from
    // SETUP through the end of ACCESS.
    //========================================================

    property p_addr_stable;
        @(posedge PCLK) disable iff (!PRESETn)
        (PSEL && PENABLE && !PREADY) |=> $stable(PADDR);
    endproperty

    assert property (p_addr_stable)
        else $error("PADDR changed during a wait state");
`endif

    //========================================================
    // MAIN TEST
    //========================================================

    initial begin

        PCLK    = 1'b0;
        PRESETn = 1'b0;

        req   = 1'b0;
        write = 1'b0;
        addr  = '0;
        wdata = '0;
        strb  = '0;
        prot  = PROT_NORMAL;

        pass_count = 0;
        fail_count = 0;
        last_error = 1'b0;

        #20;

        PRESETn = 1'b1;

        $display("");
        $display("==========================================");
        $display("            APB4 TEST START");
        $display("==========================================");

        //====================================================
        // TEST 1 - FULL WORD WRITE / READ
        //====================================================

        $display("");
        $display("TEST 1 : full-word write and read-back");

        apb_write(32'h0000, 32'hAAAA_AAAA);
        apb_read (32'h0000);
        check("CTRL_REG full write", rdata, 32'hAAAA_AAAA);

        apb_write(32'h0008, 32'hBBBB_BBBB);
        apb_read (32'h0008);
        check("DATA_REG full write", rdata, 32'hBBBB_BBBB);

        //====================================================
        // TEST 2 - SPARSE WRITES (PSTRB)
        //====================================================

        $display("");
        $display("TEST 2 : sparse byte-lane writes via PSTRB");

        // Only byte 0 enabled -> AAAAAA11
        apb_write(32'h0000, 32'h1111_1111, 4'b0001);
        apb_read (32'h0000);
        check("PSTRB=0001 byte0 only", rdata, 32'hAAAA_AA11);

        // Only byte 3 enabled -> 22AAAA11
        apb_write(32'h0000, 32'h2222_2222, 4'b1000);
        apb_read (32'h0000);
        check("PSTRB=1000 byte3 only", rdata, 32'h22AA_AA11);

        // Upper halfword -> 3333AA11
        apb_write(32'h0000, 32'h3333_3333, 4'b1100);
        apb_read (32'h0000);
        check("PSTRB=1100 upper halfword", rdata, 32'h3333_AA11);

        // No strobes -> register unchanged
        apb_write(32'h0000, 32'hFFFF_FFFF, 4'b0000);
        apb_read (32'h0000);
        check("PSTRB=0000 no update", rdata, 32'h3333_AA11);

        //====================================================
        // TEST 3 - PPROT PRIVILEGE CHECK
        //====================================================

        $display("");
        $display("TEST 3 : PPROT privilege checking on CONFIG_REG");

        // Normal-level write to privileged register -> error
        apb_write(32'h000C, 32'hCCCC_CCCC, 4'b1111, PROT_NORMAL);
        check_bit("normal write to CONFIG -> error", last_error, 1'b1);

        // Privileged write -> accepted
        apb_write(32'h000C, 32'hCCCC_CCCC, 4'b1111, PROT_PRIV);
        check_bit("privileged write to CONFIG -> ok", last_error, 1'b0);

        apb_read (32'h000C, PROT_PRIV);
        check("CONFIG_REG privileged read", rdata, 32'hCCCC_CCCC);

        //====================================================
        // TEST 4 - READ-ONLY REGISTER
        //====================================================

        $display("");
        $display("TEST 4 : write to read-only STATUS_REG");

        apb_write(32'h0004, 32'hDEAD_BEEF);
        check_bit("write STATUS_REG -> error", last_error, 1'b1);

        //====================================================
        // TEST 5 - UNMAPPED ADDRESS
        //====================================================

        $display("");
        $display("TEST 5 : unmapped address decode");

        apb_read(32'h0040);
        check_bit("read unmapped addr -> error", last_error, 1'b1);

        //====================================================
        // TEST 6 - STATUS_REG COUNTERS
        //====================================================

        $display("");
        $display("TEST 6 : STATUS_REG hardware counters");

        apb_read(32'h0004);
        $display("  STATUS_REG = %h  (writes=%0d reads=%0d err=%b)",
                 rdata, rdata[7:0], rdata[15:8], rdata[16]);
        check_bit("sticky error flag set", rdata[16], 1'b1);

        //====================================================
        // TEST 7 - BACK-TO-BACK TRANSACTIONS
        //
        // req is held high across the completing edge, so
        // the master goes ACCESS -> SETUP without returning
        // to IDLE.
        //====================================================

        $display("");
        $display("TEST 7 : back-to-back writes (no IDLE between)");

        begin
            @(negedge PCLK);
            req   = 1'b1;
            write = 1'b1;
            prot  = PROT_NORMAL;
            strb  = {STRB_WIDTH{1'b1}};

            addr  = 32'h0000;
            wdata = 32'h1234_5678;

            wait (done == 1'b1);
            #1;

            // req stays HIGH across the completing edge, and
            // the next address/data are presented now, so the
            // master latches them and goes ACCESS -> SETUP.
            addr  = 32'h0008;
            wdata = 32'h9ABC_DEF0;

            @(posedge PCLK);

            // let done fall for transfer 1 before waiting
            // on transfer 2, otherwise the level-sensitive
            // wait re-fires on the stale value
            wait (done == 1'b0);

            wait (done == 1'b1);
            #1;

            req = 1'b0;

            @(posedge PCLK);
            @(negedge PCLK);

            write = 1'b0;
            strb  = '0;
        end

        apb_read(32'h0000);
        check("b2b transfer 1 landed", rdata, 32'h1234_5678);

        apb_read(32'h0008);
        check("b2b transfer 2 landed", rdata, 32'h9ABC_DEF0);

        //====================================================
        // FINAL RESULTS
        //====================================================

        $display("");
        $display("==========================================");
        $display("            FINAL RESULTS");
        $display("==========================================");
        $display("CTRL_REG   = %h", slave.CTRL_REG);
        $display("STATUS_REG = %h", slave.STATUS_REG);
        $display("DATA_REG   = %h", slave.DATA_REG);
        $display("CONFIG_REG = %h", slave.CONFIG_REG);
        $display("------------------------------------------");
        $display("PASSED = %0d", pass_count);
        $display("FAILED = %0d", fail_count);

        if (fail_count == 0)
            $display("RESULT : ALL TESTS PASSED");
        else
            $display("RESULT : %0d FAILURE(S)", fail_count);

        $display("==========================================");

        #20;

        $finish;

    end

endmodule
