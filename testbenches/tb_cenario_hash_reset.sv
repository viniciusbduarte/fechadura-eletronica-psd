`timescale 1ns/1ps

module tb_cenario_hash_reset;

  logic clk;
  logic rst;
  logic enable;
  logic [3:0] col_matriz;
  logic [3:0] lin_matriz;
  senhaPac_t digitos_value;
  logic digitos_valid;

  decodificador_de_teclado dut(
    .clk(clk),
    .rst(rst),
    .enable(enable),
    .col_matriz(col_matriz),
    .lin_matriz(lin_matriz),
    .digitos_value(digitos_value),
    .digitos_valid(digitos_valid)
  );

  always #500us clk = ~clk;

  task automatic pressionar_tecla(input int linha, input int coluna, input int hold_ms = 30);
    logic [3:0] col_code;
    logic [3:0] lin_code;
    time tempo_inicio;

    case (coluna)
      0: col_code = 4'b0111;
      1: col_code = 4'b1011;
      2: col_code = 4'b1101;
      default: col_code = 4'b1111;
    endcase

    case (linha)
      0: lin_code = 4'b0111;
      1: lin_code = 4'b1011;
      2: lin_code = 4'b1101;
      default: lin_code = 4'b1110;
    endcase

    while (dut.lin_matriz !== lin_code) #100us;
    col_matriz = col_code;
    tempo_inicio = $time;

    while (($time - tempo_inicio) < (hold_ms * 1ms)) #100us;

    col_matriz = 4'b1111;
  endtask

  initial begin
    $dumpfile("tb_cenario_hash_reset.vcd");
    $dumpvars(0, tb_cenario_hash_reset);

    clk = 0;
    rst = 1;
    enable = 1;
    col_matriz = 4'b1111;

    #2ms;
    rst = 0;

    pressionar_tecla(0, 0);
    #10ms;
    pressionar_tecla(0, 1);
    #10ms;
    pressionar_tecla(0, 2);
    #10ms;
    pressionar_tecla(1, 2);
    #10ms;
    pressionar_tecla(3, 2);
    #50ms;

    $finish;
  end

  always @(posedge digitos_valid) begin
    $display("[%0t] LIMPO: %h", $time, digitos_value);
  end

  always @(posedge dut.key_pulse) begin
    $display("[%0t] key_pulse: %h", $time, dut.key_bcd);
  end

endmodule
