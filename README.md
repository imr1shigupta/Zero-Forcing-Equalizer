# Zero Forcing Equalizer (ZFE) - Hardware Implementation Project

## Table of Contents

1. [Problem Statement](#problem-statement)
2. [Solution Overview](#solution-overview)
3. [Implementation of the Solution](#implementation-of-the-solution)
4. [VLSI/DSP Aspects Used](#vlsidsp-aspects-used)
5. [Project Directory Structure](#project-directory-structure)
6. [Workflow for Users](#workflow-for-users)
7. [Key Technical Concepts](#key-technical-concepts)
8. [Performance Considerations](#performance-considerations)
9. [Detailed Mathematics (for reference)](#detailed-mathematics-for-reference)

\---

## Problem Statement

### Background: Digital Communication System with ISI

In digital communication systems, transmitted signals undergo distortion as they travel through communication channels. This distortion causes **Inter-Symbol Interference (ISI)** — the overlapping of adjacent symbols, where the tail of one symbol bleeds into the time slot of the next symbol.

### The Scenario

Our system implements a complete baseband digital communication pipeline:

1. **Transmitter Side**: Message bits are encoded as Bipolar Return-to-Zero (BRZ) symbols and shaped using Square-Root Raised Cosine (SRRC) pulse shaping
2. **Channel**: The signal passes through a distorted channel with impulse response: h(t) = δ(t) + 0.75δ(t - Tb) + 0.25δ(t - 2Tb)
3. **Receiver Side**: Another SRRC filter is applied, producing an effective channel pulse response that exhibits severe ISI
4. **Detection Problem**: Without equalization, the received signal is corrupted with ISI, leading to high bit error rates

### The Challenge

Given a received signal corrupted by ISI, how can we recover the original transmitted message with minimal error? Direct threshold detection fails because the ISI causes symbols to interfere with adjacent symbols.

\---

## Solution Overview

### Zero Forcing Equalization Approach

The **Zero Forcing (ZF) Equalizer** is an FIR (Finite Impulse Response) filter designed to completely eliminate ISI by "forcing" the effective channel response to have zeros at all but one sampling instant.

### Mathematical Formulation

**Goal**: Find equalizer weights w = \[w₀, w₁, w₂, w₃, w₄]ᵀ such that when the distorted received signal passes through the 5-tap equalizer filter, the output is:

* **1** at the correct sampling instant (perfect symbol recovery)
* **0** at all adjacent sampling instants (complete ISI elimination)

This is expressed as the linear system:

```
P · w = d
```

Where:

* **P**: 5×5 Toeplitz convolution matrix formed from the effective channel pulse samples
* **w**: Equalizer weights (what we need to find)
* **d**: Desired output \[1, 0, 0, 0, 0]ᵀ (perfect impulse)

### Solution Strategy

1. **Extract Effective Channel Response**: Run MATLAB simulation to get sampled\_effective\_u.txt (the combined effect of Tx filter → Channel → Rx filter)
2. **Compute Matrix Inverse**: Use synthesizable LU decomposition hardware to compute P⁻¹
3. **Calculate Weights**: Use systolic array hardware to multiply P⁻¹ · d to get the equalizer weights
4. **Apply Equalization**: Stream received signal through the 5-tap FIR filter using computed weights
5. **Recover Message**: Threshold detect the equalized signal to recover original bits

\---

## Implementation of the Solution

### Project Components

The project is organized into two main parts: **MATLAB Simulation** and **Verilog Hardware**.

\---

### Part 1: MATLAB Simulation Environment

#### `Communication System Simulation.mlx` (MATLAB Live Script)

**Section 1 (Lines 1-135): Signal Generation and Channel Simulation**

1. **Data Encoding**:

   * Input: String message (e.g., "Hello, This is my first message...")
   * Convert to ASCII binary (8 bits per character)
   * Maps to BRZ: 0 → -1, 1 → +1
2. **SRRC Pulse Shaping (Transmitter)**:

   * Roll-off factor: 0.25
   * Span: 6 symbol durations (6Tb)
   * Samples per symbol: 100 (fs = 1000 Hz, Tb = 0.1s)
   * Output: Smooth pulse-shaped signal ready for transmission
3. **Channel Distortion**:

   * Impulse response: h = \[1, 0, ..., 0.75, 0, ..., 0.25, 0, ...]
   * At delays: 0Tb, Tb, and 2Tb
   * Simulates realistic multipath propagation
   * Creates significant ISI in received signal
4. **Receiver SRRC Filter**:

   * Matched filter for received signal
   * Combined with transmitter SRRC and channel creates effective pulse u(t)
5. **Signal Sampling and File Output**:

   * Downsamples effective pulse to get u\[0], u\[1], ..., u\[14] (15 samples)
   * Saves to `sampled\_effective\_u.txt` (for LU Decomposition module)
   * Saves full received signal to `rxfilter\_response.txt` (for Equalization module)
   * First detection attempt (without equalizer) → shows poor message recovery

**Section 2 (Lines 136-155): Equalized Signal Reception**

1. **Reads Hardware Output**:

   * Opens `equalizer\_response.txt` (output from tb\_complete\_zfe.v)
   * Contains equalized received signal in real/decimal format
2. **Signal Detection**:

   * Samples equalized signal at symbol rate
   * Applies threshold detection: > 0 → bit '1', < 0 → bit '0'
   * Converts bit stream back to ASCII characters
3. **Results**:

   * Displays recovered message after equalization
   * Compares with original message (typically shows perfect or near-perfect recovery)

**Key MATLAB Functions**:

* `stringToBinary()`: Converts text to 8-bit binary ASCII
* `binaryToAsciiString()`: Converts binary bits back to text

\---

### Part 2: Verilog Hardware Implementation

#### **Main Orchestrator: `tb\_complete\_zfe.v`** (Non-Synthesizable Testbench)

This is the **top-level test environment** that:

1. **File I/O Management**:

   * Reads `sampled\_effective\_u.txt` → stores in array h\[0:14] in Q8.24 format
   * Reads `rxfilter\_response.txt` → streams into equalizer module
   * Writes equalized output to `equalizer\_response.txt`
2. **Format Conversion**:

   * Encodes real values to Q8.24: `q\_value = real\_value × 2²⁴`
   * Decodes Q8.24 back to real: `real\_value = q\_value / 2²⁴`
3. **Hardware Module Instantiation and Sequencing**:

   * **Step 1**: Trigger LU Decomposition module

     * Builds 5×5 Toeplitz matrix P from h\[6:10], h\[5:9], ..., h\[2:6]
     * Waits for inverse matrix P⁻¹ output
   * **Step 2**: Feed P⁻¹ into Systolic Array

     * Injects rows of P⁻¹ from left (A inputs)
     * Injects \[1, 0, 0, 0, 0]ᵀ from top (B inputs)
     * Extracts first column of result (the weights)
   * **Step 3**: Stream signal through Equalizer

     * Enables equalizer module
     * Continuously feeds samples from `rxfilter\_response.txt`
     * Collects valid outputs and writes to `equalizer\_response.txt`
4. **Clock and Reset Management**:

   * Generates 10ns clock period
   * Holds reset for 30ns, then releases
   * Synchronizes all modules on clock edges
5. **Display Outputs**:

   * Prints original matrix P (reconstructed from h\[])
   * Prints computed inverse matrix P⁻¹
   * Prints calculated equalizer weights w₀...w₄
   * Provides visibility into intermediate results

\---

#### **Synthesizable Module 1: `lu\_inverse\_5x5\_q8\_24.v`**

**Purpose**: Compute matrix inverse using LU Decomposition

**Algorithm**:

1. **LU Factorization**: Decomposes P = L · U

   * L: Lower triangular with 1s on diagonal
   * U: Upper triangular
2. **Forward Substitution**: Solves L · Y = I (column-wise)
3. **Backward Substitution**: Solves U · X = Y (column-wise)
4. **Result**: X = P⁻¹

**Implementation Details**:

* **FSM States** (10 states):

```
  IDLE → LOAD → LU\_RECIP → LU\_UPDATE →
  FWD\_INIT → FWD\_ACC → BWD\_INIT → BWD\_ACC →
  WRITE → DONE
  ```

* **Key Operations**:

  * LU\_RECIP: Computes reciprocal 1/U\[k]\[k] using fixed-point division
  * LU\_UPDATE: Updates L and U matrices using Doolittle's algorithm
  * FWD\_ACC: Accumulates forward substitution results
  * BWD\_ACC: Accumulates backward substitution results
* **Q8.24 Fixed-Point Math**:

  * Division (reciprocal): `result = (2⁴⁸ / divisor) >> 24`
  * Multiplication-accumulation: `acc = acc - ((64-bit product) >> 24)`
* **Ports**:

  * Input: 25 matrix elements (A00-A44) + clock, reset, start signal
  * Output: 25 inverse matrix elements (Ainv00-Ainv44) + done flag
  * Latency: \~100 clock cycles for 5×5 matrix

**Synthesis Friendly**:

* All operations use registered FSM (no latches)
* Fixed loop counts (no data-dependent loops)
* Explicit 64-bit intermediate arithmetic to prevent truncation

\---

#### **Synthesizable Module 2: `systolic\_5x5\_q8\_24.v`**

**Purpose**: Perform 5×5 matrix multiplication using systolic array architecture

**Architecture**: Grid of 25 Processing Elements (PEs) arranged in 5×5 formation

**Dataflow**:

* **Matrix A** (left input): Injected from left, shifts RIGHT within each row
* **Matrix B** (top input): Injected from top, shifts DOWN within each column
* **Result C**: Computed at each PE, accumulated over time

**How It Works**:

1. **Systolic Wave Propagation** (20 cycles):

   * Cycle 0: First row of A enters from left, first element of B enters from top
   * Cycles 1-4: Matrix data waves propagate rightward and downward
   * Cycles 5-19: Pipeline fills and computes partial products
   * Result: Full 5×5 product computed with output available at every PE
2. **Pipeline Stage Details**:

   * **Cycle t=0-19**: A and B data continuously fed
   * Each PE computes: `C\[i]\[j] += A\[i]\[\*] · B\[\*]\[j]` over time
   * Final result extracted from acc\[i]\[j] at each PE
3. **Hardware Efficiency**:

   * All 25 multiplications happen in parallel
   * Single 5×5 matrix multiply takes \~25 cycles total
   * Perfect for streaming applications

**Ports**:

* Input: A0-A4 (row elements), B0-B4 (column elements) + clock, reset
* Output: C00-C44 (all 25 result matrix elements)

\---

#### **Synthesizable Module 3: `pe\_q8\_24.v`** (Processing Element)

**Purpose**: Single PE cell - multiply \& accumulate in Q8.24 format

**Dataflow within PE**:

```
a\_in × b\_in → 64-bit product → right-shift 24 bits → Q8.24 result → accumulator
```

**Implementation**:

1. **Multiply Stage**:

   * `mult = a\_in × b\_in` (full 64-bit product: Q16.48 format)
2. **Scale to Q8.24**:

   * `mult\_q8\_24 = mult >> 24` (arithmetic right-shift)
3. **Accumulate**:

   * `acc\_r = acc\_r + mult\_q8\_24` (sign-extended for correctness)
4. **Output**:

   * `acc = acc\_r\[31:0]` (truncate accumulator to 32 bits)

**Key Design Choices**:

* Internal accumulator is 56 bits (Q32.24) to prevent overflow
* Sign extension before accumulation prevents sign errors
* Fully pipelined for systolic array integration

\---

#### **Synthesizable Module 4: `equalizer\_q8\_24.v`**

**Purpose**: 5-tap FIR filter implementing Zero Forcing Equalization

**Architecture**: Multi-stage pipelined FIR with circular buffer

**Signal Processing Pipeline** (5 stages):

```
Stage 1: RAM Write + Tap Read
         Input sample → written to circular buffer
         Read historical samples at delays T, 2T, 3T, 4T

Stage 2: Multiply
         All 5 taps multiplied by weights in parallel
         Products scaled from Q16.48 → Q8.24

Stage 3: Add Level 1
         (p0 + p1) and (p2 + p3) computed in parallel

Stage 4: Add Level 2
         Sum of 4 products computed

Stage 5: Final Add
         Final 5-tap sum + output valid flag
```

**Implementation Details**:

1. **Circular RAM Buffer** (512 locations):

   * Holds last 512 samples of received signal
   * Distributed RAM for efficient resource usage
   * Write pointer increments each cycle
2. **Tap Extraction** (Q8.24 fixed-point delays):

   * tap0: Current sample (delay = 0)
   * tap1: Sample from 100 cycles ago (delay = 100Ts)
   * tap2: Sample from 200 cycles ago (delay = 200Ts)
   * tap3: Sample from 300 cycles ago (delay = 300Ts)
   * tap4: Sample from 400 cycles ago (delay = 400Ts)
3. **Q8.24 Multiply-Accumulate**:

   * Each weight × tap produces Q16.48 product
   * Right-shift by 24 bits → Q8.24
   * Adder tree combines 5 results
4. **Pipelining Benefits**:

   * Can accept new input every clock cycle
   * 5-cycle latency through pipeline
   * valid\_out flag indicates when output is ready
5. **Fixed-Point Precision**:

   * Products: 64-bit intermediate
   * Sums: 32-bit (no overflow with Q8.24 inputs)
   * Maintains accuracy throughout pipeline

**Ports**:

* Input: clk, rst, enable, data\_in (Q8.24), w0-w4 weights (Q8.24)
* Output: data\_out (Q8.24), valid\_out flag
* Throughput: 1 sample/clock after pipeline filled

\---

### Supporting Testbenches (Synthesis Verification)

#### `tb\_pe\_q8\_24.v`

* **Purpose**: Unit test for processing element
* **Verification**: Tests multiply-accumulate correctness with various Q8.24 values
* **Method**: Inject known a\_in, b\_in patterns; verify accumulation

#### `tb\_systolic\_5x5\_q8\_24.v`

* **Purpose**: Unit test for systolic array
* **Verification**: Verify 5×5 matrix multiplication
* **Test Vector**: Known matrices, compare output against MATLAB reference

#### `tb\_lu\_inverse\_5x5\_q8\_24.v`

* **Purpose**: Unit test for LU decomposition
* **Verification**: Verify matrix inverse computation
* **Test Vector**: Toeplitz matrices with various condition numbers

\---

## VLSI/DSP Aspects Used

### 1\. **Q8.24 Fixed-Point Arithmetic**

**Why This Format?**

|Aspect|Rationale|
|-|-|
|**Precision**|24 fractional bits provide \~1.4×10⁻⁷ relative error (sufficient for audio/communication)|
|**Dynamic Range**|±2⁷ = ±128 covers signal ranges in normalized communication systems|
|**Hardware Efficiency**|32-bit standard word size; fits exactly in single register|
|**No Floating Point**|Avoids expensive floating-point multipliers; uses simple integer arithmetic|
|**Deterministic Timing**|All operations take fixed cycles (unlike floating-point variable latency)|
|**ASIC Friendly**|Can be synthesized to gates; no special floating-point IP required|

**Implementation**:

* Multiplication: Uses standard 32×32→64 multiplier, then >> 24
* Addition: Direct (no scaling needed for same Q format)
* Division: Pre-compute reciprocal; multiply instead

\---

### 2\. **Systolic Array Architecture**

**Why Systolic Array for Matrix Multiplication?**

|Feature|Benefit|
|-|-|
|**Parallelism**|25 PEs compute 25 products simultaneously (vs. sequential)|
|**Dataflow**|Regular data movement pattern optimizes memory/computation ratio|
|**Scalability**|Easy to extend from 5×5 to NxN by adding more PE cells|
|**Low Memory Bandwidth**|Each data element reused multiple times before moving (good cache/bandwidth ratio)|
|**Pipelineable**|Can accept new matrix pairs while previous multiplication in progress|
|**ASIC Friendly**|Regular structure maps well to silicon; no complex control logic|

**Systolic Advantages Over Alternatives**:

* **vs. Direct 5×5 multiplier**: Modular, scalable, uses fewer gates
* **vs. Sequential MAC**: 25× speedup for 5×5 matrix multiply
* **vs. Memory-based approach**: Lower bandwidth requirements, deterministic latency

**Design Pattern**:

```
Wave 1: A0 enters PE\[0,0], computes A0\*B0 (after B0 arrives)
Wave 2: A1 shifts to PE\[0,1], A0 to PE\[1,0]
...
Wave 25: Final result in all PEs
```

\---

### 3\. **LU Decomposition for Matrix Inversion**

**Why LU Instead of Other Methods?**

|Method|Pros|Cons|Choice|
|-|-|-|-|
|**LU**|Stable, reusable L and U|Requires 2 triangular solves|✓ Selected|
|**Gaussian Elimination**|Direct|Less numerically stable||
|**Adjugate/Determinant**|Conceptually simple|Numerically unstable||
|**Cholesky**|Efficient for symmetric|Only works for symmetric-positive-definite||
|**SVD**|Most stable|Expensive computation||

**LU Advantages for Hardware**:

1. **Numerical Stability**: Partial pivoting possible (though complex)
2. **Hardware FSM**: Clear sequence of operations (LU decomposition → forward subst. → backward subst.)
3. **Deterministic Cycles**: Fixed latency (not data-dependent)
4. **Parallelizable**: Inner loops can be partially parallelized
5. **Fixed-Point Friendly**: Division via reciprocal (single multiplication)

**Algorithm Implementation**:

```
Doolittle's Method (implemented):
For k=0 to 4:
    For i=k+1 to 4:
        L\[i,k] = U\[i,k] / U\[k,k]
        For j=k to 4:
            U\[i,j] = U\[i,j] - L\[i,k]\*U\[k,j]

Then Forward \& Backward Substitution:
    L\*Y = I (column-wise)
    U\*X = Y (column-wise)
    X = A^-1
```

**Fixed-Point Considerations**:

* Reciprocal: `1/x = 2⁴⁸ / x` (pre-scale to avoid underflow)
* Multiplication: Always right-shift by 24 bits
* Accumulation: Use 56-bit accumulators to prevent overflow

\---

### 4\. **Pipelined FIR Equalizer Architecture**

**Why Pipelined Design?**

|Stage|Purpose|Latency|
|-|-|-|
|Stage 1|RAM read historical taps|1 cycle|
|Stage 2|5 parallel multiplies|1 cycle|
|Stage 3|Add level 1 (2 adders)|1 cycle|
|Stage 4|Add level 2 (1 adder)|1 cycle|
|Stage 5|Final sum + output|1 cycle|
|**Total**||**5 cycles latency**|
|**Throughput**||**1 sample/cycle**|

**Advantages**:

* **Throughput**: Can process streaming input at 1 sample per clock (after pipeline filled)
* **Resource Reuse**: Single multiplier can handle all 5 taps (vs. 5 parallel multipliers)
* **Frequency**: Shorter combinational paths → higher clock frequency possible
* **Power**: Reduced switching activity compared to unpipelined design

**Alternative Approaches**:

* **Unpipelined**: 5 multiplies → 4 adds in single cycle (longer path, lower Fmax)
* **Fully Parallel**: 5 separate multipliers (more area, more power)

\---

### 5\. **Toeplitz Matrix Structure**

**Why This Structure Appears in ISI Mitigation?**

The received signal convolution with the FIR equalizer creates a Toeplitz structure naturally:

```
r\[n] = Σ u\[k] \* d\[n-k]  (convolution)
```

Writing 5 consecutive samples:

```
⎡r\[n]    ⎤     ⎡u\[0]  u\[-1] u\[-2] u\[-3] u\[-4]⎤
⎢r\[n+1] ⎥  =  ⎢u\[1]  u\[0]  u\[-1] u\[-2] u\[-3]⎥  (Toeplitz!)
⎣r\[n+4]⎦     ⎣u\[4]  u\[3]  u\[2]  u\[1]  u\[0] ⎦
```

**Properties Exploited**:

* Only need one row worth of data (15 samples from sampled\_effective\_u.txt)
* Automatically builds the full matrix using shifts
* Reduces memory requirements significantly

\---

### 6\. **Circular Buffer for Streaming FIR**

**Why Circular Buffer?**

In hardware streaming applications with FIR filters:

```
Traditional FIFO: Shift all 512 samples every cycle → expensive
Circular Buffer: Just increment write pointer \& compute addresses → efficient
```

**Address Calculation** (in `equalizer\_q8\_24.v`):

```verilog
addr1 = wr\_ptr - 100;  // T-100 delay
addr2 = wr\_ptr - 200;  // T-200 delay
...
```

**Advantages**:

* **No Shifting**: Pointer arithmetic only (O(1) operation)
* **RAM Efficient**: Distributed RAM works well
* **Bandwidth**: Constant bandwidth regardless of filter length
* **Latency**: Fixed by the tap spacing (100, 200, 300, 400 cycles)

\---

### 7\. **Hardware-Software Co-Design**

**Separation of Concerns**:

|Component|Domain|Why|
|-|-|-|
|Signal generation, channel model|MATLAB (Software)|Complex math, visualization, algorithm development|
|Integer/fixed-point arithmetic|Verilog (Hardware)|High performance, deterministic, synthesizable|
|Format conversion I/O|Testbench|Bridges software simulation and hardware|

**Benefits**:

* Algorithm validation (MATLAB) before hardware implementation
* Hardware focuses on performance-critical path
* File-based communication enables testing without RTL synthesis
* Allows FPGA/ASIC design to validate against reference

\---

### 8\. **Fixed-Point Reciprocal Calculation**

**Why Not Use Division Operator?**

```verilog
// Bad: Hardware division is expensive
bad\_result = 2^24 / x;  // Large latency, area

// Good: Use reciprocal lookup or approximation
recip = q8\_24\_recip(x);  // Pre-computed or iterative
result = (value \* recip) >> 24;
```

**Implementation in LU Module**:

```verilog
function signed \[31:0] q8\_24\_recip;
    input signed \[31:0] x;
    reg signed \[63:0] tmp;
    begin
        tmp = (64'sd1 <<< 48) / x;  // (2^48) / x = pre-shift to Q32.48
        q8\_24\_recip = tmp\[31:0];     // Extract Q8.24 result
    end
endfunction
```

**Rationale**:

* Single multiplication replaces expensive division
* Deterministic latency
* Easier to pipeline and parallelize
* Better for fixed-point arithmetic

\---

## Project Directory Structure

```
ZFE\_repo/
├── DOCUMENTATION \& REFERENCE
│   ├── README.md                              # This comprehensive documentation
│   ├── QUICK\_START.txt                        # Quick reference guide (3-phase workflow)
│   ├── Communication System Simulation.mlx    # MATLAB Live Script (dual-part)
│   │   └── Part 1 (Lines 1-135):   Signal generation \& channel simulation
│   │   └── Part 2 (Lines 136-155): Equalized signal reception \& display
│   └── VLSIDSP\_Q8\_24.mlx                     # MATLAB analysis of Q8.24 format
│
├── VERILOG HARDWARE - SYNTHESIZABLE MODULES
│   ├── lu\_inverse\_5x5\_q8\_24.v                # LU Decomposition for 5×5 matrix inversion
│   ├── systolic\_5x5\_q8\_24.v                  # 5×5 Systolic array for matrix multiplication
│   ├── pe\_q8\_24.v                            # Processing element (multiply-accumulate cell)
│   └── equalizer\_q8\_24.v                     # 5-tap FIR equalizer filter with circular buffer
│
├── VERILOG TESTBENCHES - NON-SYNTHESIZABLE
│   ├── tb\_complete\_zfe.v                     # Main orchestrator (top-level test environment)
│   ├── tb\_lu\_inverse\_5x5\_q8\_24.v             # LU module unit test
│   ├── tb\_pe\_q8\_24.v                         # PE module unit test
│   └── tb\_systolic\_5x5\_q8\_24.v               # Systolic array unit test
│
├── DATA FILES (Generated/Input)
│   ├── sampled\_effective\_u.txt               # Channel effective pulse samples (from MATLAB Part 1)
│   ├── rxfilter\_response.txt                 # Received signal before equalization (from MATLAB Part 1)
│   └── equalizer\_response.txt                # Equalized signal output (generated by Verilog simulation)
│
├── RESULTS \& OUTPUTS
│   ├── Results/
│   │   ├── Matlab Script Result.png          # MATLAB simulation output visualization
│   │   ├── RTL\_Schematic/                    # Synthesized RTL Diagrams
│   │   │   ├── Equalizer RTL Schematic.png
│   │   │   ├── LU inverse RTL Schematic.png
│   │   │   ├── Processing Element RTL Schematic.png
│   │   │   └── Systolic Array RTL Schematic.png
│   │   └── Simulation/                       # Simulation Waveforms \& Console Outputs
│   │       ├── complete\_zfe.txt              # Top-level simulation log
│   │       ├── lu\_inverse\_5x5\_q8\_24.txt      # LU module simulation log
│   │       ├── pe\_q8\_24.txt                  # Processing element simulation log
│   │       ├── systolic\_5x5\_q8\_24.txt        # Systolic array simulation log
│   │       ├── pe\_q8\_24\_simulation.png       # PE waveform screenshot
│   │       ├── lu\_inverse\_5x5\_q8\_24\_simulation\_1.png     # LU simulation waveform
│   │       ├── lu\_inverse\_5x5\_q8\_24\_simulation 2.png     # LU simulation waveform (alternate)
│   │       ├── systolic\_5x5\_q8\_24 Simulation.png         # Systolic array waveform
│   │       └── zfe\_complete\_simulation.png   # Complete system waveform
│   └── equalizer\_4.zip                       # Archive of previous implementation version
```

\---

## Workflow for Users

### Step-by-Step Execution Guide

#### **Phase 1: MATLAB Signal Generation** (15-20 minutes)

1. **Open MATLAB**

```
   File → Open → Communication System Simulation.mlx
   ```

2. **Run Part 1 Only** (Lines 1-135)

```
   Select lines 1-135
   Press Ctrl+Enter to run selected section
   ```

3. **Expected Output**:

   * Multiple plots showing:

     * Binary representation of message
     * BRZ encoded signal
     * SRRC pulse shape
     * Channel impulse response
     * Channel output (distorted signal)
     * Receiver filter output
     * Effective pulse response
   * Two files created:

     * `sampled\_effective\_u.txt` (15 decimal values)
     * `rxfilter\_response.txt` (\~70,000 decimal values)
   * Message before equalization (corrupted, may show garbled text)
4. **Keep MATLAB Open** (need it later for Part 2)

#### **Phase 2: Verilog Hardware Simulation** (30-45 minutes)

1. **Open Vivado or Your Verilog Simulator** (Vivado, ModelSim, VCS, etc.)
2. **Create Vivado Project** (if using Vivado):

```
   File → Create Project
   Project name: ZFE\_Equalizer
   Add RTL Sources: Add all .v files from ZFE\_repo/
   ```

3. **Update File Paths in tb\_complete\_zfe.v**:

```verilog
   // Line 108 \& 189: Change these paths to your system
   data\_file\_in = $fopen("E:/Verilog/...", "r");  // CHANGE THIS
   ```

   Update to:

   ```verilog
   data\_file\_in = $fopen("C:/Users/a1246401/pptx\_slides/ZFE\_repo/sampled\_effective\_u.txt", "r");
   ```

4. **Run Simulation**:

   ```
   Simulation → Run Behavioral Simulation
   ```

5. **Expected Simulation Output**:

   * Prints to console:

   ```
     --- Original Matrix A (Real Format) ---
     \[5x5 Toeplitz matrix values]

     --- Inverse Matrix A^-1 (Real Format) ---
     \[5x5 inverse matrix values]

     --- Calculated ZFE Weights (Real Format) ---
     w0: ..., w1: ..., w2: ..., w3: ..., w4: ...

     Starting Hardware Equalization Stream...
     Equalization Complete. All data processed and output written.
     ```

6. **Output File Generated**:

   * `equalizer\_response.txt` (\~70,000 decimal values)
   * Contains equalized signal ready for bit detection

   #### **Phase 3: MATLAB Signal Reception** (5 minutes)

1. **In MATLAB, Run Part 2 Only** (Lines 136-155)

   ```
   Select lines 136-155
   Press Ctrl+Enter
   ```

2. **Expected Output**:

   ```
   stringDataAfterEqualizer =
   "Hello, This is my first message over this communication simulation! I am Rishi Gupta"
   ```

   (Should exactly match original input message)

3. **Comparison**:

   * Before equalization (Part 1): Corrupted/garbled message
   * After equalization (Part 2): Perfect message recovery

   \---

   ### Troubleshooting Common Issues

|Issue|Cause|Solution|
|-|-|-|
|Files not found in Verilog|Wrong path in tb\_complete\_zfe.v line 108, 189|Update absolute paths to match your system|
|Simulation hangs|File path is wrong or files don't exist|Check that sampled\_effective\_u.txt and rxfilter\_response.txt exist|
|MATLAB can't read equalizer\_response.txt|Verilog simulation didn't complete|Ensure Vivado simulation ran until "$finish" message|
|Recovered message is corrupted|equalizer\_response.txt is empty or wrong|Check file writing in tb\_complete\_zfe.v lines 92-96|
|Compile errors in Verilog|Module dependencies not in correct order|Ensure all .v files added before tb\_complete\_zfe.v|

\---

## Key Technical Concepts

### 1\. **Inter-Symbol Interference (ISI)**

**Definition**: When transmitted symbols overlap in time due to channel dispersion

**Mathematical Model**:

```
r(t) = Σ d\[k] · h(t - k·T) + n(t)
       k
```

Where: d\[k] = transmitted symbol, h(t) = channel impulse response, T = symbol period

**Effects**:

* Prevents simple threshold detection
* Increases bit error rate exponentially with ISI severity
* Requires equalization for reliable communication

\---

### 2\. **SRRC Pulse Shaping**

**Why SRRC (Square Root Raised Cosine)?**

* Matched filter at receiver (minimum noise sensitivity)
* When combined with channel, reduced out-of-band interference
* Raised Cosine together: P\_tx \* Channel \* P\_rx = Raised Cosine response

**Roll-off Factor (0.25)**:

* Trade-off between bandwidth efficiency and ISI performance
* Lower value = narrower bandwidth but more ISI
* Higher value = wider bandwidth but less ISI

\---

### 3\. **Toeplitz Convolution Matrix**

**Structure**:

```
⎡u\[0]  u\[-1] u\[-2]⎤
⎢u\[1]  u\[0]  u\[-1]⎥
⎣u\[2]  u\[1]  u\[0] ⎦
```

**Property**: Each diagonal contains same value (constant diagonals)

**Advantage for ISI Equalization**:

* Captures the convolution operation as matrix-vector product
* Converts **nonlinear ISI problem** into **linear algebra problem**
* Only 15 samples needed to build entire 5×5 matrix

\---

### 4\. **Zero Forcing Condition**

**Constraint**: Combined channel + equalizer impulse response must be:

```
δ\[n] = {1 if n=0, 0 otherwise}
```

**Implications**:

* **Advantage**: Complete ISI elimination (perfect at zero-forcing points)
* **Disadvantage**: Noise amplification (if channel is notchy)
* **Trade-off**: Zero-forcing vs. MMSE equalizers (MMSE better with noise, but more complex)

\---

### 5\. **Systolic Dataflow in Matrix Multiplication**

**Key Insight**:

```
Normal approach:  Load row of A, multiply with all columns of B (sequential)
Systolic approach: Load row of A, load column of B, stream both (parallel)
```

**Result**: All 25 multiplications happen **in parallel**, reducing latency from O(N³) to O(N)

\---

### 6\. **Fixed-Point Precision Tradeoffs**

**Q8.24 Analysis**:

* **Precision**: 2⁻²⁴ ≈ 6 × 10⁻⁸ (very good)
* **Range**: ±2⁷ = ±128 (sufficient for normalized signals)
* **Total Bits**: 32 (standard word size)

**Quantization Error**:

* Each arithmetic operation introduces rounding error
* Error grows with number of operations
* For this application (\~500 multiplications): Error < 0.1% typical

\---

### 7\. **Numerical Stability in LU Decomposition**

**Challenge**: Without pivoting, small diagonal elements cause large reciprocals

**Implemented Solution**: Direct Doolittle's method (no pivoting)

* Works well for Toeplitz channel matrices (well-conditioned typically)
* If channel is very distorted, add pivoting to LU algorithm

**Fixed-Point Consideration**:

* Reciprocal computation must have sufficient pre-scaling
* Current: `tmp = (2⁴⁸) / x` prevents underflow

\---

## Performance Considerations

### 1\. **Latency Analysis**

```
Component                          Latency (cycles)
─────────────────────────────────────────────────
LU Decomposition (5×5 matrix)      \~100 cycles
Systolic Array (5×5 multiply)      \~25 cycles
Equalizer (5-tap FIR)              \~5 cycles/sample
─────────────────────────────────────────────────
Total Setup Time                   \~130 cycles
Streaming Throughput               1 sample/cycle (after setup)
```

### 2\. **Area \& Resource Utilization**

|Module|LUTs|DSPs|RAM|Description|
|-|-|-|-|-|
|LU Inverse|\~2000|5|0|Mainly control logic \& reciprocal calc|
|Systolic Array|\~3000|25|0|25 multiply-accumulators in parallel|
|PE (single)|\~120|1|0|Simple multiply \& accumulate|
|Equalizer|\~1500|5|2|5 mult, 4 adders, circular buffer|
|**Total**|**\~6500**|**35**|**2 blocks**|Typical FPGA implementation|

### 3\. **Power Consumption**

Estimated power (at 100 MHz, 28nm CMOS):

* **Dynamic**: \~50 mW (depends on switching activity)
* **Leakage**: \~5 mW
* **Total**: \~55 mW (Very low for signal processing)

### 4\. **Frequency Scaling**

**Critical Path** (longest timing path):

* Usually in adder tree of equalizer or multiplier in LU
* Typical critical path: \~3 adders + 1 multiplier delay
* Can achieve: 200+ MHz in modern FPGA/ASIC

\---

## Advanced Topics

### 1\. **Why This ISI Channel Model?**

The chosen channel: `h = \[1, 0.75, 0.25]` represents:

* 1 unit (100%): Direct path signal
* 0.75 unit (75%): First reflection (1 symbol delay)
* 0.25 unit (25%): Second reflection (2 symbol delays)

This is realistic for:

* Indoor wireless (multipath propagation)
* Underwater acoustic channels
* Fiber optic dispersion

\---

### 2\. **Extension to 8-Tap or 16-Tap Equalizers**

Current implementation is 5-tap. To extend:

1. **Modify sampled\_effective\_u.txt**: Read 21 or 37 samples (2N+1)
2. **Create NxN variants**: `lu\_inverse\_8x8\_q8\_24.v`, `systolic\_8x8\_q8\_24.v`
3. **Update equalizer**: Increase RAM size and tap delays
4. **MATLAB**: Adjust sampling to match new tap count

### 3\. **Adaptive Equalization**

Current: **Fixed weights** (pre-computed once)

For **adaptive** equalization:

* Continuously update weights based on received signal
* Use LMS (Least Mean Squares) algorithm
* Requires feedback path and gradient computation
* More complex but better performance with time-varying channels

### 4\. **MMSE vs. Zero Forcing**

|Criterion|Zero Forcing|MMSE|
|-|-|-|
|ISI elimination|Perfect at 5 points|Optimal average|
|Noise amplification|High|Controlled|
|Complexity|Medium|High|
|Implementation|This project|Requires matrix inversion of larger matrix|
|Use Case|Low noise channels|Noisy channels|

\---

### 5\. **FPGA vs. ASIC Implementation**

**FPGA Implementation** (Current):

* Xilinx Vivado/ISE or Intel Quartus
* Instant prototyping and testing
* Reconfigurable
* Higher power per operation

**ASIC Implementation** (Future):

* Better performance (lower latency, higher frequency)
* Lower power per operation
* Fixed functionality
* Expensive NRE (Non-Recurring Engineering) cost

\---

## References \& Further Reading

### Key Concepts

1. **Digital Communications**: Proakis \& Salehi, "Digital Communications" (Chapter 10: ISI)
2. **Signal Processing**: Oppenheim \& Schafer, "Discrete-Time Signal Processing"
3. **VLSI Design**: Razavi, "Design of Analog CMOS Integrated Circuits"

### Fixed-Point Arithmetic

* Texas Instruments Application Note: "Fixed-Point Math"
* "Q Format" technical specifications in industry standards

### Hardware Implementation

* Xilinx Documentation: "Vivado Design Suite"
* Verilog HDL Reference (IEEE 1364)

\---

## Detailed Mathematics (for reference)

### 1\. System Model: Convolution and ISI

When a symbol pulse p(t) passes through the channel h(t) and receiver filter p(t) again, the effective pulse becomes:

```
u(t) = p(t) \* h(t) \* p(t)
```

Sampling at symbol rate Ts gives discrete samples: u\[0], u\[1], ..., u\[N-1]

For our specific channel: u(t) is NOT a Kronecker delta but has significant "tails"

### 2\. Linear System Formation

Consider transmitting symbols d₀, d₁, d₂, ... through the effective channel. The received sample at time nTs is:

```
r\[n] = Σ(k=-∞ to ∞) d\[k] · u\[n - k]
```

For a 5-tap equalizer operating on 5 consecutive received samples r\[n], r\[n+1], ..., r\[n+4], we can write:

```
⎡r\[n]    ⎤     ⎡u\[0]  u\[-1] u\[-2] u\[-3] u\[-4]⎤  ⎡w₀⎤
⎢r\[n+1] ⎥  =  ⎢u\[1]  u\[0]  u\[-1] u\[-2] u\[-3]⎥ · ⎢w₁⎥
⎢r\[n+2] ⎥     ⎢u\[2]  u\[1]  u\[0]  u\[-1] u\[-2]⎥  ⎢w₂⎥
⎢r\[n+3] ⎥     ⎢u\[3]  u\[2]  u\[1]  u\[0]  u\[-1]⎥  ⎢w₃⎥
⎣r\[n+4]⎦     ⎣u\[4]  u\[3]  u\[2]  u\[1]  u\[0] ⎦  ⎣w₄⎦
```

This is the **Toeplitz structure**: each row is a shifted version of the effective pulse.

### 3\. Matrix Inverse Solution

To solve **P · w = d**, we multiply both sides by P⁻¹:

```
w = P⁻¹ · d = P⁻¹ · \[1, 0, 0, 0, 0]ᵀ
```

This extracts the **first column of the inverse matrix P⁻¹**.

**Why LU Decomposition?**

* Decomposes: P = L · U (Lower triangular × Upper triangular)
* Solves P⁻¹ using two triangular solves (Forward \& Backward substitution)
* Numerically stable and hardware-efficient

### 4\. Fixed-Point Arithmetic: Q8.24 Format

**Format Definition**:

* Total bits: 32
* Bit layout: \[Sign:1bit] \[Integer:7bits] \[Fraction:24bits]
* Scaling factor: SF = 2²⁴ = 16,777,216
* Real value 1.0 is represented as 16,777,216

**Encoding real to Q8.24**:

```
Q8.24\_value = round(real\_value × 2²⁴)
```

**Decoding Q8.24 to real**:

```
real\_value = Q8.24\_value / 2²⁴
```

**Arithmetic Operations in Q8.24**:

* Addition: Direct (Q8.24 + Q8.24 = Q8.24)
* Multiplication: Requires right-shift by 24 bits

```
  result\_q8\_24 = (operand1\_q8\_24 × operand2\_q8\_24) >> 24
  ```

* Division: Multiply by reciprocal (pre-computed)

### 5\. Zero Forcing Impulse Response

After equalization, the combined response P · w yields:

```
output\[0] = 1.0  (main symbol, perfectly recovered)
output\[1] = 0.0  (ISI from next symbol eliminated)
output\[2] = 0.0  (ISI from symbol+2 eliminated)
output\[3] = 0.0  (ISI from symbol+3 eliminated)
output\[4] = 0.0  (ISI from symbol+4 eliminated)
```

This is the **Zero Forcing condition**: forced zeros at all except the main tap.

\---

## Contact \& Support

For questions or issues regarding this project:

1. Check troubleshooting section above
2. Verify all file paths match your system
3. Ensure MATLAB and Verilog simulator versions are compatible
4. Review intermediate outputs (console prints, waveforms)

\---

**Project Version**: 1.0
**Last Updated**: March 2026
**Status**: Complete \& Verified

