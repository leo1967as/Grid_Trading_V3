//+------------------------------------------------------------------+
//|                                                  MarketState.mqh |
//|                            Grid Survival Protocol EA - Analysis  |
//|                                                                  |
//| Description: Market Condition Detection                          |
//|              - Trend/Range detection using ADX                   |
//|              - Volatility classification                         |
//+------------------------------------------------------------------+
#property copyright "Grid Survival Protocol"
#property link      ""
#property version   "1.00"

#include "../Utils/Common.mqh"
#include "../Utils/Logger.mqh"
#include "../Models/TradeState.mqh"

//+------------------------------------------------------------------+
//| Market State Class                                               |
//+------------------------------------------------------------------+
class CMarketState
{
private:
   string            m_symbol;           // Trading symbol
   ENUM_TIMEFRAMES   m_timeframe;        // Analysis timeframe
   
   int               m_adxHandle;        // ADX indicator handle
   int               m_adxPeriod;        // ADX period
   double            m_adxBuffer[];      // ADX main values
   double            m_plusDI[];         // +DI values
   double            m_minusDI[];        // -DI values
   
   double            m_trendThreshold;   // ADX threshold for trend (e.g., 25)
   double            m_strongTrendThreshold; // Strong trend threshold (e.g., 40)
   
   ENUM_MARKET_CONDITION m_currentState; // Current detected state
   double            m_adxValue;         // Current ADX value
   int               m_trendDirection;   // 1=up, -1=down, 0=none
   
   bool              m_isInitialized;
   
public:
   //--- Constructor
   CMarketState()
   {
      m_symbol              = "";
      m_timeframe           = PERIOD_CURRENT;
      m_adxHandle           = INVALID_HANDLE;
      m_adxPeriod           = 14;
      m_trendThreshold      = 25.0;
      m_strongTrendThreshold = 40.0;
      m_currentState        = MARKET_CONDITION_UNKNOWN;
      m_adxValue            = 0;
      m_trendDirection      = 0;
      m_isInitialized       = false;
      
      ArraySetAsSeries(m_adxBuffer, true);
      ArraySetAsSeries(m_plusDI, true);
      ArraySetAsSeries(m_minusDI, true);
   }
   
   //--- Destructor
   ~CMarketState()
   {
      Deinit();
   }
   
   //--- Initialize
   bool Init(string symbol, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT, 
             int adxPeriod = 14, double trendThreshold = 25.0)
   {
      m_symbol         = symbol;
      m_timeframe      = timeframe;
      m_adxPeriod      = adxPeriod;
      m_trendThreshold = trendThreshold;
      m_strongTrendThreshold = trendThreshold * 1.6;
      
      // Create ADX indicator
      m_adxHandle = iADX(m_symbol, m_timeframe, m_adxPeriod);
      if(m_adxHandle == INVALID_HANDLE)
      {
         Logger.Error("Failed to create ADX indicator");
         return false;
      }
      
      m_isInitialized = true;
      Logger.Info(StringFormat("MarketState initialized: Symbol=%s, TF=%s, ADX=%d, Trend=%.0f",
                               m_symbol, EnumToString(m_timeframe), m_adxPeriod, m_trendThreshold));
      return true;
   }
   
   //--- Deinitialize
   void Deinit()
   {
      if(m_adxHandle != INVALID_HANDLE)
      {
         IndicatorRelease(m_adxHandle);
         m_adxHandle = INVALID_HANDLE;
      }
      m_isInitialized = false;
   }
   
   //--- Update market state (call on each bar or regularly)
   bool Update()
   {
      if(!m_isInitialized || m_adxHandle == INVALID_HANDLE)
         return false;
      
      // Copy ADX values
      if(CopyBuffer(m_adxHandle, 0, 0, 3, m_adxBuffer) <= 0)
      {
         Logger.Error("Failed to copy ADX buffer");
         return false;
      }
      
      // Copy +DI and -DI
      CopyBuffer(m_adxHandle, 1, 0, 3, m_plusDI);
      CopyBuffer(m_adxHandle, 2, 0, 3, m_minusDI);
      
      m_adxValue = m_adxBuffer[0];
      
      // Determine trend direction
      if(m_plusDI[0] > m_minusDI[0])
         m_trendDirection = 1;  // Uptrend
      else if(m_minusDI[0] > m_plusDI[0])
         m_trendDirection = -1; // Downtrend
      else
         m_trendDirection = 0;  // Neutral
      
      // Classify market condition
      ClassifyMarket();
      
      return true;
   }
   
   //--- Get current market condition
   ENUM_MARKET_CONDITION GetCondition() const
   {
      return m_currentState;
   }
   
   //--- Get ADX value
   double GetADX() const
   {
      return m_adxValue;
   }
   
   //--- Get trend direction (1=up, -1=down, 0=none)
   int GetTrendDirection() const
   {
      return m_trendDirection;
   }
   
   //--- Check if market is trending
   bool IsTrending() const
   {
      return m_currentState == MARKET_CONDITION_TRENDING;
   }
   
   //--- Check if market is ranging (good for grid)
   bool IsRanging() const
   {
      return m_currentState == MARKET_CONDITION_RANGING;
   }
   
   //--- Check if high volatility
   bool IsVolatile() const
   {
      return m_currentState == MARKET_CONDITION_VOLATILE;
   }
   
   //--- Check if suitable for grid trading
   bool IsSuitableForGrid() const
   {
      // Grid works best in ranging/quiet markets
      return m_currentState == MARKET_CONDITION_RANGING ||
             m_currentState == MARKET_CONDITION_QUIET;
   }
   
   //--- Get condition string
   string GetConditionString() const
   {
      switch(m_currentState)
      {
         case MARKET_CONDITION_TRENDING:  return "TRENDING";
         case MARKET_CONDITION_RANGING:   return "RANGING";
         case MARKET_CONDITION_VOLATILE:  return "VOLATILE";
         case MARKET_CONDITION_QUIET:     return "QUIET";
         default:                         return "UNKNOWN";
      }
   }
   
   //--- Get status summary
   string GetStatusSummary() const
   {
      string dirStr = m_trendDirection > 0 ? "UP" : 
                      m_trendDirection < 0 ? "DOWN" : "NEUTRAL";
      return StringFormat("Market: %s | ADX=%.1f | Dir=%s | GridOK=%s",
                          GetConditionString(), m_adxValue, dirStr,
                          IsSuitableForGrid() ? "YES" : "NO");
   }
   
   //--- Check if initialized
   bool IsInitialized() const
   {
      return m_isInitialized;
   }
   
private:
   //--- Classify market condition
   void ClassifyMarket()
   {
      if(m_adxValue >= m_strongTrendThreshold)
      {
         m_currentState = MARKET_CONDITION_VOLATILE;  // Strong trend = volatile
      }
      else if(m_adxValue >= m_trendThreshold)
      {
         m_currentState = MARKET_CONDITION_TRENDING;
      }
      else if(m_adxValue >= 15)
      {
         m_currentState = MARKET_CONDITION_RANGING;
      }
      else
      {
         m_currentState = MARKET_CONDITION_QUIET;
      }
   }
};
//+------------------------------------------------------------------+
