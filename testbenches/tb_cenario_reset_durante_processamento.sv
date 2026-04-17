`timescale 1ns/1ps

module tb_cenario_reset_durante_processamento;

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
    int i;

    $dumpfile("tb_cenario_reset_durante_processamento.vcd");
    $dumpvars(0, tb_cenario_reset_durante_processamento);

    clk = 0;
    rst = 1;
    enable = 1;
    col_matriz = 4'b1111;

    #2ms;
    rst = 0;

    pressionar_tecla(0, 0); // inicia entrada
    #20ms;

    rst = 1'b1;
    #2ms;
    rst = 1'b0;
    #5ms;

    if (dut.fsm !== 3'd0) begin
      $fatal(1, "Falha no reset: FSM principal nao retornou para ST_IDLE");
    end

    for (i = 0; i < 20; i++) begin
      if (digitos_value.digits[i] !== 4'hF) begin
        $fatal(1, "Falha no reset: digits[%0d] != 0xF", i);
      end
    end

    if (digitos_valid !== 1'b0) begin
      $fatal(1, "Falha no reset: digitos_valid deveria estar em 0");
    end

    $display("[PASSOU] Reset durante processamento retornou ao estado inicial");
    #10ms;
    $finish;
  end

endmodule
