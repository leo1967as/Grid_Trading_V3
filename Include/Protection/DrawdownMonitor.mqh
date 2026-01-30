//+------------------------------------------------------------------+
//|                                            DrawdownMonitor.mqh   |
//|                           Grid Survival Protocol EA - Protection |
//|                                                                  |
//| Description: Real-time Drawdown Monitoring                       |
//|              - Continuous DD tracking                            |
//|              - Threshold warnings                                |
//|              - Callback triggers                                 |
//+------------------------------------------------------------------+
#property copyright "Grid Survival Protocol"
#property link      ""
#property version   "1.00"

#include "../Utils/Common.mqh"
#include "../Utils/Logger.mqh"

//+------------------------------------------------------------------+
//| Drawdown Type Enum                                               |
//+------------------------------------------------------------------+
enum ENUM_DRAWDOWN_TYPE
{
   DD_FROM_BALANCE = 0,      // Drawdown from starting balance
   DD_FROM_HIGH_WATER_MARK,  // Drawdown from highest equity
   DD_DAILY                  // Daily drawdown
};

//+------------------------------------------------------------------+
//| Drawdown Metrics Structure                                       |
//+------------------------------------------------------------------+
struct SDrawdownMetrics
{
   double   currentEquity;      // Current equity
   double   currentBalance;     // Current balance
   double   startingBalance;    // Starting balance
   double   highWaterMark;      // Highest equity reached
   double   dailyStartEquity;   // Equity at day start
   
   double   ddFromBalance;      // DD from starting balance (%)
   double   ddFromHWM;          // DD from high water mark (%)
   double   ddDaily;            // Daily DD (%)
   double   maxDDReached;       // Maximum DD reached (%)
   
   datetime lastUpdateTime;     // Last update timestamp
   datetime dailyResetTime;     // Next daily reset time
   
   void Reset()
   {
      currentEquity    = 0;
      currentBalance   = 0;
      startingBalance  = 0;
      highWaterMark    = 0;
      dailyStartEquity = 0;
      ddFromBalance    = 0;
      ddFromHWM        = 0;
      ddDaily          = 0;
      maxDDReached     = 0;
      lastUpdateTime   = 0;
      dailyResetTime   = 0;
   }
};

//+------------------------------------------------------------------+
//| Drawdown Monitor Class                                           |
//+------------------------------------------------------------------+
class CDrawdownMonitor
{
private:
   SDrawdownMetrics  m_metrics;        // Current metrics
   bool              m_isInitialized;
   
public:
   //--- Constructor
   CDrawdownMonitor()
   {
      m_metrics.Reset();
      m_isInitialized = false;
   }
   
   //--- Initialize monitor
   bool Init()
   {
      m_metrics.Reset();
      
      m_metrics.currentEquity    = GetEquity();
      m_metrics.currentBalance   = GetBalance();
      m_metrics.startingBalance  = m_metrics.currentBalance;
      m_metrics.highWaterMark    = m_metrics.currentEquity;
      m_metrics.dailyStartEquity = m_metrics.currentEquity;
      m_metrics.lastUpdateTime   = TimeCurrent();
      
      // Set daily reset time to next day 00:00
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      dt.hour = 0;
      dt.min  = 0;
      dt.sec  = 0;
      dt.day  += 1;
      m_metrics.dailyResetTime = StructToTime(dt);
      
      m_isInitialized = true;
      Logger.Info(StringFormat("DrawdownMonitor initialized: Equity=%.2f, Balance=%.2f",
                               m_metrics.currentEquity, m_metrics.currentBalance));
      return true;
   }
   
   //--- Update metrics (call on every tick)
   void Update()
   {
      if(!m_isInitialized)
         return;
      
      // Check for daily reset
      CheckDailyReset();
      
      // Update current values
      m_metrics.currentEquity  = GetEquity();
      m_metrics.currentBalance = GetBalance();
      m_metrics.lastUpdateTime = TimeCurrent();
      
      // Update high water mark
      if(m_metrics.currentEquity > m_metrics.highWaterMark)
         m_metrics.highWaterMark = m_metrics.currentEquity;
      
      // Calculate drawdowns
      CalculateDrawdowns();
   }
   
   //--- Get current metrics
   SDrawdownMetrics GetMetrics() const
   {
      return m_metrics;
   }
   
