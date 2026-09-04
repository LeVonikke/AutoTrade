//+------------------------------------------------------------------+
//| USDJPY_Demo_EA.mq5                                              |
//| Technical test EA. It refuses non-demo MT5 accounts.            |
//+------------------------------------------------------------------+
#property copyright "AutoTrade"
#property version   "1.000"
#property strict

#include <Trade/Trade.mqh>

input group "Demo safety"
input bool   AllowDemoOrders        = false; // Change only after observing signals in a DEMO account.
input double DemoLots               = 0.01;
input int    StopLossTerminalPoints = 250;   // USDJPY: commonly 0.250 with a 3-decimal quote.
input int    MaxEntriesPerDay       = 3;
input long   MagicNumber            = 20260801;

input group "Signal"
input ENUM_TIMEFRAMES SignalTimeframe = PERIOD_M5;
input int    FastEMAPeriod            = 9;
input int    SlowEMAPeriod            = 21;

CTrade trade;
int fastMAHandle=INVALID_HANDLE;
int slowMAHandle=INVALID_HANDLE;
datetime lastSignalBar=0;
int entriesToday=0;
int entriesDayKey=0;

enum BotPosition
  {
   NO_POSITION=0,
   LONG_POSITION,
   SHORT_POSITION,
   OTHER_POSITION
  };

int CurrentDayKey()
  {
   MqlDateTime now;
   TimeToStruct(TimeTradeServer(),now);
   return now.year*10000+now.mon*100+now.day;
  }

void ResetDailyCounterIfNeeded()
  {
   int today=CurrentDayKey();
   if(today!=entriesDayKey)
     {
      entriesDayKey=today;
      entriesToday=0;
     }
  }

bool IsNewSignalBar()
  {
   datetime currentBar=iTime(_Symbol,SignalTimeframe,0);
   if(currentBar==0 || currentBar==lastSignalBar)
      return false;
   lastSignalBar=currentBar;
   return true;
  }

BotPosition GetBotPosition()
  {
   if(!PositionSelect(_Symbol))
      return NO_POSITION;
   if(PositionGetInteger(POSITION_MAGIC)!=MagicNumber)
      return OTHER_POSITION;

   ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   if(type==POSITION_TYPE_BUY)
      return LONG_POSITION;
   if(type==POSITION_TYPE_SELL)
      return SHORT_POSITION;
   return OTHER_POSITION;
  }

bool GetClosedBarCross(bool &crossUp,bool &crossDown)
  {
   double fast[2];
   double slow[2];
   // CopyBuffer places the older value first in physical memory.
   if(CopyBuffer(fastMAHandle,0,1,2,fast)!=2 || CopyBuffer(slowMAHandle,0,1,2,slow)!=2)
      return false;

   crossUp=(fast[0]<=slow[0] && fast[1]>slow[1]);
   crossDown=(fast[0]>=slow[0] && fast[1]<slow[1]);
   return true;
  }

bool DemoTradingIsPermitted()
  {
   if(!AllowDemoOrders)
     {
      Print("Demo orders are blocked: AllowDemoOrders=false.");
      return false;
     }
   if(AccountInfoInteger(ACCOUNT_TRADE_MODE)!=ACCOUNT_TRADE_MODE_DEMO)
     {
      Print("Refusing order: this EA only runs on an MT5 demo account.");
      return false;
     }
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED) || !TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
     {
      Print("Demo trading is disabled in the terminal or account.");
      return false;
     }
   return true;
  }

bool RequestSucceeded()
  {
   uint retcode=trade.ResultRetcode();
   return retcode==TRADE_RETCODE_DONE || retcode==TRADE_RETCODE_DONE_PARTIAL || retcode==TRADE_RETCODE_PLACED;
  }

bool OpenLong()
  {
   if(!DemoTradingIsPermitted())
      return false;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick))
      return false;

   double stop=NormalizeDouble(tick.ask-StopLossTerminalPoints*_Point,_Digits);
   if(!trade.Buy(DemoLots,_Symbol,0.0,stop,0.0,"USDJPY demo EMA") || !RequestSucceeded())
     {
      Print("Demo buy failed: ",trade.ResultRetcode()," ",trade.ResultRetcodeDescription());
      return false;
     }
   entriesToday++;
   return true;
  }

bool OpenShort()
  {
   if(!DemoTradingIsPermitted())
      return false;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick))
      return false;

   double stop=NormalizeDouble(tick.bid+StopLossTerminalPoints*_Point,_Digits);
   if(!trade.Sell(DemoLots,_Symbol,0.0,stop,0.0,"USDJPY demo EMA") || !RequestSucceeded())
     {
      Print("Demo sell failed: ",trade.ResultRetcode()," ",trade.ResultRetcodeDescription());
      return false;
     }
   entriesToday++;
   return true;
  }

void CloseBotPosition(string reason)
  {
   if(!DemoTradingIsPermitted())
      return;
   if(!trade.PositionClose(_Symbol) || !RequestSucceeded())
      Print("Demo close failed: ",trade.ResultRetcode()," ",trade.ResultRetcodeDescription());
   else
      Print("Demo position closed: ",reason);
  }

int OnInit()
  {
   if(StringFind(_Symbol,"USDJPY")<0 || FastEMAPeriod<=0 || SlowEMAPeriod<=FastEMAPeriod || DemoLots<=0 || StopLossTerminalPoints<=0 || MaxEntriesPerDay<=0)
      return INIT_PARAMETERS_INCORRECT;

   fastMAHandle=iMA(_Symbol,SignalTimeframe,FastEMAPeriod,0,MODE_EMA,PRICE_CLOSE);
   slowMAHandle=iMA(_Symbol,SignalTimeframe,SlowEMAPeriod,0,MODE_EMA,PRICE_CLOSE);
   if(fastMAHandle==INVALID_HANDLE || slowMAHandle==INVALID_HANDLE)
      return INIT_FAILED;

   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetTypeFillingBySymbol(_Symbol);
   ResetDailyCounterIfNeeded();
   Print("USDJPY demo EA initialized. It refuses all non-demo accounts.");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   if(fastMAHandle!=INVALID_HANDLE)
      IndicatorRelease(fastMAHandle);
   if(slowMAHandle!=INVALID_HANDLE)
      IndicatorRelease(slowMAHandle);
  }

void OnTick()
  {
   ResetDailyCounterIfNeeded();
   BotPosition position=GetBotPosition();
   if(position==OTHER_POSITION || !IsNewSignalBar())
      return;

   bool crossUp=false;
   bool crossDown=false;
   if(!GetClosedBarCross(crossUp,crossDown))
      return;

   if(position==LONG_POSITION && crossDown)
     {
      CloseBotPosition("opposite EMA cross");
      return;
     }
   if(position==SHORT_POSITION && crossUp)
     {
      CloseBotPosition("opposite EMA cross");
      return;
     }
   if(position!=NO_POSITION || entriesToday>=MaxEntriesPerDay)
      return;

   if(crossUp)
      OpenLong();
   else if(crossDown)
      OpenShort();
  }
