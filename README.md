# APB4 Master–Slave Interface (SystemVerilog)

A synthesizable **AMBA APB4** requester (master) and completer (slave), written in
SystemVerilog, verified with a self-checking testbench on QuestaSim.

```
PASSED = 14
FAILED = 0
RESULT : ALL TESTS PASSED
```

This is an APB4 upgrade of an earlier APB3 master–slave design. APB4 adds two signals
over APB3 — both implemented and verified here:

| Signal | Width | Purpose |
|---|---|---|
| `PSTRB` | `DATA_WIDTH/8` | Write byte-lane strobes — enables sparse (partial-word) writes |
| `PPROT` | 3 | Protection attributes (privilege, security, data/instruction) |

## Signal coverage by spec revision

| Signal | Added in | Implemented |
|---|---|:---:|
| PCLK, PRESETn, PADDR, PSEL, PENABLE, PWRITE, PWDATA, PRDATA | APB2 | ✅ |
| PREADY, PSLVERR | APB3 | ✅ |
| PSTRB, PPROT | APB4 | ✅ |
| PWAKEUP, PAUSER, PWUSER, PRUSER, PBUSER, PNSE | APB5 | — |

## Architecture

```
   req / write / addr / wdata / strb / prot
        ┌──────────────┐                        ┌──────────────┐
        │  apb_master  │ ── PADDR, PSEL,        │  apb_slave   │
        │  IDLE        │    PENABLE, PWRITE, ──►│  decode      │
        │   → SETUP    │    PWDATA, PSTRB,      │  wait states │
        │   → ACCESS   │    PPROT               │  registers   │
        │              │ ◄── PRDATA, PREADY, ───│              │
        └──────────────┘     PSLVERR            └──────────────┘
   rdata / done / error
```

### `apb_master`

Parameterized (`ADDR_WIDTH`, `DATA_WIDTH`) 3-state Moore FSM:

| State | PSEL | PENABLE | Behavior |
|---|:---:|:---:|---|
| `IDLE` | 0 | 0 | Waits for `req`; latches addr/wdata/strb/prot/write. |
| `SETUP` | 1 | 0 | One-cycle setup phase. |
| `ACCESS` | 1 | 1 | Holds until `PREADY`. If `req` is still high at completion, re-enters `SETUP` directly — back-to-back transfer, no `IDLE` bubble. |

Enforces the APB4 rule that **`PSTRB` must be driven LOW for all read transfers**:

```systemverilog
assign PSTRB = write_reg ? strb_reg : '0;
```

### `apb_slave`

Parameterized (`ADDR_WIDTH`, `DATA_WIDTH`, `WAIT_STATES`) register-file completer.

| Register | Address | Access |
|---|---|---|
| `CTRL_REG` | `0x0000` | R/W |
| `STATUS_REG` | `0x0004` | Read-only, hardware maintained |
| `DATA_REG` | `0x0008` | R/W |
| `CONFIG_REG` | `0x000C` | R/W, **privileged access only** |

**Byte-lane writes.** A `strb_merge` function applies `PWDATA` one byte lane at a time,
gated by the matching `PSTRB` bit, so unselected lanes keep their old value.

**Protection checking.** `CONFIG_REG` requires `PPROT[0] == 1` (privileged). A
normal-level access is refused with `PSLVERR` and the register is left unchanged.

**`PSLVERR`** is asserted on a completing transfer when the address is undecoded, the
protection level is insufficient, or the access writes a read-only register.

**`STATUS_REG`** is hardware-maintained, not a dead placeholder:

| Field | Bits | Meaning |
|---|---|---|
| Write count | `[7:0]` | Completed write transfers |
| Read count | `[15:8]` | Completed read transfers |
| Sticky error | `[16]` | Set once any transfer returned `PSLVERR` |
| Reserved | `[31:17]` | Reads as zero |

## Verification

`tb/tb_apb_master.sv` is self-checking with a pass/fail scoreboard.

| Test | What it proves |
|---|---|
| 1 | Full-word write and read-back on `CTRL_REG` / `DATA_REG` |
| 2 | Sparse writes — `PSTRB` = `0001`, `1000`, `1100`, `0000` each update only the selected byte lanes |
| 3 | `PPROT` privilege gate — normal write to `CONFIG_REG` errors, privileged write succeeds |
| 4 | Write to read-only `STATUS_REG` returns `PSLVERR` |
| 5 | Unmapped address returns `PSLVERR` |
| 6 | `STATUS_REG` counters and sticky error flag track real traffic |
| 7 | Back-to-back writes complete with no `IDLE` state between them |

Two SVA properties (behind `` `ifdef ENABLE_SVA ``) check protocol compliance
continuously: `PSTRB` must be zero during any read, and `PADDR` must stay stable
through wait states.

## Simulation results

**Master-side waveform** — request interface, `PSTRB`/`PPROT` driving through
`SETUP → ACCESS`, and `rdata` capturing sparse-write results (`aaaaaa11`,
`22aaaa11`, `3333aa11`):

![Master waveform](docs/img/waveform_master.png)

**Slave-side waveform** — address decode (`ctrl_sel`/`data_sel`/`config_sel`),
`priv_ok`/`write_ok` gating, and the `STATUS_REG` write/read counters incrementing
on every completed transfer:

![Slave waveform](docs/img/waveform_slave.png)

## RTL schematics

Generated (QuestaSim RTL viewer) block diagrams:

| Master | Slave | Top-level connectivity |
|--------|-------|--------------------------|
| ![Master schematic](docs/img/schematic_master.png) | ![Slave schematic](docs/img/schematic_slave.png) | ![Top schematic](docs/img/schematic_top.png) |

## Running

**QuestaSim / ModelSim:**
```bash
cd sim
vsim -do apb.do
```
`apb.do` compiles the three `.sv` files from the current directory. If you keep the
`rtl/` / `tb/` split shown below, either copy the sources into `sim/` before running,
or add `../rtl/` and `../tb/` prefixes to the `vlog` lines.

**Icarus Verilog** (no SVA support — omit `+define+ENABLE_SVA`):
```bash
iverilog -g2012 -o sim.out rtl/apb_master.sv rtl/apb_slave.sv tb/tb_apb_master.sv
vvp sim.out
```

## Repository layout

```
.
├── rtl/
│   ├── apb_master.sv     # APB4 requester FSM
│   └── apb_slave.sv      # APB4 completer (byte-lane writes, PPROT, status counters)
├── tb/
│   └── tb_apb_master.sv  # Self-checking testbench, 14 checks + 2 SVA properties
├── sim/
│   └── apb.do            # QuestaSim compile + wave + run
└── docs/
    └── img/              # Waveforms and RTL schematics
```

## Notes on terminology

Arm's current specifications use **Requester** and **Completer** rather than Master and
Slave. Module names here keep the legacy terms for continuity; comments use the
current terminology.

## Next step toward APB5

APB5 (Issue D/E) adds `PWAKEUP` (wake-up signaling), the user sideband signals
(`PAUSER`, `PWUSER`, `PRUSER`, `PBUSER`), interface parity protection, and — in Issue E —
Realm Management Extension support. All are optional, so this APB4 design is legal on
an APB5 interconnect with those inputs tied off.

## Author

Manu S D — Team Zenther
