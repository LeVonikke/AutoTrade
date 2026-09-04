//+------------------------------------------------------------------+
//| WIN_MA_Crossover.mq5                                            |
//| Baseline EA for Mini Ibovespa (WIN) in MetaTrader 5             |
//+------------------------------------------------------------------+
#property copyright "AutoTrade"
#property version   "1.000"
#property strict

#include <Trade/Trade.mqh>

input group "Safety"
input bool   AllowLiveTrading       = false; // Must remain false until a demo test is approved.
input double Contracts              = 1.0;
input int    StopLossB3Points       = 250;   // Price distance: 250 WIN points = R$50 at one contract.
input int    MaxEntriesPerDay       = 3;
input int    MaxDeviationPoints     = 10;
input long   MagicNumber             = 20260731;

input group "Trading session (broker server time)"
input int    StartHHMM               = 910;
input int    LastEntryHHMM           = 1730;
input bool   CloseAtSessionEnd       = true;
input int    ForceCloseHHMM          = 1755;

input group "Signal - baseline only"
input ENUM_TIMEFRAMES SignalTimeframe = PERIOD_M5;
input int    FastMAPeriod             = 9;
input int    SlowMAPeriod             = 21;

CTrade trade;
int fastMAHandle = INVALID_HANDLE;
int slowMAHandle = INVALID_HANDLE;
datetime lastSignalBar = 0;
int entriesToday = 0;
int entriesDayKey = 0;

enum BotPosition
  {
   NO_POSITION = 0,
   LONG_POSITION,
   SHORT_POSITION,
   OTHER_POSITION
  };

// Return the current broker-server time as HHMM.
int CurrentHHMM()
  {
   MqlDateTime now;
   TimeToStruct(TimeTradeServer(),now);
   return now.hour * 100 + now.min;
  }

int CurrentDayKey()
  {
   MqlDateTime now;
   TimeToStruct(TimeTradeServer(),now);
   return now.year * 10000 + now.mon * 100 + now.day;
  }

void ResetDailyCounterIfNeeded()
  {
   int dayKey=CurrentDayKey();
   if(dayKey != entriesDayKey)
     {
      entriesDayKey=dayKey;
      entriesToday=0;
     }
  }

bool IsEntryWindow()
  {
   int hhmm=CurrentHHMM();
   return (hhmm >= StartHHMM && hhmm < LastEntryHHMM);
  }

bool IsForceCloseTime()
  {
   return (CloseAtSessionEnd && CurrentHHMM() >= ForceCloseHHMM);
  }

bool IsNewSignalBar()
  {
   datetime currentBar=iTime(_Symbol,SignalTimeframe,0);
   if(currentBar == 0 || currentBar == lastSignalBar)
      return false;

   lastSignalBar=currentBar;
   return true;
  }

BotPosition GetBotPosition()
  {
   if(!PositionSelect(_Symbol))
      return NO_POSITION;

   if(PositionGetInteger(POSITION_MAGIC) != MagicNumber)
      return OTHER_POSITION;

   ENUM_POSITION_TYPE positionType=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   if(positionType == POSITION_TYPE_BUY)
      return LONG_POSITION;
   if(positionType == POSITION_TYPE_SELL)
      return SHORT_POSITION;

   return OTHER_POSITION;
  }

bool GetClosedBarCross(bool &crossUp,bool &crossDown)
  {
   double fast[2];
   double slow[2];
   // Bars 2 and 1 are used so a signal never depends on an unfinished candle.
   if(CopyBuffer(fastMAHandle,0,1,2,fast) != 2 || CopyBuffer(slowMAHandle,0,1,2,slow) != 2)
     {
      Print("Unable to read moving-average buffers. Error ",GetLastError());
      return false;
     }

   crossUp=(fast[0] <= slow[0] && fast[1] > slow[1]);
   crossDown=(fast[0] >= slow[0] && fast[1] < slow[1]);
   return true;
  }

bool TradingIsPermitted()
  {
   if(!AllowLiveTrading)
     {
      Print("Trading blocked: AllowLiveTrading=false.");
      return false;
     }
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED) || !TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
     {
      Print("Trading blocked by the MT5 terminal or account settings.");
      return false;
     }
   return true;
  }

bool RequestSucceeded()
  {
   uint retcode=trade.ResultRetcode();
   return (retcode == TRADE_RETCODE_DONE || retcode == TRADE_RETCODE_DONE_PARTIAL || retcode == TRADE_RETCODE_PLACED);
  }

bool OpenLong()
  {
   if(!TradingIsPermitted())
      return false;

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick))
      return false;

   double sl=NormalizeDouble(tick.ask - StopLossB3Points,_Digits);
   if(!trade.Buy(Contracts,_Symbol,0.0,sl,0.0,"WIN MA crossover" ) || !RequestSucceeded())
     {
      Print("Buy failed: ",trade.ResultRetcode()," ",trade.ResultRetcodeDescription());
      return false;
     }

   entriesToday++;
   Print("Long position opened. Stop loss: ",DoubleToString(sl,_Digits));
   return true;
  }

bool OpenShort()
  {
   if(!TradingIsPermitted())
      return false;

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick))
      return false;

   double sl=NormalizeDouble(tick.bid + StopLossB3Points,_Digits);
   if(!trade.Sell(Contracts,_Symbol,0.0,sl,0.0,"WIN MA crossover") || !RequestSucceeded())
     {
      Print("Sell failed: ",trade.ResultRetcode()," ",trade.ResultRetcodeDescription());
      return false;
     }

   entriesToday++;
   Print("Short position opened. Stop loss: ",DoubleToString(sl,_Digits));
   return true;
  }

void CloseBotPosition(string reason)
  {
   if(!TradingIsPermitted())
      return;

   if(!trade.PositionClose(_Symbol) || !RequestSucceeded())
      Print("Close failed: ",trade.ResultRetcode()," ",trade.ResultRetcodeDescription());
   else
      Print("Position closed: ",reason);
  }

int OnInit()
  {
   if(FastMAPeriod <= 0 || SlowMAPeriod <= FastMAPeriod || Contracts <= 0 || StopLossB3Points <= 0 || MaxEntriesPerDay <= 0)
      return INIT_PARAMETERS_INCORRECT;

   if(StringFind(_Symbol,"WIN") != 0)
     {
      Print("Attach this EA only to the active WIN contract chart. Current symbol: ",_Symbol);
      return INIT_PARAMETERS_INCORRECT;
     }

   fastMAHandle=iMA(_Symbol,SignalTimeframe,FastMAPeriod,0,MODE_EMA,PRICE_CLOSE);
   slowMAHandle=iMA(_Symbol,SignalTimeframe,SlowMAPeriod,0,MODE_EMA,PRICE_CLOSE);
   if(fastMAHandle == INVALID_HANDLE || slowMAHandle == INVALID_HANDLE)
      return INIT_FAILED;

   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(MaxDeviationPoints);
   trade.SetTypeFillingBySymbol(_Symbol);
   ResetDailyCounterIfNeeded();
   Print("WIN EA initialized. Real trading is ",AllowLiveTrading ? "ENABLED" : "BLOCKED");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   if(fastMAHandle != INVALID_HANDLE)
      IndicatorRelease(fastMAHandle);
   if(slowMAHandle != INVALID_HANDLE)
      IndicatorRelease(slowMAHandle);
  }

void OnTick()
  {
   ResetDailyCounterIfNeeded();
   BotPosition position=GetBotPosition();

   // Never interfere with a manually opened position or another EA's position.
   if(position == OTHER_POSITION)
     {
      Print("A non-bot position exists on ",_Symbol,". This EA will not act.");
      return;
     }

   if(IsForceCloseTime() && position != NO_POSITION)
     {
      CloseBotPosition("end of session");
      return;
     }

   if(!IsEntryWindow() || !IsNewSignalBar())
      return;

   bool crossUp=false;
   bool crossDown=false;
   if(!GetClosedBarCross(crossUp,crossDown))
      return;

   if(position == LONG_POSITION && crossDown)
     {
      CloseBotPosition("opposite moving-average cross");
      return;
     }
   if(position == SHORT_POSITION && crossUp)
     {
      CloseBotPosition("opposite moving-average cross");
      return;
     }

   if(position != NO_POSITION || entriesToday >= MaxEntriesPerDay)
      return;

   if(crossUp)
      OpenLong();
   else if(crossDown)
      OpenShort();
  }
