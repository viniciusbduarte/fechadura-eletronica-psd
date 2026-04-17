`timescale 1ns/1ps

module tb_cenario_enable_pause;

  logic clk;
  logic rst;
  logic enable;
  logic [3:0] col_matriz;
  logic [3:0] lin_matriz;
  senhaPac_t digitos_value;
  logic digitos_valid;
  logic [2:0] fsm_before;
  logic [22:0] to_cnt_before;

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
    $dumpfile("tb_cenario_enable_pause.vcd");
    $dumpvars(0, tb_cenario_enable_pause);

    clk = 0;
    rst = 1;
    enable = 1;
    col_matriz = 4'b1111;

    #2ms;
    rst = 0;

    pressionar_tecla(0, 0); // entra em processamento
    #20ms;

    fsm_before = dut.fsm;
    to_cnt_before = dut.to_cnt;

    enable = 1'b0;
    #200ms;

    if (dut.fsm !== fsm_before) begin
      $fatal(1, "Falha no enable=0: FSM nao congelou");
    end
    if (dut.to_cnt !== to_cnt_before) begin
      $fatal(1, "Falha no enable=0: to_cnt nao congelou");
    end

    enable = 1'b1;
    #10ms;

    if (dut.to_cnt <= to_cnt_before) begin
      $fatal(1, "Falha no retorno enable=1: to_cnt nao voltou a contar");
    end

    $display("[PASSOU] Enable congelou e retomou corretamente");
    #10ms;
    $finish;
  end

endmodule
