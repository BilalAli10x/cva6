// SPDX-License-Identifier: MIT
//
// MII (10/100) Ethernet front-end for the Digilent Arty A7-100T.
//
// Wraps verilog-ethernet's MII MAC + async FIFOs (eth_mac_mii_fifo) behind
// the AXI-Stream interface framing_top_mii expects. The MAC-side AXI-Stream
// ports are in clk_int (25 MHz); the FIFOs cross into the PHY's MII TX/RX
// clock domains. Frames up to 1518 bytes need FIFOs deeper than one frame
// (store-and-forward).

module mii_soc (
  input  wire        clk_int,
  input  wire        rst_int,

  // MII PHY
  input  wire        phy_rx_clk,
  input  wire [3:0]  phy_rxd,
  input  wire        phy_rx_ctl,   // RX_DV
  input  wire        phy_rxer,     // RX_ER
  input  wire        mii_tx_clk,   // TX_CLK from PHY
  output wire [3:0]  phy_txd,
  output wire        phy_tx_ctl,   // TX_EN
  output wire        phy_reset_n,
  output wire        rx_clk,

  // AXI-Stream (logic clock domain)
  input  wire        tx_axis_tvalid,
  input  wire        tx_axis_tlast,
  input  wire [7:0]  tx_axis_tdata,
  output wire        tx_axis_tready,
  input  wire        tx_axis_tuser,

  output wire [7:0]  rx_axis_tdata,
  output wire        rx_axis_tvalid,
  output wire        rx_axis_tlast,
  output wire        rx_axis_tuser,

  output wire [31:0] rx_fcs_reg,
  output wire [31:0] tx_fcs_reg
);

  wire        mii_tx_en;
  wire        mii_tx_er;

  assign phy_reset_n    = ~rst_int;
  // The FIFOs hand both AXI-Stream directions over in clk_int, so
  // framing_top's RX logic must run in clk_int as well (not phy_rx_clk).
  assign rx_clk         = clk_int;

  // framing_top was written for a bare MAC: it advances its TX address on
  // tready even when tvalid is low and keeps tvalid high for a few cycles
  // after tlast. Gate tready with tvalid and swallow the trailing beats so
  // only the real frame enters the TX FIFO.
  wire        tx_fifo_tready;
  reg         tx_drain = 1'b0;
  wire        tx_fifo_tvalid = tx_axis_tvalid & ~tx_drain;
  assign tx_axis_tready = tx_fifo_tready & tx_fifo_tvalid;

  always @(posedge clk_int) begin
    if (rst_int || !tx_axis_tvalid)
      tx_drain <= 1'b0;
    else if (tx_axis_tready && tx_axis_tlast)
      tx_drain <= 1'b1;
  end

  // framing_top needs an inter-frame gap to advance its RX buffer pointer
  // (the MAC used to guarantee one; the FIFO can emit frames back to back).
  wire        rx_fifo_tvalid;
  wire        rx_fifo_tlast;
  reg  [5:0]  rx_gap = 6'd0;
  wire        rx_fifo_tready = (rx_gap == 6'd0);
  assign rx_axis_tvalid = rx_fifo_tvalid & rx_fifo_tready;
  assign rx_axis_tlast  = rx_fifo_tlast & rx_axis_tvalid;

  always @(posedge clk_int) begin
    if (rst_int)
      rx_gap <= 6'd0;
    else if (rx_axis_tvalid && rx_axis_tlast)
      rx_gap <= 6'd32;
    else if (rx_gap != 6'd0)
      rx_gap <= rx_gap - 1'b1;
  end
  assign rx_fcs_reg     = 32'd0;
  assign tx_fcs_reg     = 32'd0;

  eth_mac_mii_fifo #(
    .TARGET            ("XILINX"),
    .CLOCK_INPUT_STYLE ("BUFG"),
    .ENABLE_PADDING    (1),
    .MIN_FRAME_LENGTH  (64),
    .TX_FIFO_DEPTH     (4096),
    .RX_FIFO_DEPTH     (4096)
  ) i_eth_mac_mii_fifo (
    .rst        (rst_int),
    .logic_clk  (clk_int),
    .logic_rst  (rst_int),

    .tx_axis_tdata  (tx_axis_tdata),
    .tx_axis_tkeep  (1'b1),
    .tx_axis_tvalid (tx_fifo_tvalid),
    .tx_axis_tready (tx_fifo_tready),
    .tx_axis_tlast  (tx_axis_tlast),
    .tx_axis_tuser  (tx_axis_tuser),

    .rx_axis_tdata  (rx_axis_tdata),
    .rx_axis_tkeep  (),
    .rx_axis_tvalid (rx_fifo_tvalid),
    .rx_axis_tready (rx_fifo_tready),
    .rx_axis_tlast  (rx_fifo_tlast),
    .rx_axis_tuser  (rx_axis_tuser),

    .mii_rx_clk (phy_rx_clk),
    .mii_rxd    (phy_rxd),
    .mii_rx_dv  (phy_rx_ctl),
    // RX_ER is ignored: the DP83848J flags it on good frames from some link
    // partners. The MAC's FCS check still drops corrupted frames.
    .mii_rx_er  (1'b0),
    .mii_tx_clk (mii_tx_clk),
    .mii_txd    (phy_txd),
    .mii_tx_en  (mii_tx_en),
    .mii_tx_er  (mii_tx_er),

    .tx_error_underflow (),
    .tx_fifo_overflow   (),
    .tx_fifo_bad_frame  (),
    .tx_fifo_good_frame (),
    .rx_error_bad_frame (),
    .rx_error_bad_fcs   (),
    .rx_fifo_overflow   (),
    .rx_fifo_bad_frame  (),
    .rx_fifo_good_frame (),

    .cfg_ifg      (8'd12),
    .cfg_tx_enable(1'b1),
    .cfg_rx_enable(1'b1)
  );

  assign phy_tx_ctl = mii_tx_en;

endmodule
