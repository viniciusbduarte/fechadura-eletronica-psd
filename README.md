# TABELA DE TRANSIÇÃO DE ESTADOS
## Decodificador de Teclado Matricial 4x4

**Projeto:** Decodificador de Teclado com Debounce e Auto-Repeat  
**Data:** 2026-04-14  
**Clock:** 1 kHz (1 ciclo = 1 ms)  

---

## 1. FSM DE DEBOUNCE E AUTO-REPEAT

### Descrição
A FSM de debounce valida leituras do teclado filtrando ruído no mínimo representável do clock base (1 ms) e gerencia auto-repeat para dígitos numéricos com hold time (2s) e rate (1s).

### Estados
- **DB_IDLE:** Aguardando detecção de tecla
- **DB_COUNT:** Contando ciclos de debounce
- **DB_LOCKED:** Tecla validada, gerenciando auto-repeat

### Tabela de Transição

| Estado Atual | Condição | Próximo Estado | Ações |
|:---|:---|:---|:---|
| **DB_IDLE** | `raw_valid = 1` | DB_COUNT | `db_cnt ← 1`<br>`key_bcd ← raw_bcd` |
| **DB_IDLE** | `raw_valid = 0` | DB_IDLE | Sem ação |
| **DB_COUNT** | `raw_valid = 0` | DB_IDLE | `db_cnt ← 0` |
| **DB_COUNT** | `raw_valid = 1` AND `db_cnt < (DEBOUNCE_VAL - 1)` | DB_COUNT | `db_cnt ← db_cnt + 1` |
| **DB_COUNT** | `raw_valid = 1` AND `db_cnt ≥ (DEBOUNCE_VAL - 1)` | DB_LOCKED | `key_pulse ← 1`<br>`db_cnt ← 0`<br>`rep_cnt ← 0`<br>`rep_phase ← 0` |
| **DB_LOCKED** | `raw_valid = 0` | DB_IDLE | `rep_cnt ← 0`<br>`rep_phase ← 0` |
| **DB_LOCKED** | `raw_valid = 1` AND `key_bcd ≤ 9`<br>AND `rep_phase = 0`<br>AND `rep_cnt < (HOLD-1)` | DB_LOCKED | `rep_cnt ← rep_cnt + 1` |
| **DB_LOCKED** | `raw_valid = 1` AND `key_bcd ≤ 9`<br>AND `rep_phase = 0`<br>AND `rep_cnt ≥ (HOLD-1)` | DB_LOCKED | `rep_pulse ← 1`<br>`rep_cnt ← 0`<br>`rep_phase ← 1` |
| **DB_LOCKED** | `raw_valid = 1` AND `key_bcd ≤ 9`<br>AND `rep_phase = 1`<br>AND `rep_cnt < (RATE-1)` | DB_LOCKED | `rep_cnt ← rep_cnt + 1` |
| **DB_LOCKED** | `raw_valid = 1` AND `key_bcd ≤ 9`<br>AND `rep_phase = 1`<br>AND `rep_cnt ≥ (RATE-1)` | DB_LOCKED | `rep_pulse ← 1`<br>`rep_cnt ← 0` |
| **DB_LOCKED** | `raw_valid = 1` AND `key_bcd > 9` | DB_LOCKED | Sem ação<br>(sem auto-repeat) |

### Observações
- Auto-repeat **desativado** para `*` (0xA) e `#` (0xB)
- Saída `key_pulse` é um pulso de 1 ciclo
- Saída `rep_pulse` é um pulso de 1 ciclo, repetido

---

## 2. FSM PRINCIPAL (PROCESSAMENTO E VALIDAÇÃO)

### Descrição
A FSM principal acumula dígitos em um buffer de 20 posições, gerencia confirmação via `*`, reset via `#`, e implementa timeout de 5 segundos sem atividade.

