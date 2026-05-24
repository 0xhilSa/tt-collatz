`timescale 1ns/1ps
`default_nettype none

module tb_collatz_waves;
  reg  [7:0] ui_in;
  wire [7:0] uo_out;
  reg  [7:0] uio_in;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;
  reg        ena, clk, rst_n;

  wire [1:0] fsm_state    = dut.state;
  wire [23:0] n_current   = dut.n;
  wire [15:0] n_assembled = dut.n_input;
  wire        n_is_odd    = dut.n_is_odd;
  wire [3:0]  shift_amt   = dut.shift_amt;
  wire [7:0]  step_count  = dut.step_count;
  wire        done_flag   = uio_out[2];
  wire        ovf_flag    = uio_out[3];
  wire        ctrl_load_h = uio_in[0];
  wire        ctrl_start  = uio_in[1];

  tt_um_collatz_0xhilSa dut(
    .ui_in(ui_in), .uo_out(uo_out),
    .uio_in(uio_in), .uio_out(uio_out), .uio_oe(uio_oe),
    .ena(ena), .clk(clk), .rst_n(rst_n)
  );

  initial clk = 0;
  always #50 clk = ~clk;

  initial begin
    $dumpfile("collatz_waves.vcd");
    $dumpvars(0, tb_collatz_waves);   // dump everything
  end

  task load_and_run;
    input [15:0] n;
    input [7:0]  expected;
    integer t_start, timeout;
    begin
      $display("\n[%0t ns] === {START: n = %0d} ===================", $time/1000, n);

      // ── Phase 1: load low byte ────────────────────────────────
      @(negedge clk);
      ui_in = n[7:0];
      uio_in = 8'b00000000;   // load_high=0, start=0
      ena = 1;
      @(posedge clk); #1;
      $display("[%0t ns] LOAD LOW  byte=0x%02h  n_input=0x%04h  state=%0d", $time/1000, ui_in, n_assembled, fsm_state);

      // ── Phase 2: load high byte ───────────────────────────────
      @(negedge clk);
      ui_in = n[15:8];
      uio_in = 8'b00000001;   // load_high=1
      @(posedge clk); #1;
      $display("[%0t ns] LOAD HIGH byte=0x%02h  n_input=0x%04h  state=%0d", $time/1000, ui_in, n_assembled, fsm_state);

      // ── Phase 3: pulse start ──────────────────────────────────
      @(negedge clk);
      uio_in = 8'b00000010;   // start=1
      @(posedge clk); #1;
      $display("[%0t ns] START     n=%0d  state=%0d", $time/1000, n_current, fsm_state);
      uio_in = 8'b00000000;

      // ── Phase 4: watch iterations ─────────────────────────────
      t_start = $time;
      timeout = 20000;
      while(!done_flag && timeout > 0) begin
        @(posedge clk); #1;
        if(fsm_state == 2) begin
          if(n_is_odd)
            $display("[%0t ns]  ODD  n=%-8d → (3n+1)/2=%-8d\tsteps=%0d", $time/1000, n_current, dut.n_odd, step_count);
          else
            $display("[%0t ns]  EVEN n=%-8d >> %0d     → %-8d\tsteps=%0d", $time/1000, n_current, shift_amt, dut.n_even, step_count);
        end
        timeout = timeout - 1;
      end

      // ── Phase 5: read result ──────────────────────────────────
      if(timeout == 0) begin
        $display("[%0t ns] TIMEOUT! n=%0d never finished", $time/1000, n);
      end else begin
        $display("[%0t ns] DONE     result=%0d  expected=%0d  ovf=%b  %s", $time/1000, uo_out, expected, ovf_flag, (uo_out == expected) ? "\tPASS" : "\tFAIL");
        $display("[%0t ns]          cycles in RUN state = %0d", $time/1000, (($time - t_start) / 100));
      end

      // ── Gap between test cases ────────────────────────────────
      repeat(8) @(posedge clk);
    end
  endtask

  // ── Main test sequence ────────────────────────────────────────────────
  initial begin
    rst_n=0; ena=0; ui_in=0; uio_in=0;
    repeat(5) @(posedge clk);
    rst_n=1;
    repeat(3) @(posedge clk);

    $display("+==========================================+");
    $display("|  Collatz Waveform Testbench              |");
    $display("|  Open collatz_waves.vcd in GTKWave       |");
    $display("+==========================================+");

    load_and_run(16'd1,   8'd0);
    load_and_run(16'd2,   8'd1);
    load_and_run(16'd3,   8'd7);
    load_and_run(16'd6,   8'd8);
    load_and_run(16'd7,   8'd16);

    load_and_run(16'd27,  8'd111);

    load_and_run(16'd871, 8'd178);

    $display("\n[%0t ns] All tests complete.", $time/1000);
    $display("GTKWave tip: zoom to any DONE pulse and trace");
    $display("  n_current backwards to see the full trajectory.");
    $finish;
  end

endmodule
