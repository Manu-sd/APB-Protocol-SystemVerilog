module apb_slave (
    input  logic        PCLK,
    input  logic        PRESETn,

    //========================================================
    // APB INPUTS
    //========================================================

    input  logic [31:0] PADDR,
    input  logic        PSEL,
    input  logic        PENABLE,
    input  logic        PWRITE,
    input  logic [31:0] PWDATA,

    //========================================================
    // APB OUTPUTS
    //========================================================

    output logic [31:0] PRDATA,
    output logic        PREADY,
    output logic        PSLVERR
);

    //========================================================
    // APB REGISTERS
    //========================================================

    logic [31:0] CTRL_REG;
    logic [31:0] STATUS_REG;
    logic [31:0] DATA_REG;
    logic [31:0] CONFIG_REG;

    //========================================================
    // ADDRESS DECODER
    //========================================================

    logic ctrl_sel;
    logic status_sel;
    logic data_sel;
    logic config_sel;
    logic addr_valid;

    assign ctrl_sel   = (PADDR == 32'h0000);

    assign status_sel = (PADDR == 32'h0004);

    assign data_sel   = (PADDR == 32'h0008);

    assign config_sel = (PADDR == 32'h000C);

    assign addr_valid = ctrl_sel   ||
                        status_sel ||
                        data_sel   ||
                        config_sel;

    //========================================================
    // WAIT STATE COUNTER
    //========================================================

    logic [1:0] wait_count;

    //========================================================
    // WAIT STATE COUNTER
    //========================================================
    //
    // SETUP:
    //     wait_count = 0
    //
    // ACCESS 1:
    //     wait_count = 1
    //
    // ACCESS 2:
    //     wait_count = 2
    //
    // After reaching 2:
    //     PREADY = 1
    //
    //========================================================

    always_ff @(posedge PCLK or negedge PRESETn) begin

        if (!PRESETn) begin

            wait_count <= 2'd0;

        end

        else begin

            //============================================
            // Outside ACCESS
            //============================================

            if (!PSEL || !PENABLE) begin

                wait_count <= 2'd0;

            end

            //============================================
            // Inside ACCESS
            //============================================

            else begin

                if (wait_count < 2'd2)

                    wait_count <= wait_count + 1'b1;

            end

        end

    end

    //========================================================
    // PREADY GENERATION
    //========================================================

    always_comb begin

        PREADY = 1'b0;

        if (PSEL &&
            PENABLE &&
            (wait_count >= 2'd2)) begin

            PREADY = 1'b1;

        end

    end

    //========================================================
    // ERROR GENERATION
    //========================================================

    assign PSLVERR = PSEL &&
                     PENABLE &&
                     PREADY &&
                     !addr_valid;

    //========================================================
    // WRITE OPERATION
    //========================================================

    always_ff @(posedge PCLK or negedge PRESETn) begin

        if (!PRESETn) begin

            CTRL_REG   <= 32'b0;
            STATUS_REG <= 32'b0;
            DATA_REG   <= 32'b0;
            CONFIG_REG <= 32'b0;

        end

        else if (PSEL &&
                 PENABLE &&
                 PWRITE &&
                 PREADY) begin

            //============================================
            // CTRL REGISTER
            // Address = 0x0000
            //============================================

            if (ctrl_sel)

                CTRL_REG <= PWDATA;

            //============================================
            // DATA REGISTER
            // Address = 0x0008
            //============================================

            else if (data_sel)

                DATA_REG <= PWDATA;

            //============================================
            // CONFIG REGISTER
            // Address = 0x000C
            //============================================

            else if (config_sel)

                CONFIG_REG <= PWDATA;

            //============================================
            // STATUS_REG
            // Read-only
            //============================================

            // No write operation

        end

    end

    //========================================================
    // READ OPERATION
    //========================================================

    always_comb begin

        // Default value

        PRDATA = 32'b0;

        // Read transaction

        if (PSEL &&
            PENABLE &&
            !PWRITE) begin

            //============================================
            // CTRL REGISTER
            //============================================

            if (ctrl_sel)

                PRDATA = CTRL_REG;

            //============================================
            // STATUS REGISTER
            //============================================

            else if (status_sel)

                PRDATA = STATUS_REG;

            //============================================
            // DATA REGISTER
            //============================================

            else if (data_sel)

                PRDATA = DATA_REG;

            //============================================
            // CONFIG REGISTER
            //============================================

            else if (config_sel)

                PRDATA = CONFIG_REG;

        end

    end

endmodule