### Estados
- **ST_IDLE:** Aguardando primeiro dígito
- **ST_DIGIT:** Acumulando dígitos (0-9)
- **ST_CONFIRM:** Processando confirmação (*)
- **ST_HASH:** Processando reset (#)
- **ST_TIMEOUT:** Timeout de 5 segundos
- **ST_CLR:** Limpeza e retorno a IDLE

### Tabela de Transição

| Estado Atual | Condição | Próximo Estado | Ações |
|:---|:---|:---|:---|
| **ST_IDLE** | `to_pulse = 1` | ST_TIMEOUT | Sem ação adicional |
| **ST_IDLE** | `key_pulse = 0` | ST_IDLE | Sem ação |
| **ST_IDLE** | `key_pulse = 1` AND `key_bcd = 0xA` | ST_CONFIRM | `to_active ← 1`<br>`to_cnt ← 0`<br>`proc_cnt ← 0` |
| **ST_IDLE** | `key_pulse = 1` AND `key_bcd = 0xB` | ST_HASH | `to_active ← 1`<br>`to_cnt ← 0` |
| **ST_IDLE** | `key_pulse = 1` AND `key_bcd ≤ 9` | ST_DIGIT | `to_active ← 1`<br>`to_cnt ← 0`<br>`digitos_value[0] ← key_bcd` |
| **ST_DIGIT** | `to_pulse = 1` | ST_TIMEOUT | Sem ação adicional |
| **ST_DIGIT** | `key_pulse = 0` AND `rep_pulse = 0` | ST_DIGIT | Sem ação |
| **ST_DIGIT** | `(key_pulse = 1` OR `rep_pulse = 1)` AND `key_bcd = 0xA` | ST_CONFIRM | `to_cnt ← 0`<br>`proc_cnt ← 0` |
| **ST_DIGIT** | `(key_pulse = 1` OR `rep_pulse = 1)` AND `key_bcd = 0xB` | ST_HASH | `to_cnt ← 0` |
| **ST_DIGIT** | `(key_pulse = 1` OR `rep_pulse = 1)` AND `key_bcd ≤ 9` | ST_DIGIT | `to_cnt ← 0`<br>**SHIFT:** `digits[i] ← digits[i-1]` para i=19..1<br>`digitos_value[0] ← key_bcd` |
| **ST_CONFIRM** | `proc_cnt < (PROCESS_VAL - 1)` | ST_CONFIRM | `proc_cnt ← proc_cnt + 1` |
| **ST_CONFIRM** | `proc_cnt ≥ (PROCESS_VAL - 1)` | ST_CLR | `digitos_valid ← 1`<br>`to_active ← 0`<br>`to_cnt ← 0`<br>`proc_cnt ← 0` |
| **ST_HASH** | — | ST_CLR | `digitos_value ← {20{0xB}}`<br>`digitos_valid ← 1`<br>`to_active ← 0`<br>`to_cnt ← 0` |
| **ST_TIMEOUT** | — | ST_CLR | `digitos_value ← {20{0xE}}`<br>`digitos_valid ← 1`<br>`to_cnt ← 0` |
| **ST_CLR** | — | ST_IDLE | `digitos_value ← {20{0xF}}`<br>`proc_cnt ← 0` |

### Timeout Global (Condição Especial)

| Condição | Ação |
|:---|:---|
| `to_active = 1` AND `to_cnt ≥ (TIMEOUT_VAL - 1)` | `to_active ← 0`<br>`to_cnt ← 0`<br>`to_pulse ← 1` (1 ciclo) |

Observação: o `to_pulse` é consumido apenas em `ST_IDLE` e `ST_DIGIT`, que então fazem a transição para `ST_TIMEOUT`.

---

## 3. MAPA DE CÓDIGOS BCD DE SAÍDA

| Código | Significado | Contexto |
|:---|:---|:---|
| 0x0-0x9 | Dígitos 0-9 | Buffer normal |
| 0xA | Asterisco (*) | Confirmação |
| 0xB | Hash (#) | Reset ou erro via hash |
| 0xE | Erro | Timeout de 5 segundos |
| 0xF | Inválido | Posições não preenchidas |

---

## 4. PARÂMETROS DE TEMPORIZAÇÃO

| Parâmetro | Símbolo | Valor | Descrição |
|:---|:---|:---|:---|
| Debounce | DEBOUNCE_VAL | 1 ms (1 ciclo) | Tempo de estabilidade mínima |
| Processamento | PROCESS_VAL | 1 ms (1 ciclo) | Delay de confirmação |
| Hold Time | HOLD_VAL | 2 s | Espera antes de auto-repeat |
| Taxa de Repetição | RATE_VAL | 1 s | Intervalo de auto-repeat |
| Timeout Global | TIMEOUT_VAL | 5 s | Timeout sem atividade |

---

## 5. SINAIS INTERNOS E EXTERNAS

### Entradas
| Sinal | Tipo | Descrição |
|:---|:---|:---|
| `clk` | input logic | Clock de 1 kHz |
| `rst` | input logic | Reset síncrono (ativo alto) |
| `enable` | input logic | Habilita processamento |
| `col_matriz[3:0]` | input logic | Colunas do teclado (active-low) |

### Saídas
| Sinal | Tipo | Descrição |
|:---|:---|:---|
| `lin_matriz[3:0]` | output logic | Linhas do teclado (active-low) |
| `digitos_value` | output senhaPac_t | Buffer de 20 × 4 bits |
| `digitos_valid` | output logic | Pulso de validação (1 ciclo) |

### Sinais Internos (Debounce)
| Sinal | Tipo | Descrição |
|:---|:---|:---|
| `db_st` | db_st_t | Estado da FSM debounce |
| `db_cnt[6:0]` | logic | Contador debounce |
| `key_bcd[3:0]` | logic | Código BCD capturado |
| `key_pulse` | logic | Pulso debounce completo |
| `rep_cnt[20:0]` | logic | Contador auto-repeat |
| `rep_phase` | logic | Fase auto-repeat (0=hold, 1=rate) |
| `rep_pulse` | logic | Pulso auto-repeat |

### Sinais Internos (Principal)
| Sinal | Tipo | Descrição |
|:---|:---|:---|
| `fsm` | fsm_t | Estado da FSM principal |
| `proc_cnt[4:0]` | logic | Contador processamento |
| `to_cnt[22:0]` | logic | Contador timeout |
| `to_active` | logic | Timeout ativado |
| `to_pulse` | logic | Pulso de timeout (1 ciclo) |

---

## 6. CONDIÇÕES ESPECIAIS

### Enable Control
```
Se enable = 0:
  → Nenhuma transição ocorre
  → FSM congelada no estado atual
  → Contadores mantêm valores
  → Saídas congeladas

Se enable = 1:
  → Operação normal
```

### Reset
```
Se rst = 1:
  → db_st ← DB_IDLE
  → fsm ← ST_IDLE
  → Todos os contadores ← 0
  → digitos_value ← {20{0xF}}
  → digitos_valid ← 0
```

### Controle de Buffer
```
SHIFT (ST_DIGIT com novo dígito):
  digitos_value.digits[19:1] ← digitos_value.digits[18:0]
  digitos_value.digits[0] ← new_bcd
  
Resultado: Novo dígito entra em [0], ältesten sai de [19]
```

## 7. CASOS ESPECIAIS E TRATAMENTO DE ERROS

### Caso 1: Tecla Pressionada > 5 segundos
```
to_active = 1 durante todo tempo
to_cnt incrementa continuamente
Quando to_cnt ≥ 5.000:
  → to_pulse ← 1 (1 ciclo)
  → Em ST_IDLE ou ST_DIGIT: fsm ← ST_TIMEOUT
  → digitos_value ← {20{0xE}}
  → digitos_valid ← 1 (pulso)
  → fsm ← ST_CLR → ST_IDLE
```

### Caso 2: Múltiplas Teclas Pressionadas Simultaneamente
```
Versão atual: Não suportado
A matriz foi projetada para detectar uma célula por vez
Se múltiplas colunas forem ativas:
  → Case statement toma a primeira correspondência
  → Resultado imprevisível
Recomendação: Adicionar validação de entrada
```

### Caso 3: Enable = 0 Durante Processamento
```
Se enable = 0:
  → Nenhuma FSM progride
  → Contadores congelados
  → Buffer retem valores
  → Saídas congeladas
  
Ao reativar enable = 1:
  → Sistema retoma exatamente onde parou
  → Timeout continua a contar (se to_active = 1)
```

### Caso 4: Reset During Processing
```
Se rst = 1:
  → Ambas FSMs retornam a IDLE/inicial
  → Todos contadores zerados
  → Buffer preenchido com 0xF
  → Qualquer operação em progresso é perdida
```

---

## 8. RESUMO DE ESTADOS FINAIS

### Situações de Saída

| Situação | digitos_value | digitos_valid | fsm | Descrição |
|:---|:---|:---|:---|:---|
| Confirmação (*) | Sequência com 0xF | 1 (pulso) | ST_CLR | Normal |
| Reset (#) | {20{0xB}} | 1 (pulso) | ST_CLR | Usuário reset |
| Timeout 5s | {20{0xE}} | 1 (pulso) | ST_CLR | Timeout |
| Sem confirmação | {20{0xF}} | 0 | ST_IDLE | Estado inicial |
| Processando | Parcial | 0 | ST_DIGIT | Acumulando |

---

