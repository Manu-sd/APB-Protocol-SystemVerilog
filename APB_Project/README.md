# APB Master–Slave Interface (SystemVerilog)

A synthesizable **AMBA APB (Advanced Peripheral Bus)** master and slave, written in
SystemVerilog, with a self-checking testbench and QuestaSim simulation script.

The master converts a simple internal request interface (`req` / `write` / `addr` /
`wdata`) into a compliant APB transaction (`PSEL`, `PENABLE`, `PWRITE`, ...). The slave
implements a small 4-register memory map with configurable wait states and error
reporting, so the pair can be used to verify a real APB master/slave handshake,
including back-to-back transactions and wait-state insertion.

## Architecture

```
        req / write / addr / wdata            PADDR / PSEL / PENABLE / PWRITE / PWDATA
   ┌───────────────┐   ───────────────►   ┌───────────────┐
   │   Requester    │                     │   apb_master   │ ───────────────►  APB bus
   │ (e.g. CPU/FSM) │   ◄───────────────   │  (IDLE/SETUP/  │  ◄───────────────
   └───────────────┘   rdata / done/error  │    ACCESS)     │  PRDATA/PREADY/PSLVERR
                                            └───────────────┘
                                                     │
                                                     ▼
                                            ┌───────────────┐
                                            │   apb_slave    │
                                            │ (register file │
                                            │  + wait states)│
                                            └───────────────┘
```

### `apb_master`

A 3-state Moore FSM (`IDLE → SETUP → ACCESS`) that drives the APB protocol on behalf
of an internal requester:

| State    | PSEL | PENABLE | Behavior |
|----------|:----:|:-------:|----------|
| `IDLE`   | 0    | 0       | Waits for `req`. On `req`, latches `addr`/`wdata`/`write` and moves to `SETUP`. |
| `SETUP`  | 1    | 0       | One-cycle setup phase (address/control valid, `PENABLE` still low). |
| `ACCESS` | 1    | 1       | Access phase. Holds until slave asserts `PREADY`. Supports **back-to-back** transactions — if `req` is still high when `PREADY` completes the transfer, it re-enters `SETUP` immediately instead of returning to `IDLE`. |

Outputs: `done` (pulses when a transfer completes), `error` (qualified by `PSLVERR`),
and `rdata` (captured from `PRDATA` on completed read transfers).

### `apb_slave`

A 4-register memory-mapped slave with a fixed 3-cycle access (2 programmed wait
states before `PREADY`):

| Register     | Address  | Access |
|--------------|----------|--------|
| `CTRL_REG`   | `0x0000` | R/W |
| `STATUS_REG` | `0x0004` | Read-only (no write path) |
| `DATA_REG`   | `0x0008` | R/W |
| `CONFIG_REG` | `0x000C` | R/W |

- **Wait-state generation:** a 2-bit `wait_count` increments every cycle while
  `PSEL && PENABLE`, and `PREADY` is asserted once `wait_count >= 2`, i.e. every
  transaction takes 2 wait cycles before completing.
- **Error response:** `PSLVERR` is asserted when a completed transfer (`PSEL &&
  PENABLE && PREADY`) targets an address outside the 4 decoded registers
  (`addr_valid == 0`).

## Repository layout

```
.
├── rtl/
│   ├── apb_master.sv     # APB master FSM
│   └── apb_slave.sv      # APB slave (register file + wait states)
├── tb/
│   └── tb_apb_master.sv  # Self-checking testbench (write/read tasks)
├── sim/
│   └── apb.do            # QuestaSim compile + simulate + waveform script
└── docs/
    └── img/              # Waveforms and RTL schematics
```

## Testbench

`tb_apb_master.sv` instantiates `apb_master` and `apb_slave` back-to-back (no
external APB bus needed) and drives them through reusable `apb_write` / `apb_read`
tasks that:

1. Apply `req`/`write`/`addr`/`wdata` on a falling clock edge.
2. Wait for `done`.
3. Print the transaction result (`$display`) including any `error`.
4. De-assert `req` and let the master return to `IDLE`.

The test sequence exercises all three writable registers, each followed by a
read-back check:

```
WRITE 0x0000 = AAAAAAAA  → READ 0x0000
WRITE 0x0008 = BBBBBBBB  → READ 0x0008
WRITE 0x000C = CCCCCCCC  → READ 0x000C
WRITE 0x0000 = DDDDDDDD  → READ 0x0000   (overwrite CTRL_REG again)
```

Final register contents are dumped at the end of simulation.

## Running the simulation (QuestaSim/ModelSim)

```bash
cd sim
vsim -do apb.do
```

`apb.do` compiles `apb_master.sv`, `apb_slave.sv`, and `tb_apb_master.sv`, launches
`vsim` with full visibility (`-voptargs=+acc`), adds the master/slave internal
signals and register contents to the Wave window, and runs to completion.

To run headless (no waveform GUI), replace `vsim -voptargs=+acc work.tb_apb_master`
in `apb.do` with `vsim -c -voptargs=+acc work.tb_apb_master` and add `-do "run -all; quit"`.

## Simulation results

**Master-side transaction waveform** — `req`/`addr`/`wdata` driving the FSM through
`SETUP → ACCESS`, and `rdata` capturing each read result:

![Master waveform](docs/img/waveform_master.png)

**Slave-side waveform** — wait-state counter reaching 2 before `PREADY` asserts, and
the register file (`CTRL_REG`, `DATA_REG`, `CONFIG_REG`) updating on each write:

![Slave waveform](docs/img/waveform_slave.png)

All four writes complete with `error = 0`, and each subsequent read returns the
exact value written, confirming correct address decoding and register storage.

## RTL schematics

Generated (QuestaSim RTL viewer) block diagrams for reference:

| Master | Slave | Top-level connectivity |
|--------|-------|--------------------------|
| ![Master schematic](docs/img/schematic_master.png) | ![Slave schematic](docs/img/schematic_slave.png) | ![Top schematic](docs/img/schematic_top.png) |

## Possible extensions

- Parameterize the number of slave wait states.
- Add an APB address decoder / multiplexer to support multiple slaves on one bus.
- Add SVA (SystemVerilog Assertions) for protocol compliance (e.g. `PADDR` must
  stay stable through `SETUP`+`ACCESS`, `PENABLE` must deassert for exactly one
  cycle between back-to-back transfers is *not* required per spec but worth
  checking against your target IP).
- Wrap with UVM for constrained-random regression instead of the directed tasks.

## Author

Manu S D — Team Zenther
