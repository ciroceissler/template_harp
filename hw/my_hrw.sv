module my_hrw
(
  input              clk,
  input              rst_b,
  input              valid_in,
  input      [511:0] data_in,
  output reg [511:0] data_out
);

  always_ff @(posedge clk) begin
    if (!rst_b) begin
      data_out <= 0;
    end
    else if (valid_in) begin

      // TODO: modify your code HERE!

      data_out <= data_in + 100;
    end
  end

endmodule : my_hrw

