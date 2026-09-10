module apb_master (
    input  logic        PCLK,
    input  logic        PRESETn,

    //========================================================
    // INTERNAL REQUEST INTERFACE
    //========================================================

    input  logic        req,
    input  logic        write,
    input  logic [31:0] addr,
    input  logic [31:0] wdata,

    output logic [31:0] rdata,
    output logic        done,
    output logic        error,

    //========================================================
    // APB INTERFACE
    //========================================================

    output logic [31:0] PADDR,
    output logic        PSEL,
    output logic        PENABLE,
    output logic        PWRITE,
    output logic [31:0] PWDATA,

    input  logic [31:0] PRDATA,
    input  logic        PREADY,
    input  logic        PSLVERR
);

    //========================================================
    // STATE DECLARATION
    //========================================================

    typedef enum logic [1:0] {
        IDLE,
        SETUP,
        ACCESS
    } state_t;

    state_t state;
    state_t next_state;

    //========================================================
    // TRANSACTION REGISTERS
    //========================================================

    logic [31:0] addr_reg;
    logic [31:0] wdata_reg;
    logic        write_reg;

    //========================================================
    // STATE REGISTER
    //========================================================

    always_ff @(posedge PCLK or negedge PRESETn) begin

        if (!PRESETn)

            state <= IDLE;

        else

            state <= next_state;

    end

    //========================================================
    // NEXT STATE LOGIC
    //========================================================

    always_comb begin

        // Default: remain in current state
        next_state = state;

        case (state)

            //================================================
            // IDLE
            //================================================

            IDLE: begin

                if (req)

                    next_state = SETUP;

                else

                    next_state = IDLE;

            end

            //================================================
            // SETUP
            //================================================

            SETUP: begin

                // SETUP lasts exactly one clock cycle

                next_state = ACCESS;

            end

            //================================================
            // ACCESS
            //================================================

            ACCESS: begin

                if (PREADY) begin

                    // Current transfer completed.
                    //
                    // If another request is already waiting,
                    // immediately start another transaction.

                    if (req)

                        next_state = SETUP;

                    else

                        next_state = IDLE;

                end

                else begin

                    // Slave is inserting wait states.

                    next_state = ACCESS;

                end

            end

            //================================================
            // DEFAULT
            //================================================

            default: begin

                next_state = IDLE;

            end

        endcase

    end

    //========================================================
    // CAPTURE TRANSACTION INFORMATION
    //========================================================
    //
    // Normal transaction:
    //     IDLE + req
    //
    // Back-to-back transaction:
    //     ACCESS + PREADY + req
    //
    //========================================================

    always_ff @(posedge PCLK or negedge PRESETn) begin

        if (!PRESETn) begin

            addr_reg  <= 32'b0;
            wdata_reg <= 32'b0;
            write_reg <= 1'b0;

        end

        else if ((state == IDLE && req) ||
                 (state == ACCESS && PREADY && req)) begin

            addr_reg  <= addr;
            wdata_reg <= wdata;
            write_reg <= write;

        end

    end

    //========================================================
    // APB CONTROL SIGNALS
    //========================================================

    always_comb begin

        PSEL    = 1'b0;
        PENABLE = 1'b0;

        case (state)

            //================================================
            // IDLE
            //================================================

            IDLE: begin

                PSEL    = 1'b0;
                PENABLE = 1'b0;

            end

            //================================================
            // SETUP
            //================================================

            SETUP: begin

                PSEL    = 1'b1;
                PENABLE = 1'b0;

            end

            //================================================
            // ACCESS
            //================================================

            ACCESS: begin

                PSEL    = 1'b1;
                PENABLE = 1'b1;

            end

            //================================================
            // DEFAULT
            //================================================

            default: begin

                PSEL    = 1'b0;
                PENABLE = 1'b0;

            end

        endcase

    end

    //========================================================
    // APB ADDRESS / DATA / CONTROL
    //========================================================

    assign PADDR  = addr_reg;
    assign PWDATA = wdata_reg;
    assign PWRITE = write_reg;

    //========================================================
    // TRANSFER COMPLETE
    //========================================================

    assign done = (state == ACCESS) &&
                  PREADY;

    //========================================================
    // TRANSFER ERROR
    //========================================================

    assign error = (state == ACCESS) &&
                   PREADY &&
                   PSLVERR;

    //========================================================
    // READ DATA CAPTURE
    //========================================================

    always_ff @(posedge PCLK or negedge PRESETn) begin

        if (!PRESETn)

            rdata <= 32'b0;

        else if ((state == ACCESS) &&
                 PREADY &&
                 !write_reg) begin

            rdata <= PRDATA;

        end

    end

endmodule








