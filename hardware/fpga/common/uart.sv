//
// Copyright 2011-2015 Jeff Bush
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

//
// Serial port interface.
//

module uart
    #(parameter BASE_ADDRESS = 0,
    parameter CLOCKS_PER_BIT = 1)

    (input                    clk,
    input                     reset,

    // IO bus interface
    io_bus_interface.slave    io_bus,

    // UART interface
    output                    uart_tx,
    input                     uart_rx);

    localparam STATUS_REG = BASE_ADDRESS;
    localparam RX_REG = BASE_ADDRESS + 4;
    localparam TX_REG = BASE_ADDRESS + 8;
    localparam FIFO_LENGTH = 8;

    /*AUTOLOGIC*/
    // Beginning of automatic wires (for undeclared instantiated-module outputs)
    logic               rx_char_valid;          // From uart_receive of uart_receive.v
    logic               tx_ready;               // From uart_transmit of uart_transmit.v
    // End of automatics
    logic[7:0] rx_fifo_char;
    logic rx_fifo_empty;
    logic rx_fifo_read;
    logic rx_fifo_full;
    logic rx_fifo_overrun;
    logic rx_fifo_overrun_dq;
    logic rx_fifo_frame_error;

    logic[7:0] rx_char;
    logic rx_frame_error;
    logic tx_enable;

    assign tx_enable = io_bus.write_en && io_bus.address == TX_REG;

    uart_transmit #(.CLOCKS_PER_BIT(CLOCKS_PER_BIT)) uart_transmit(
        .tx_char(io_bus.write_data[7:0]),
        .*);

    uart_receive #(.CLOCKS_PER_BIT(CLOCKS_PER_BIT)) uart_receive(.*);

    assign rx_fifo_read = io_bus.address == RX_REG && io_bus.read_en;

    // Logic for Overrun Error (OE) bit
    always_ff @(posedge clk, posedge reset)
    begin
        if (reset)
        begin
            rx_fifo_overrun <= 0;
        end
        else
        begin
            case (io_bus.address)
                STATUS_REG:
                begin
                    io_bus.read_data[31:4] <= 0;
                    io_bus.read_data[3:0] <= {rx_fifo_frame_error, rx_fifo_overrun, !rx_fifo_empty, tx_ready};
                end
                default:
                begin
                    io_bus.read_data[31:8] <= 0;
                    io_bus.read_data[7:0] <= rx_fifo_char;
                end
            endcase

            if (rx_fifo_read)
                rx_fifo_overrun <= 0;
            if (rx_char_valid && rx_fifo_full)
                rx_fifo_overrun <= 1;
        end
    end

    always_comb
    begin
        if (rx_char_valid && rx_fifo_full)
            rx_fifo_overrun_dq = 1;
        else
            rx_fifo_overrun_dq = 0;
    end

    // Up to ALMOST_FULL_THRESHOLD characters can be filled. FIFO is
    // automatically dequeued and OE bit is asserted when a character is queued
    // after this point. The OE bit is deasserted when rx_fifo_read or the
    // number of stored characters is lower than the threshold.
    sync_fifo #(.WIDTH(9), .SIZE(FIFO_LENGTH),
        .ALMOST_FULL_THRESHOLD(FIFO_LENGTH - 1))
        rx_fifo(
        .clk(clk),
        .reset(reset),
        .almost_empty(),
        .almost_full(rx_fifo_full),
        .full(),
        .empty(rx_fifo_empty),
        .value_o({rx_fifo_frame_error, rx_fifo_char}),
        .enqueue_en(rx_char_valid),
        .flush_en(1'b0),
        .value_i({rx_frame_error, rx_char}),
        .dequeue_en(rx_fifo_read || rx_fifo_overrun_dq));
endmodule

// Local Variables:
// verilog-library-flags:("-y ../../core" "-y ../../testbench")
// verilog-typedef-regexp:"_t$"
// verilog-auto-reset-widths:unbased
// End:
