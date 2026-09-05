# AutoTrade — WIN / MetaTrader 5

![MQL5](https://img.shields.io/badge/MQL5-blue) ![Status](https://img.shields.io/badge/status-prot%C3%B3tipo-yellow) ![Privado](https://img.shields.io/badge/-privado-grey) ![Live Trading](https://img.shields.io/badge/live%20trading-disabled-critical)

`WIN_MA_Crossover.mq5` is a starting Expert Advisor (EA) for the active B3 mini-index contract on MetaTrader 5.

It is intentionally **unable to place orders by default**. `AllowLiveTrading` is set to `false`. The source can be compiled and inspected before the Rico account and the WIN symbol are enabled.

## Structure

| file | content |
|---|---|
| `WIN_MA_Crossover.mq5` | main EA — EMA 9/21 crossover on the WIN mini-index, orders disabled by default |
| `WIN_EMA_Crossover.ntsl` | same strategy translated to NTSL for Profit / Nova Futura |
| `PROFIT_NOVA_FUTURA.md` | deployment restrictions and import steps for the NTSL version |
| `USDJPY_Demo_EA.mq5` | separate technical demo EA, FX-only, demo-account-only |
| `*.ex5`, `*.compile.log` | compiled binaries and build logs, kept for reference |

## What is implemented

- One-contract default (`Contracts = 1`)
- Hard stop loss of 250 B3 price points (R$50 on one WIN contract, before fees and slippage)
- Uses the active WIN expiry chart, such as `WINQ26`, rather than a hard-coded symbol
- Trades only on a closed 5-minute candle
- Baseline signal: EMA 9 / EMA 21 crossover
- Closes a bot position on the opposite crossover
- Limits new entries to three per broker-server day
- Stops opening trades after 17:30 and attempts to close the bot position at 17:55 (both times are broker-server time and must be confirmed in the final broker environment)
- Never touches a manual position or a position placed by another EA (checked through `MagicNumber`)

The EMA crossover is a transparent placeholder, not a validated or recommended trading strategy. It must be replaced if a different entry rule is chosen and must be tested with realistic spread, fees and slippage before any real-money use.

## Install into MT5

1. In MT5, choose **File → Open Data Folder**.
2. Open `MQL5\Experts` and copy `WIN_MA_Crossover.mq5` there.
3. Open it in MetaEditor and compile (`F7`).
4. Connect to a broker-provided **demo** account that has the current WIN contract and open that contract's M5 chart.
5. Drag the EA from Navigator → Expert Advisors onto the chart.
6. Keep `AllowLiveTrading = false` while inspecting the Journal and testing configuration.

The EA will reject charts whose symbol does not begin with `WIN`, so it cannot be accidentally attached to a generic FX or stock chart.

## Before enabling any order

- Confirm that the broker's WIN symbol has the expected quote scale and that a 250-point stop is accepted.
- Test the EA in the MT5 Strategy Tester and then in the broker's demo environment.
- Confirm the server clock and update the three session inputs if necessary.
- Define a maximum daily financial loss, a maximum number of consecutive losses, and a circuit breaker for platform/disconnect faults. These have not been guessed in this baseline.
- Review the final entry and exit rules; the current EMA crossover has no profit target and exits only on its stop or an opposite crossover/session close.

Never share the broker, MT5 or portal password in this repository or chat.

## Profit / Nova Futura

The NTSL translation is in `WIN_EMA_Crossover.ntsl`; its deployment restrictions and import steps are in `PROFIT_NOVA_FUTURA.md`.

## USDJPY technical demo

`USDJPY_Demo_EA.mq5` is a separate technical test. It will only initialize on a USDJPY chart and will refuse every account that is not an MT5 **demo** account. Its default is 0.01 lots and its order switch is off (`AllowDemoOrders = false`).

This is not a performance or risk-equivalent test of the WIN strategy: FX uses lots and terminal points, rather than B3 contracts and B3 price points. It only tests the EA's signal, order, stop and close mechanics in a safe broker demo environment.
