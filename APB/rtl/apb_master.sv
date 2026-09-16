//============================================================
// APB4 MASTER (Requester)
//
// AMBA APB Protocol Specification v2.0 (APB4)
//
// Adds over APB3:
//     PSTRB [DATA_WIDTH/8]  - write byte lane strobes
//     PPROT [2:0]           - protection attributes
//
// PPROT encoding (Arm IHI 0024):
//     PPROT[0] : 0 = normal      1 = privileged
//     PPROT[1] : 0 = secure      1 = non-secure
//     PPROT[2] : 0 = data        1 = instruction
//============================================================

module apb_master #(

    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int STRB_WIDTH = DATA_WIDTH / 8

) (
    input  logic                  PCLK,
    input  logic                  PRESETn,

    //========================================================
    // INTERNAL REQUEST INTERFACE
    //========================================================

    input  logic                  req,
    input  logic                  write,
    input  logic [ADDR_WIDTH-1:0] addr,
    input  logic [DATA_WIDTH-1:0] wdata,
    input  logic [STRB_WIDTH-1:0] strb,
    input  logic [2:0]            prot,

    output logic [DATA_WIDTH-1:0] rdata,
    output logic                  done,
    output logic                  error,

    //========================================================
    // APB INTERFACE
    //========================================================

    output logic [ADDR_WIDTH-1:0] PADDR,
    output logic                  PSEL,
    output logic                  PENABLE,
    output logic                  PWRITE,
    output logic [DATA_WIDTH-1:0] PWDATA,
    output logic [STRB_WIDTH-1:0] PSTRB,
    output logic [2:0]            PPROT,

    input  logic [DATA_WIDTH-1:0] PRDATA,
    input  logic                  PREADY,
    input  logic                  PSLVERR
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

    logic [ADDR_WIDTH-1:0] addr_reg;
    logic [DATA_WIDTH-1:0] wdata_reg;
    logic [STRB_WIDTH-1:0] strb_reg;
    logic [2:0]            prot_reg;
    logic                  write_reg;

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
            //
            // Lasts exactly one clock cycle.
            //================================================

            SETUP: begin

                next_state = ACCESS;

            end

            //================================================
            // ACCESS
            //================================================

            ACCESS: begin

                if (PREADY) begin

                    // Transfer completed.
                    // Back-to-back transaction if req still high.

                    if (req)

                        next_state = SETUP;

                    else

                        next_state = IDLE;

                end

                else begin

                    // Completer is inserting wait states.

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
    //
    // Normal transaction:
    //     IDLE + req
    //
    // Back-to-back transaction:
    //     ACCESS + PREADY + req
    //========================================================

    always_ff @(posedge PCLK or negedge PRESETn) begin

        if (!PRESETn) begin

            addr_reg  <= '0;
            wdata_reg <= '0;
            strb_reg  <= '0;
            prot_reg  <= 3'b000;
            write_reg <= 1'b0;

        end

        else if ((state == IDLE   && req) ||
                 (state == ACCESS && PREADY && req)) begin

            addr_reg  <= addr;
            wdata_reg <= wdata;
            strb_reg  <= strb;
            prot_reg  <= prot;
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

            IDLE: begin

                PSEL    = 1'b0;
                PENABLE = 1'b0;

            end

            SETUP: begin

                PSEL    = 1'b1;
                PENABLE = 1'b0;

            end

            ACCESS: begin

                PSEL    = 1'b1;
                PENABLE = 1'b1;

            end

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
    assign PPROT  = prot_reg;

    //========================================================
    // WRITE STROBES
    //
    // APB4 rule:
    //     PSTRB must be driven LOW for all read transfers.
    //========================================================

    assign PSTRB = write_reg ? strb_reg
                             : '0;

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

            rdata <= '0;

        else if ((state == ACCESS) &&
                 PREADY &&
                 !write_reg) begin

            rdata <= PRDATA;

        end

    end

endmodule






