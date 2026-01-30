//+------------------------------------------------------------------+
//|                                                      Common.mqh  |
//|                               Grid Survival Protocol EA - Utils  |
//|                                                                  |
//| Description: Shared Constants, Macros, and Helper Functions      |
//+------------------------------------------------------------------+
#property copyright "Grid Survival Protocol"
#property link      ""
#property version   "1.00"

//+------------------------------------------------------------------+
//| Version Information                                              |
//+------------------------------------------------------------------+
#define EA_NAME           "Grid Survival Protocol"
#define EA_VERSION        "1.00"
#define EA_BUILD          "20260130"

//+------------------------------------------------------------------+
//| Magic Number (unique identifier for this EA's orders)            |
//+------------------------------------------------------------------+
#define GRID_MAGIC_NUMBER 20260130

//+------------------------------------------------------------------+
//| Precision Constants                                              |
//+------------------------------------------------------------------+
#define PRICE_EPSILON     0.00001    // Minimum price difference
#define LOT_EPSILON       0.001      // Minimum lot difference
#define PERCENT_EPSILON   0.01       // Minimum percent difference

//+------------------------------------------------------------------+
//| Time Constants (in seconds)                                      |
//+------------------------------------------------------------------+
#define SECONDS_PER_MINUTE   60
#define SECONDS_PER_HOUR     3600
#define SECONDS_PER_DAY      86400

//+------------------------------------------------------------------+
//| Retry Constants                                                  |
//+------------------------------------------------------------------+
#define MAX_RETRY_ATTEMPTS   5
#define RETRY_DELAY_MS       100

//+------------------------------------------------------------------+
//| Logging Macros                                                   |
//+------------------------------------------------------------------+
#define LOG_PREFIX        "[GridSurvival] "

//--- Log levels
#define LOG_DEBUG(msg)    PrintFormat(LOG_PREFIX + "[DEBUG] %s", msg)
#define LOG_INFO(msg)     PrintFormat(LOG_PREFIX + "[INFO] %s", msg)
#define LOG_WARNING(msg)  PrintFormat(LOG_PREFIX + "[WARNING] %s", msg)
#define LOG_ERROR(msg)    PrintFormat(LOG_PREFIX + "[ERROR] %s", msg)
#define LOG_CRITICAL(msg) PrintFormat(LOG_PREFIX + "[CRITICAL] %s", msg)

//+------------------------------------------------------------------+
//| Validation Macros                                                |
//+------------------------------------------------------------------+
#define IS_VALID_TICKET(ticket)    ((ticket) > 0)
#define IS_VALID_PRICE(price)      ((price) > 0.0)
#define IS_VALID_LOT(lot)          ((lot) > 0.0)
#define IS_VALID_PERCENT(pct)      ((pct) >= 0.0 && (pct) <= 100.0)

//+------------------------------------------------------------------+
//| Comparison Helpers                                               |
//+------------------------------------------------------------------+
//--- Compare doubles with epsilon
bool IsEqual(double a, double b, double epsilon = PRICE_EPSILON)
{
   return MathAbs(a - b) < epsilon;
}

//--- Check if value is greater than
bool IsGreater(double a, double b, double epsilon = PRICE_EPSILON)
{
   return (a - b) > epsilon;
}

//--- Check if value is less than
bool IsLess(double a, double b, double epsilon = PRICE_EPSILON)
{
   return (b - a) > epsilon;
}

//--- Check if value is in range
bool IsInRange(double value, double low, double high)
{
   return (value >= low && value <= high);
}

//+------------------------------------------------------------------+
//| Math Helpers                                                     |
//+------------------------------------------------------------------+
//--- Clamp value between min and max
double Clamp(double value, double minVal, double maxVal)
{
   if(value < minVal) return minVal;
   if(value > maxVal) return maxVal;
   return value;
}

//--- Round to specified decimal places
double RoundTo(double value, int decimals)
{
   double factor = MathPow(10, decimals);
   return MathRound(value * factor) / factor;
}

//--- Round lot size to broker requirements
double NormalizeLot(string symbol, double lot)
{
   double minLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   // Round to lot step
   lot = MathRound(lot / lotStep) * lotStep;
   
   // Clamp to min/max
   return Clamp(lot, minLot, maxLot);
}

//--- Normalize price to symbol digits
double NormalizePrice(string symbol, double price)
{
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   return NormalizeDouble(price, digits);
}

//+------------------------------------------------------------------+
//| String Helpers                                                   |
//+------------------------------------------------------------------+
//--- Format money value
string FormatMoney(double value, int decimals = 2)
{
   return DoubleToString(value, decimals);
}

//--- Format percent value
string FormatPercent(double value, int decimals = 2)
{
   return DoubleToString(value, decimals) + "%";
}

//--- Format time duration
string FormatDuration(int seconds)
{
   int hours   = seconds / SECONDS_PER_HOUR;
   int minutes = (seconds % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE;
   int secs    = seconds % SECONDS_PER_MINUTE;
   
   if(hours > 0)
      return StringFormat("%dh %dm %ds", hours, minutes, secs);
   else if(minutes > 0)
      return StringFormat("%dm %ds", minutes, secs);
   else
      return StringFormat("%ds", secs);
}

//+------------------------------------------------------------------+
//| Trade Helpers                                                    |
//+------------------------------------------------------------------+
//--- Get point value in account currency
double GetPointValue(string symbol)
{
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double point     = SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   if(tickSize > 0)
      return tickValue * (point / tickSize);
   return 0.0;
}

//--- Calculate pips from points
double PointsToPips(string symbol, double points)
{
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   
   // For 5-digit brokers (e.g., EURUSD 1.12345)
   if(digits == 5 || digits == 3)
      return points / 10;
   return points;
}

//--- Calculate points from pips  
double PipsToPoints(string symbol, double pips)
{
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   
   if(digits == 5 || digits == 3)
      return pips * 10;
   return pips;
}

//--- Get current spread in points
double GetSpread(string symbol)
{
   return (double)SymbolInfoInteger(symbol, SYMBOL_SPREAD);
}

//--- Check if market is open
bool IsMarketOpen(string symbol)
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   datetime from, to;
   if(!SymbolInfoSessionTrade(symbol, (ENUM_DAY_OF_WEEK)dt.day_of_week, 0, from, to))
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Account Helpers                                                  |
//+------------------------------------------------------------------+
//--- Get account free margin
double GetFreeMargin()
{
   return AccountInfoDouble(ACCOUNT_MARGIN_FREE);
}

//--- Get account equity
double GetEquity()
{
   return AccountInfoDouble(ACCOUNT_EQUITY);
}

//--- Get account balance
double GetBalance()
{
   return AccountInfoDouble(ACCOUNT_BALANCE);
}

//--- Get current profit/loss
double GetCurrentPL()
{
   return AccountInfoDouble(ACCOUNT_PROFIT);
}

//--- Calculate margin required for lot size
double CalculateMarginRequired(string symbol, double lot, ENUM_ORDER_TYPE orderType)
{
   double margin = 0;
   
   if(orderType == ORDER_TYPE_BUY)
   {
      if(!OrderCalcMargin(ORDER_TYPE_BUY, symbol, lot, 
                          SymbolInfoDouble(symbol, SYMBOL_ASK), margin))
         return -1;
   }
   else if(orderType == ORDER_TYPE_SELL)
   {
      if(!OrderCalcMargin(ORDER_TYPE_SELL, symbol, lot,
                          SymbolInfoDouble(symbol, SYMBOL_BID), margin))
         return -1;
   }
   
   return margin;
}
//+------------------------------------------------------------------+
