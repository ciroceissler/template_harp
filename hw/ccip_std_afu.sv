//
// Copyright (c) 2017, Intel Corporation
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// Redistributions of source code must retain the above copyright notice, this
// list of conditions and the following disclaimer.
//
// Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation
// and/or other materials provided with the distribution.
//
// Neither the name of the Intel Corporation nor the names of its contributors
// may be used to endorse or promote products derived from this software
// without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

import ccip_if_pkg::*;

module ccip_std_afu
(
    // CCI-P Clocks and Resets
    input  logic         pClk,               // 400MHz - CCI-P clock domain. Primary interface clock
    input  logic         pClkDiv2,           // 200MHz - CCI-P clock domain.
    input  logic         pClkDiv4,           // 100MHz - CCI-P clock domain.
    input  logic         uClk_usr,           // User clock domain. Refer to clock programming guide  ** Currently provides fixed 300MHz clock **
    input  logic         uClk_usrDiv2,       // User clock domain. Half the programmed frequency  ** Currently provides fixed 150MHz clock **
    input  logic         pck_cp2af_softReset,// CCI-P ACTIVE HIGH Soft Reset
    input  logic [1:0]   pck_cp2af_pwrState, // CCI-P AFU Power State
    input  logic         pck_cp2af_error,    // CCI-P Protocol Error Detected

    // Interface structures
    input  t_if_ccip_Rx  pck_cp2af_sRx,      // CCI-P Rx Port
    output t_if_ccip_Tx  pck_af2cp_sTx       // CCI-P Tx Port
);


    // register map to HardCloud
    localparam CSR_AFU_DSM_BASEL = 16'h110; // 32b - RW  Lower 32-bits of AFU DSM base address
    localparam CSR_SRC_ADDR      = 16'h120; // 64b - RW  Reads are targetted to this region
    localparam CSR_DST_ADDR      = 16'h128; // 64b - RW  Writes are targetted to this region
    localparam CSR_NUM_LINES     = 16'h130; // 32b - RW  Numbers of cache lines to be rd
    localparam CSR_CTL           = 16'h138; // 32b - RW  Control CSR to start n stop the test

    // CSR_CTL actions
    localparam CTL_ASSERT_RST   = 32'h0000;
    localparam CTL_DEASSERT_RST = 32'h0001;
    localparam CTL_START        = 32'h0003;
    localparam CTL_STOP         = 32'h0007;

    // address used in DSM
    localparam DSM_RUN_COMPLETE = 16'h40 >> 6;

    //
    // Run the entire design at the standard CCI-P frequency (400 MHz).
    //
    logic clk;
    assign clk = pClk;

    logic reset;
    assign reset = pck_cp2af_softReset;


    // =========================================================================
    //
    //   Register requests.
    //
    // =========================================================================

    //
    // The incoming pck_cp2af_sRx and outgoing pck_af2cp_sTx must both be
    // registered.  Here we register pck_cp2af_sRx and assign it to sRx.
    // We also assign pck_af2cp_sTx to sTx here but don't register it.
    // The code below never uses combinational logic to write sTx.
    //

    t_if_ccip_Rx sRx;
    always_ff @(posedge clk)
    begin
        sRx <= pck_cp2af_sRx;
    end

    t_if_ccip_Tx sTx;
    assign pck_af2cp_sTx = sTx;


    // =========================================================================
    //
    //   CSR (MMIO) handling.
    //
    // =========================================================================

    // The AFU ID is a unique ID for a given program.  Here we generated
    // one with the "uuidgen" program.
    logic [127:0] afu_id = 128'hC6AA954A_9B91_4A37_ABC1_1D9F0709DCC3;

    //
    // A valid AFU must implement a device feature list, starting at MMIO
    // address 0.  Every entry in the feature list begins with 5 64-bit
    // words: a device feature header, two AFU UUID words and two reserved
    // words.
    //

    // Is a CSR read request active this cycle?
    logic is_csr_read;
    assign is_csr_read = sRx.c0.mmioRdValid;

    // Is a CSR write request active this cycle?
    logic is_csr_write;
    assign is_csr_write = sRx.c0.mmioWrValid;

    // The MMIO request header is overlayed on the normal c0 memory read
    // response data structure.  Cast the c0Rx header to an MMIO request
    // header.
    t_ccip_c0_ReqMmioHdr mmio_req_hdr;
    assign mmio_req_hdr = t_ccip_c0_ReqMmioHdr'(sRx.c0.hdr);


    //
    // Implement the device feature list by responding to MMIO reads.
    //

    always_ff @(posedge clk)
    begin
        if (reset)
        begin
            sTx.c2.mmioRdValid <= 1'b0;
        end
        else
        begin
            // Always respond with something for every read request
            sTx.c2.mmioRdValid <= is_csr_read;

            // The unique transaction ID matches responses to requests
            sTx.c2.hdr.tid <= mmio_req_hdr.tid;

            // Addresses are of 32-bit objects in MMIO space.  Addresses
            // of 64-bit objects are thus multiples of 2.
            case (mmio_req_hdr.address)
              0: // AFU DFH (device feature header)
                begin
                    // Here we define a trivial feature list.  In this
                    // example, our AFU is the only entry in this list.
                    sTx.c2.data <= t_ccip_mmioData'(0);
                    // Feature type is AFU
                    sTx.c2.data[63:60] <= 4'h1;
                    // End of list (last entry in list)
                    sTx.c2.data[40] <= 1'b1;
                end

              // AFU_ID_L
              2: sTx.c2.data <= afu_id[63:0];

              // AFU_ID_H
              4: sTx.c2.data <= afu_id[127:64];

              // DFH_RSVD0
              6: sTx.c2.data <= t_ccip_mmioData'(0);

              // DFH_RSVD1
              8: sTx.c2.data <= t_ccip_mmioData'(0);

              default: sTx.c2.data <= t_ccip_mmioData'(0);
            endcase
        end
    end


    //
    // CSR write handling.  Host software must tell the AFU the memory address
    // to which it should be writing.  The address is set by writing a CSR.
    //

    // TODO: write handling based o register map of HardCloud


    // =========================================================================
    //
    //   Main AFU logic
    //
    // =========================================================================

    //
    // State machine
    //

    // TODO: state machine logic


    //
    // Read
    //

    // TODO: add read logic


    //
    // Write
    //

    // TODO: add write logic

endmodule
