`timescale 1ns/1ps

module tb_cenario_debounce;

  logic clk;
  logic rst;
  logic enable;
  logic [3:0] col_matriz;
  logic [3:0] lin_matriz;
  senhaPac_t digitos_value;
  logic digitos_valid;
  int key_count;

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

  always @(posedge dut.key_pulse) begin
    key_count++;
  end

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
    $dumpfile("tb_cenario_debounce.vcd");
    $dumpvars(0, tb_cenario_debounce);

    clk = 0;
    rst = 1;
    enable = 1;
    col_matriz = 4'b1111;
    key_count = 0;

    #2ms;
    rst = 0;

    // Pulso curto: 200us (< 1 ciclo de 1ms), nao deve gerar key_pulse
    while (dut.lin_matriz !== 4'b0111) #100us;
    col_matriz = 4'b0111;
    #200us;
    col_matriz = 4'b1111;
    #5ms;

    if (key_count != 0) begin
      $fatal(1, "Falha no debounce: key_pulse nao deveria ocorrer para pulso de 200us");
    end

    if (digitos_valid !== 1'b0) begin
      $fatal(1, "Falha no debounce: digitos_valid nao deveria pulsar");
    end

    $display("[PASSOU] Debounce rejeitou pressao curta");
    #10ms;
    $finish;
  end

endmodule
