/*
 * Copyright (c) 2026 Sahil Rajwar
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_collatz_0xhilSa(
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);
  wire load_high = uio_in[0];
  wire start = uio_in[1];

  localparam IDLE = 2'd0,
             LOAD = 2'd1,
             RUN  = 2'd2,
             DONE = 2'd3;

  reg [1:0] state;

  reg [23:0] n;
  reg [15:0] n_input;
  reg [7:0]  step_count;
  reg        overflow;
  reg        done;

  function [3:0] ctz8;
    input [7:0] bits;
    casez (bits)
      8'bxxxxxxx1: ctz8 = 4'd0;
      8'bxxxxxx10: ctz8 = 4'd1;
      8'bxxxxx100: ctz8 = 4'd2;
      8'bxxxx1000: ctz8 = 4'd3;
      8'bxxx10000: ctz8 = 4'd4;
      8'bxx100000: ctz8 = 4'd5;
      8'bx1000000: ctz8 = 4'd6;
      8'b10000000: ctz8 = 4'd7;
      8'b00000000: ctz8 = 4'd8;
      default:     ctz8 = 4'd1;
    endcase
  endfunction

  wire n_is_odd  = n[0];
  wire [3:0] shift_amt = ctz8(n[7:0]);
  wire [23:0] n_even = n >> shift_amt;

  wire [24:0] n_odd_full = {1'b0, n} + {1'b0, n[23:1]} + 25'd1;
  wire [23:0] n_odd = n_odd_full[23:0];
  wire        odd_ovf = n_odd_full[24];
  wire [3:0] step_inc = n_is_odd ? 4'd2 : shift_amt;

  always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      state <= IDLE;
      n <= 24'd0;
      n_input <= 16'd0;
      step_count <= 8'd0;
      overflow <= 1'b0;
      done <= 1'b0;
    end else begin
      case(state)
        IDLE: begin
          done <= 1'b0;
          overflow <= 1'b0;
          if(ena) begin
            if(!load_high)
              n_input[7:0]  <= ui_in;
            else begin
              n_input[15:8] <= ui_in;
              state <= LOAD;
            end
          end
        end

        LOAD: begin
          if(start) begin
            n <= {8'd0, n_input};
            step_count <= 8'd0;
            state <= RUN;
          end
        end

        RUN: begin
          if(n <= 24'd1) begin
            state <= DONE;
            done  <= 1'b1;
          end else begin
            n <= n_is_odd ? n_odd : n_even;
            if(step_count + {4'd0, step_inc} > 9'd255)
              step_count <= 8'd255;
            else
              step_count <= step_count + {4'd0, step_inc};
            if(n_is_odd && odd_ovf)
              overflow <= 1'b1;
          end
        end

        DONE: begin
          done <= 1'b1;
          state <= IDLE;
        end
      endcase
    end
  end

  assign uo_out = step_count;
  assign uio_out = {4'b0000, overflow, done, 2'b00};
  assign uio_oe = 8'b00001100;
endmodule
