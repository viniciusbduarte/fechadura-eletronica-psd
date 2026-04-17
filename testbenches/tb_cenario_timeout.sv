`timescale 1ns/1ps

module tb_cenario_timeout;

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

    $dumpfile("tb_cenario_timeout.vcd");
    $dumpvars(0, tb_cenario_timeout);

    clk = 0;
    rst = 1;
    enable = 1;
    col_matriz = 4'b1111;

    #2ms;
    rst = 0;

    pressionar_tecla(0, 0); // inicia sessao e ativa timeout

    fork
      begin : watchdog
        #6s;
        $fatal(1, "Timeout do teste: digitos_valid nao pulsou no intervalo esperado");
      end
      begin : espera_timeout
        @(posedge digitos_valid);

        for (i = 0; i < 20; i++) begin
          if (digitos_value.digits[i] !== 4'hE) begin
            $fatal(1, "Falha no timeout: digits[%0d] != 0xE", i);
          end
        end

        $display("[PASSOU] Timeout gerou vetor de erro 0xE");
      end
    join_any
    disable fork;

    #10ms;
    $finish;
  end

endmodule
