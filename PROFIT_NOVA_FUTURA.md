# Versão Profit / Nova Futura

O arquivo `WIN_EMA_Crossover.ntsl` traduz a base do robô de MT5 para NTSL, a linguagem do Profit. Ele usa o contrato WIN aberto no gráfico, um contrato por ordem, stop de 250 pontos e encerramento antes do fim da sessão.

## Limitação da plataforma gratuita

Na Nova Futura, o Profit Max Trader gratuito é a versão de entrada. A corretora indica automação de estratégias como recurso do Profit Pro. Assim, o arquivo NTSL pode ser usado para estudar sinais e fazer backtest no editor, mas não deve ser considerado um robô autônomo enquanto a conta não tiver Profit Pro e o módulo de Automação de Estratégias habilitado.

O código começa com `EnableOrders(False)`. Ao importar, ele apenas colore os cruzamentos:

- verde: cruzamento de alta da EMA 9 sobre a EMA 21;
- vermelho: cruzamento de baixa.

Não altere essa opção antes de completar o backtest. Caso a automação seja liberada, configure a automação com:

- ativo: contrato WIN vigente;
- gráfico: 5 minutos;
- quantidade por ordem: 1;
- exposição máxima: 1 contrato;
- modo de execução: fechamento do candle;
- pausar e zerar: 17:55 (ajuste ao horário da sua sessão);
- limite diário de perda e de operações: a definir antes de conta real.

## Como importar para estudo

1. No Profit, abra **Estratégias → Editor de Estratégias → Nova Estratégia de Execução**.
2. Cole o conteúdo de `WIN_EMA_Crossover.ntsl`, salve e compile.
3. Aplique ao gráfico M5 do WIN e execute o Backtest.
4. Revise operações, custos e o relatório de patrimônio. O cruzamento de médias é somente uma regra-base, sem evidência de rentabilidade.

As funções de compra, venda e stops pertencem às funções de backtest/execução da NTSL. Antes de automação, confira a versão do manual incluída no próprio Profit, pois plataformas e funções podem mudar.
