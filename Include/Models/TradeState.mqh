//+------------------------------------------------------------------+
//|                                                   TradeState.mqh |
//|                               Grid Survival Protocol EA - Models |
//|                                                                  |
//| Description: System State Enumerations and Structures            |
//|              - EA operating states                               |
//|              - Trading modes                                     |
//|              - Market conditions                                 |
//+------------------------------------------------------------------+
#property copyright "Grid Survival Protocol"
#property link      ""
#property version   "1.00"

//+------------------------------------------------------------------+
//| EA Operating States                                              |
//+------------------------------------------------------------------+
enum ENUM_EA_STATE
{
   EA_STATE_INITIALIZING = 0,   // EA is starting up
   EA_STATE_IDLE,               // Waiting for conditions
   EA_STATE_TRADING,            // Normal trading mode
   EA_STATE_PAUSED,             // Temporarily paused
   EA_STATE_EMERGENCY,          // Emergency mode (Level 1 triggered)
   EA_STATE_RECOVERY,           // Recovery mode (rebuilding equity)
   EA_STATE_LOCKED,             // Soft Lock mode (Hedge active)
   EA_STATE_STOPPED,            // Stopped by HardStop or DailyLimit
   EA_STATE_ERROR               // Error state
};

//+------------------------------------------------------------------+
//| Trading Modes                                                    |
//+------------------------------------------------------------------+
enum ENUM_TRADING_MODE
{
   TRADING_MODE_NORMAL = 0,     // Normal operation
   TRADING_MODE_REDUCED,        // Reduced position sizing
   TRADING_MODE_CLOSE_ONLY,     // Close only, no new trades
   TRADING_MODE_NO_NEW_TRADES,  // Alias for CLOSE_ONLY
   TRADING_MODE_CLOSE_ALL       // Close all positions immediately
};

//+------------------------------------------------------------------+
//| Market Condition                                                 |
//+------------------------------------------------------------------+
enum ENUM_MARKET_CONDITION
{
   MARKET_CONDITION_UNKNOWN = 0,  // Cannot determine
   MARKET_CONDITION_TRENDING,     // Strong trend detected
   MARKET_CONDITION_RANGING,      // Sideways/ranging market
   MARKET_CONDITION_VOLATILE,     // High volatility
   MARKET_CONDITION_QUIET         // Low volatility
};

//+------------------------------------------------------------------+
//| Session State                                                    |
//+------------------------------------------------------------------+
enum ENUM_SESSION_STATE
{
   SESSION_STATE_CLOSED = 0,      // Outside trading hours
   SESSION_STATE_OPEN,            // Normal trading session
   SESSION_STATE_NEWS_PAUSE,      // Paused due to news
   SESSION_STATE_ROLLOVER         // Rollover period
};

//+------------------------------------------------------------------+
//| Trade Signal                                                     |
//+------------------------------------------------------------------+
enum ENUM_TRADE_SIGNAL
{
   SIGNAL_NONE = 0,               // No signal
   SIGNAL_BUY,                    // Buy signal
   SIGNAL_SELL,                   // Sell signal
   SIGNAL_CLOSE_BUY,              // Close buy positions
   SIGNAL_CLOSE_SELL,             // Close sell positions
   SIGNAL_CLOSE_ALL               // Close all positions
};

//+------------------------------------------------------------------+
//| Trade Direction Mode (Phase 5.5: Bidirectional)                  |
//+------------------------------------------------------------------+
enum ENUM_TRADE_DIRECTION_MODE
{
   DIRECTION_LONG_ONLY = 0,       // Long Only (Buy Grid)
   DIRECTION_SHORT_ONLY,          // Short Only (Sell Grid)
   DIRECTION_BOTH                 // Both Directions
};

//+------------------------------------------------------------------+
//| System State Structure                                           |
//+------------------------------------------------------------------+
struct SSystemState
{
   ENUM_EA_STATE           eaState;           // Current EA state
   ENUM_TRADING_MODE       tradingMode;       // Current trading mode
   ENUM_MARKET_CONDITION   marketCondition;   // Detected market condition
   ENUM_SESSION_STATE      sessionState;      // Current session state
   
   datetime                stateChangeTime;   // Last state change time
   string                  stateReason;       // Reason for current state
   
   //--- Financial metrics
   double                  startingEquity;    // Equity at EA start
   double                  currentEquity;     // Current equity
   double                  highWaterMark;     // Highest equity reached
   double                  currentDrawdown;   // Current DD from high water mark (%)
   double                  dailyPL;           // Today's P/L
   double                  dailyPLPercent;    // Today's P/L in %
   
   //--- Constructor
   void SSystemState()
   {
      Reset();
   }
   
   //--- Reset to default values
   void Reset()
   {
      eaState         = EA_STATE_INITIALIZING;
      tradingMode     = TRADING_MODE_NORMAL;
      marketCondition = MARKET_CONDITION_UNKNOWN;
      sessionState    = SESSION_STATE_CLOSED;
      
      stateChangeTime = 0;
      stateReason     = "";
      
      startingEquity  = 0.0;
      currentEquity   = 0.0;
      highWaterMark   = 0.0;
      currentDrawdown = 0.0;
      dailyPL         = 0.0;
      dailyPLPercent  = 0.0;
   }
   
   //--- Initialize with current account values
   void Init()
   {
      Reset();
      startingEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      currentEquity  = startingEquity;
      highWaterMark  = startingEquity;
      eaState        = EA_STATE_IDLE;
      sessionState   = SESSION_STATE_OPEN;
   }
   
   //--- Check if trading is allowed
   bool IsTradingAllowed() const
   {
      return (eaState == EA_STATE_TRADING || eaState == EA_STATE_IDLE) &&
             (tradingMode == TRADING_MODE_NORMAL || tradingMode == TRADING_MODE_REDUCED) &&
             (sessionState == SESSION_STATE_OPEN);
   }
   
   //--- Check if new trades are allowed
   bool CanOpenNewTrades() const
   {
      return IsTradingAllowed() && tradingMode != TRADING_MODE_NO_NEW_TRADES;
   }
   
   //--- Check if in emergency or worse
   bool IsEmergencyOrWorse() const
   {
      return (eaState == EA_STATE_EMERGENCY || 
              eaState == EA_STATE_STOPPED || 
              eaState == EA_STATE_ERROR);
   }
   
   //--- Update drawdown calculation
   void UpdateDrawdown()
   {
      if(highWaterMark > 0)
         currentDrawdown = ((highWaterMark - currentEquity) / highWaterMark) * 100.0;
      else
         currentDrawdown = 0.0;
   }
   
   //--- Set new state with reason
   void SetState(ENUM_EA_STATE newState, string reason = "")
   {
      if(eaState != newState)
      {
         eaState         = newState;
         stateChangeTime = TimeCurrent();
         stateReason     = reason;
      }
   }
   
   //--- Get state description
   string GetStateDescription() const
   {
      switch(eaState)
      {
         case EA_STATE_INITIALIZING: return "Initializing";
         case EA_STATE_IDLE:         return "Idle";
         case EA_STATE_TRADING:      return "Trading";
         case EA_STATE_EMERGENCY:    return "EMERGENCY";
         case EA_STATE_RECOVERY:     return "Recovery";
         case EA_STATE_LOCKED:       return "LOCKED (Hedged)";
         case EA_STATE_STOPPED:      return "STOPPED";
         case EA_STATE_ERROR:        return "ERROR";
         default:                    return "Unknown";
      }
   }
};
//+------------------------------------------------------------------+
