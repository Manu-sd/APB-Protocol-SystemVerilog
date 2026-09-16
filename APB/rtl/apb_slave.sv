//============================================================
// APB4 SLAVE (Completer)
//
// AMBA APB Protocol Specification v2.0 (APB4)
//
// Adds over APB3:
//     PSTRB - per-byte write enables (sparse writes)
//     PPROT - protection attribute checking
//
// REGISTER MAP
//     0x0000  CTRL_REG     R/W
//     0x0004  STATUS_REG   Read-only  (hardware maintained)
//     0x0008  DATA_REG     R/W
//     0x000C  CONFIG_REG   R/W, privileged access only
//
// STATUS_REG layout
//     [7:0]   completed write transfer count
//     [15:8]  completed read transfer count
//     [16]    sticky: last transfer produced PSLVERR
//     [31:17] reserved, reads as zero
//============================================================

module apb_slave #(

    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int STRB_WIDTH = DATA_WIDTH / 8,

    // Number of wait states inserted before PREADY
    parameter int WAIT_STATES = 2

) (
    input  logic                  PCLK,
    input  logic                  PRESETn,

    //========================================================
    // APB INPUTS
    //========================================================

    input  logic [ADDR_WIDTH-1:0] PADDR,
    input  logic                  PSEL,
    input  logic                  PENABLE,
    input  logic                  PWRITE,
    input  logic [DATA_WIDTH-1:0] PWDATA,
    input  logic [STRB_WIDTH-1:0] PSTRB,
    input  logic [2:0]            PPROT,

    //========================================================
    // APB OUTPUTS
    //========================================================

    output logic [DATA_WIDTH-1:0] PRDATA,
    output logic                  PREADY,
    output logic                  PSLVERR
);

    //========================================================
    // REGISTERS
    //========================================================

    logic [DATA_WIDTH-1:0] CTRL_REG;
    logic [DATA_WIDTH-1:0] DATA_REG;
    logic [DATA_WIDTH-1:0] CONFIG_REG;

    // STATUS_REG is assembled from hardware counters
    logic [7:0]            write_count;
    logic [7:0]            read_count;
    logic                  err_sticky;

    logic [DATA_WIDTH-1:0] STATUS_REG;

    assign STATUS_REG = { 15'b0,
                          err_sticky,
                          read_count,
                          write_count };

    //========================================================
    // ADDRESS DECODER
    //========================================================

    logic ctrl_sel;
    logic status_sel;
    logic data_sel;
    logic config_sel;
    logic addr_valid;

    assign ctrl_sel   = (PADDR == 'h0000);

    assign status_sel = (PADDR == 'h0004);

    assign data_sel   = (PADDR == 'h0008);

    assign config_sel = (PADDR == 'h000C);

    assign addr_valid = ctrl_sel   ||
                        status_sel ||
                        data_sel   ||
                        config_sel;

    //========================================================
    // PROTECTION CHECK
    //
    // PPROT[0] : 0 = normal, 1 = privileged
    //
    // CONFIG_REG is privileged-access only.
    // A normal-level access to it is refused with PSLVERR.
    //========================================================

    logic priv_ok;

    assign priv_ok = config_sel ? PPROT[0]
                                : 1'b1;

    //========================================================
    // WRITE PROTECTION CHECK
    //
    // STATUS_REG is read-only.
    // A write to it is refused with PSLVERR.
    //========================================================

    logic write_ok;

    assign write_ok = !(PWRITE && status_sel);

    //========================================================
    // WAIT STATE COUNTER
    //
    // SETUP     : wait_count = 0
    // ACCESS 1  : wait_count = 1
    // ACCESS 2  : wait_count = 2  -> PREADY
    //========================================================

    localparam int CNT_WIDTH = (WAIT_STATES <= 1) ? 1 : $clog2(WAIT_STATES + 1);

    logic [CNT_WIDTH-1:0] wait_count;

    always_ff @(posedge PCLK or negedge PRESETn) begin

        if (!PRESETn) begin

            wait_count <= '0;

        end

        else begin

            //============================================
            // Outside ACCESS
            //============================================

            if (!PSEL || !PENABLE) begin

                wait_count <= '0;

            end

            //============================================
            // Inside ACCESS
            //============================================

            else begin

                if (wait_count < CNT_WIDTH'(WAIT_STATES))

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
            (wait_count >= CNT_WIDTH'(WAIT_STATES))) begin

            PREADY = 1'b1;

        end

    end

    //========================================================
    // ERROR GENERATION
    //
    // Asserted on a completing transfer when:
    //     - address is not decoded, OR
    //     - protection level is insufficient, OR
    //     - the access writes a read-only register
    //========================================================

    assign PSLVERR = PSEL &&
                     PENABLE &&
                     PREADY &&
                     (!addr_valid || !priv_ok || !write_ok);

    //========================================================
    // TRANSFER QUALIFIERS
    //========================================================

    logic xfer_done;
    logic xfer_ok;

    assign xfer_done = PSEL && PENABLE && PREADY;

    assign xfer_ok   = xfer_done && !PSLVERR;

    //========================================================
    // BYTE-LANE WRITE HELPER
    //
    // Applies PWDATA to reg_q one byte lane at a time,
    // gated by the corresponding PSTRB bit.
    //========================================================

    function automatic logic [DATA_WIDTH-1:0] strb_merge (
        input logic [DATA_WIDTH-1:0] old_val,
        input logic [DATA_WIDTH-1:0] new_val,
        input logic [STRB_WIDTH-1:0] strobe
    );

        logic [DATA_WIDTH-1:0] result;

        result = old_val;

        for (int i = 0; i < STRB_WIDTH; i++) begin

            if (strobe[i])

                result[i*8 +: 8] = new_val[i*8 +: 8];

        end

        return result;

    endfunction

    //========================================================
    // WRITE OPERATION
    //========================================================

    always_ff @(posedge PCLK or negedge PRESETn) begin

        if (!PRESETn) begin

            CTRL_REG   <= '0;
            DATA_REG   <= '0;
            CONFIG_REG <= '0;

        end

        else if (xfer_ok && PWRITE) begin

            //============================================
            // CTRL_REG  0x0000
            //============================================

            if (ctrl_sel)

                CTRL_REG <= strb_merge(CTRL_REG, PWDATA, PSTRB);

            //============================================
            // DATA_REG  0x0008
            //============================================

            else if (data_sel)

                DATA_REG <= strb_merge(DATA_REG, PWDATA, PSTRB);

            //============================================
            // CONFIG_REG  0x000C  (privileged only)
            //============================================

            else if (config_sel)

                CONFIG_REG <= strb_merge(CONFIG_REG, PWDATA, PSTRB);

            //============================================
            // STATUS_REG  0x0004 is read-only.
            // Writes to it are rejected by write_ok,
            // so this branch is never reached.
            //============================================

        end

    end

    //========================================================
    // STATUS COUNTERS
    //========================================================

    always_ff @(posedge PCLK or negedge PRESETn) begin

        if (!PRESETn) begin

            write_count <= 8'd0;
            read_count  <= 8'd0;
            err_sticky  <= 1'b0;

        end

        else begin

            if (xfer_ok && PWRITE)

                write_count <= write_count + 8'd1;

            if (xfer_ok && !PWRITE)

                read_count <= read_count + 8'd1;

            if (xfer_done && PSLVERR)

                err_sticky <= 1'b1;

        end

    end

    //========================================================
    // READ OPERATION
    //========================================================

    always_comb begin

        PRDATA = '0;

        if (PSEL &&
            PENABLE &&
            !PWRITE) begin

            if (ctrl_sel)

                PRDATA = CTRL_REG;

            else if (status_sel)

                PRDATA = STATUS_REG;

            else if (data_sel)

                PRDATA = DATA_REG;

            else if (config_sel && priv_ok)

                PRDATA = CONFIG_REG;

        end

    end

endmodule