   //--- Get drawdown by type
   double GetDrawdown(ENUM_DRAWDOWN_TYPE type) const
   {
      switch(type)
      {
         case DD_FROM_BALANCE:      return m_metrics.ddFromBalance;
         case DD_FROM_HIGH_WATER_MARK: return m_metrics.ddFromHWM;
         case DD_DAILY:             return m_metrics.ddDaily;
         default:                   return 0;
      }
   }
   
   //--- Get current drawdown (from HWM - most commonly used)
   double GetCurrentDrawdown() const
   {
      return m_metrics.ddFromHWM;
   }
   
   //--- Get daily drawdown
   double GetDailyDrawdown() const
   {
      return m_metrics.ddDaily;
   }
   
   //--- Get max drawdown reached
   double GetMaxDrawdown() const
   {
      return m_metrics.maxDDReached;
   }
   
   //--- Check if drawdown exceeds threshold
   bool IsExceedingThreshold(double threshold, ENUM_DRAWDOWN_TYPE type = DD_FROM_HIGH_WATER_MARK)
   {
      return GetDrawdown(type) >= threshold;
   }
   
   //--- Check if approaching threshold (80% of threshold)
   bool IsApproachingThreshold(double threshold, ENUM_DRAWDOWN_TYPE type = DD_FROM_HIGH_WATER_MARK)
   {
      return GetDrawdown(type) >= (threshold * 0.8);
   }
   
   //--- Reset high water mark (after recovery)
   void ResetHighWaterMark()
   {
      m_metrics.highWaterMark = m_metrics.currentEquity;
      m_metrics.maxDDReached  = 0;
      Logger.Info(StringFormat("HWM reset to: %.2f", m_metrics.highWaterMark));
   }
   
   //--- Force daily reset
   void ForceDailyReset()
   {
      m_metrics.dailyStartEquity = m_metrics.currentEquity;
      m_metrics.ddDaily = 0;
      
      // Update reset time
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      dt.hour = 0;
      dt.min  = 0;
      dt.sec  = 0;
      dt.day  += 1;
      m_metrics.dailyResetTime = StructToTime(dt);
      
      Logger.Info("Daily metrics reset");
   }
   
   //--- Get status summary
   string GetStatusSummary()
   {
      return StringFormat(
         "DD Monitor: Equity=%.2f | DD: Balance=%.2f%% HWM=%.2f%% Daily=%.2f%% | Max=%.2f%%",
         m_metrics.currentEquity,
         m_metrics.ddFromBalance,
         m_metrics.ddFromHWM,
         m_metrics.ddDaily,
         m_metrics.maxDDReached
      );
   }
   
   //--- Check if initialized
   bool IsInitialized() const
   {
      return m_isInitialized;
   }
   
private:
   //--- Calculate all drawdown percentages
   void CalculateDrawdowns()
   {
      // DD from starting balance
      if(m_metrics.startingBalance > 0)
      {
         m_metrics.ddFromBalance = 
            ((m_metrics.startingBalance - m_metrics.currentEquity) / m_metrics.startingBalance) * 100.0;
      }
      
      // DD from high water mark
      if(m_metrics.highWaterMark > 0)
      {
         m_metrics.ddFromHWM = 
            ((m_metrics.highWaterMark - m_metrics.currentEquity) / m_metrics.highWaterMark) * 100.0;
      }
      
      // Daily DD
      if(m_metrics.dailyStartEquity > 0)
      {
         m_metrics.ddDaily = 
            ((m_metrics.dailyStartEquity - m_metrics.currentEquity) / m_metrics.dailyStartEquity) * 100.0;
      }
      
      // Ensure non-negative (profit = 0 DD)
      m_metrics.ddFromBalance = MathMax(0, m_metrics.ddFromBalance);
      m_metrics.ddFromHWM     = MathMax(0, m_metrics.ddFromHWM);
      m_metrics.ddDaily       = MathMax(0, m_metrics.ddDaily);
      
      // Update max DD
      if(m_metrics.ddFromHWM > m_metrics.maxDDReached)
         m_metrics.maxDDReached = m_metrics.ddFromHWM;
   }
   
   //--- Check and perform daily reset
   void CheckDailyReset()
   {
      if(TimeCurrent() >= m_metrics.dailyResetTime)
      {
         ForceDailyReset();
      }
   }
};
//+------------------------------------------------------------------+
