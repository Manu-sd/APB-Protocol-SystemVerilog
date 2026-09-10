module tb_apb_master;

    //========================================================
    // CLOCK & RESET
    //========================================================

    logic PCLK;
    logic PRESETn;

    //========================================================
    // MASTER INPUTS
    //========================================================

    logic        req;
    logic        write;
    logic [31:0] addr;
    logic [31:0] wdata;

    //========================================================
    // MASTER OUTPUTS
    //========================================================

    logic [31:0] rdata;
    logic        done;
    logic        error;

    //========================================================
    // APB BUS
    //========================================================

    logic [31:0] PADDR;
    logic        PSEL;
    logic        PENABLE;
    logic        PWRITE;
    logic [31:0] PWDATA;

    logic [31:0] PRDATA;
    logic        PREADY;
    logic        PSLVERR;

    //========================================================
    // APB MASTER
    //========================================================

    apb_master master (

        .PCLK    (PCLK),
        .PRESETn (PRESETn),

        .req     (req),
        .write   (write),
        .addr    (addr),
        .wdata   (wdata),

        .rdata   (rdata),
        .done    (done),
        .error   (error),

        .PADDR   (PADDR),
        .PSEL    (PSEL),
        .PENABLE (PENABLE),
        .PWRITE  (PWRITE),
        .PWDATA  (PWDATA),

        .PRDATA  (PRDATA),
        .PREADY  (PREADY),
        .PSLVERR (PSLVERR)

    );

    //========================================================
    // APB SLAVE
    //========================================================

    apb_slave slave (

        .PCLK    (PCLK),
        .PRESETn (PRESETn),

        .PADDR   (PADDR),
        .PSEL    (PSEL),
        .PENABLE (PENABLE),
        .PWRITE  (PWRITE),
        .PWDATA  (PWDATA),

        .PRDATA  (PRDATA),
        .PREADY  (PREADY),
        .PSLVERR (PSLVERR)

    );

    //========================================================
    // CLOCK
    //========================================================

    always #5 PCLK = ~PCLK;


    //========================================================
    // WRITE TASK
    //========================================================

    task automatic apb_write;

        input logic [31:0] address;
        input logic [31:0] data;

        begin

            $display("");
            $display("--------------------------------------");
            $display("START WRITE");
            $display("ADDRESS = %h", address);
            $display("DATA    = %h", data);
            $display("--------------------------------------");

            //============================================
            // Apply transaction during IDLE
            //============================================

            @(negedge PCLK);

            req   = 1'b1;
            write = 1'b1;
            addr  = address;
            wdata = data;

            //============================================
            // Wait for APB transfer completion
            //============================================

            wait(done == 1'b1);

            //============================================
            // Transfer completed
            //============================================

            $display("WRITE COMPLETE");
            $display("ERROR = %b", error);

            //============================================
            // Remove request
            //============================================

            @(negedge PCLK);

            req   = 1'b0;
            write = 1'b0;

            //============================================
            // Allow master to return to IDLE
            //============================================

            @(posedge PCLK);

            $display("RETURNED TO IDLE");

        end

    endtask


    //========================================================
    // READ TASK
    //========================================================

    task automatic apb_read;

        input logic [31:0] address;

        begin

            $display("");
            $display("--------------------------------------");
            $display("START READ");
            $display("ADDRESS = %h", address);
            $display("--------------------------------------");

            //============================================
            // Apply transaction during IDLE
            //============================================

            @(negedge PCLK);

            req   = 1'b1;
            write = 1'b0;
            addr  = address;
            wdata = 32'b0;

            //============================================
            // Wait for transfer completion
            //============================================

            wait(done == 1'b1);

            //============================================
            // Wait until next falling edge so that
            // rdata has definitely been updated
            //============================================

            @(negedge PCLK);

            $display("READ COMPLETE");
            $display("RDATA = %h", rdata);
            $display("ERROR = %b", error);

            //============================================
            // Remove request
            //============================================

            req   = 1'b0;
            write = 1'b0;

            //============================================
            // Allow master to return to IDLE
            //============================================

            @(posedge PCLK);

            $display("RETURNED TO IDLE");

        end

    endtask


    //========================================================
    // MAIN TEST
    //========================================================

    initial begin

        //====================================================
        // INITIAL VALUES
        //====================================================

        PCLK    = 1'b0;
        PRESETn = 1'b0;

        req   = 1'b0;
        write = 1'b0;
        addr  = 32'b0;
        wdata = 32'b0;


        //====================================================
        // RESET
        //====================================================

        #20;

        PRESETn = 1'b1;

        $display("");
        $display("======================================");
        $display("           APB TEST START");
        $display("======================================");


        //====================================================
        // WRITE 1
        //
        // CTRL_REG
        // Address = 0x0000
        // Data    = AAAAAAAA
        //====================================================

        apb_write(
            32'h0000,
            32'hAAAAAAAA
        );


        //====================================================
        // READ 1
        //
        // CTRL_REG
        //====================================================

        apb_read(
            32'h0000
        );


        //====================================================
        // WRITE 2
        //
        // DATA_REG
        // Address = 0x0008
        // Data    = BBBBBBBB
        //====================================================

        apb_write(
            32'h0008,
            32'hBBBBBBBB
        );


        //====================================================
        // READ 2
        //
        // DATA_REG
        //====================================================

        apb_read(
            32'h0008
        );


        //====================================================
        // WRITE 3
        //
        // CONFIG_REG
        // Address = 0x000C
        // Data    = CCCCCCCC
        //====================================================

        apb_write(
            32'h000C,
            32'hCCCCCCCC
        );


        //====================================================
        // READ 3
        //
        // CONFIG_REG
        //====================================================

        apb_read(
            32'h000C
        );


        //====================================================
        // WRITE 4
        //
        // CTRL_REG again
        // Address = 0x0000
        // Data    = DDDDDDDD
        //====================================================

        apb_write(
            32'h0000,
            32'hDDDDDDDD
        );


        //====================================================
        // READ 4
        //
        // CTRL_REG
        //====================================================

        apb_read(
            32'h0000
        );


        //====================================================
        // FINAL RESULTS
        //====================================================

        $display("");
        $display("======================================");
        $display("           FINAL RESULTS");
        $display("======================================");

        $display("CTRL_REG   = %h", slave.CTRL_REG);
        $display("STATUS_REG = %h", slave.STATUS_REG);
        $display("DATA_REG   = %h", slave.DATA_REG);
        $display("CONFIG_REG = %h", slave.CONFIG_REG);

        $display("======================================");


        #20;

        $finish;

    end

endmodule
