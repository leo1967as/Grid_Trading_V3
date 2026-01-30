//+------------------------------------------------------------------+
//|                                             DailyLossLimit.mqh   |
//|                           Grid Survival Protocol EA - Protection |
//|                                                                  |
//| Description: Daily Loss Limit Protection                         |
//|              - Track daily P/L                                   |
//|              - Stop trading when daily limit reached             |
//|              - Auto-reset next day                               |
//+------------------------------------------------------------------+
#property copyright "Grid Survival Protocol"
#property link      ""
#property version   "1.00"

#include "../Utils/Common.mqh"
#include "../Utils/Logger.mqh"

//+------------------------------------------------------------------+
//| Daily Loss Limit Class                                           |
//+------------------------------------------------------------------+
class CDailyLossLimit
{
private:
   double            m_limitPercent;       // Daily loss limit (%)
   double            m_warningPercent;     // Warning level (%)
   
   double            m_dailyStartEquity;   // Equity at day start
   double            m_dailyStartBalance;  // Balance at day start
   double            m_dailyPL;            // Today's P/L ($)
   double            m_dailyPLPercent;     // Today's P/L (%)
   
   bool              m_isTriggered;        // Daily limit reached
   datetime          m_dayStartTime;       // Start of current day
   datetime          m_nextResetTime;      // Next daily reset time
   int               m_triggerCount;       // Total times triggered (historical)
   
   bool              m_isInitialized;
   
public:
   //--- Constructor
   CDailyLossLimit()
   {
      m_limitPercent     = 5.0;
      m_warningPercent   = 4.0;
      m_dailyStartEquity = 0;
      m_dailyStartBalance = 0;
      m_dailyPL          = 0;
      m_dailyPLPercent   = 0;
      m_isTriggered      = false;
      m_dayStartTime     = 0;
      m_nextResetTime    = 0;
      m_triggerCount     = 0;
      m_isInitialized    = false;
   }
   
   //--- Initialize
   bool Init(double limitPercent = 5.0)
   {
      m_limitPercent   = limitPercent;
      m_warningPercent = limitPercent * 0.8;  // Warning at 80%
      
      // Initialize daily tracking
      ResetDaily();
      
      m_isInitialized = true;
      Logger.Info(StringFormat("DailyLossLimit initialized: Limit=%.1f%%, Warning=%.1f%%",
                               m_limitPercent, m_warningPercent));
      return true;
   }
   
   //--- Update daily P/L (call every tick)
   void Update()
   {
      if(!m_isInitialized)
         return;
      
      // Check for daily reset
      if(TimeCurrent() >= m_nextResetTime)
      {
         ResetDaily();
         return;
      }
      
      // Calculate daily P/L
      double currentEquity = GetEquity();
      m_dailyPL = currentEquity - m_dailyStartEquity;
      
      if(m_dailyStartEquity > 0)
         m_dailyPLPercent = (m_dailyPL / m_dailyStartEquity) * 100.0;
      else
         m_dailyPLPercent = 0;
   }
   
   //--- Check if limit reached (returns true if should stop)
   bool Check()
   {
      if(!m_isInitialized)
         return false;
      
      // Already triggered, stay triggered until reset
      if(m_isTriggered)
         return true;
      
      // Check if daily loss exceeds limit (negative P/L)
      if(m_dailyPLPercent <= -m_limitPercent)
      {
         m_isTriggered = true;
         m_triggerCount++;
         
         Logger.Critical(StringFormat("DAILY LOSS LIMIT REACHED: P/L=%.2f (%.2f%%)",
                                      m_dailyPL, m_dailyPLPercent));
         Alert("GRID EA: Daily loss limit reached! P/L: ", 
               DoubleToString(m_dailyPL, 2), " (", 
               DoubleToString(m_dailyPLPercent, 2), "%)");
         
         return true;
      }
      
      // Check warning level
      if(m_dailyPLPercent <= -m_warningPercent)
      {
         Logger.Warning(StringFormat("Daily loss warning: P/L=%.2f (%.2f%%), Limit=%.1f%%",
                                     m_dailyPL, m_dailyPLPercent, m_limitPercent));
      }
      
      return false;
   }
   
   //--- Check if triggered
   bool IsTriggered() const
   {
      return m_isTriggered;
   }
   
   //--- Check if in warning zone
   bool IsWarning() const
   {
      return m_dailyPLPercent <= -m_warningPercent && !m_isTriggered;
   }
   
   //--- Get daily P/L
   double GetDailyPL() const
   {
      return m_dailyPL;
   }
   
   //--- Get daily P/L percent
   double GetDailyPLPercent() const
   {
      return m_dailyPLPercent;
   }
   
   //--- Get remaining loss allowance
   double GetRemainingAllowance() const
   {
      return m_limitPercent + m_dailyPLPercent;  // If PL is -3%, limit 5%, remaining = 2%
   }
   
   //--- Get time until reset
   int GetSecondsUntilReset() const
   {
      return (int)(m_nextResetTime - TimeCurrent());
   }
   
   //--- Get trigger count
   int GetTriggerCount() const
   {
      return m_triggerCount;
   }
   
   //--- Reset daily tracking
   void ResetDaily()
   {
      m_dailyStartEquity  = GetEquity();
      m_dailyStartBalance = GetBalance();
      m_dailyPL           = 0;
      m_dailyPLPercent    = 0;
      m_isTriggered       = false;
      m_dayStartTime      = TimeCurrent();
      
      // Calculate next reset time (00:00 server time next day)
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      dt.hour = 0;
      dt.min  = 0;
      dt.sec  = 0;
      dt.day  += 1;
      m_nextResetTime = StructToTime(dt);
      
      Logger.Info(StringFormat("Daily reset: StartEquity=%.2f, NextReset=%s",
                               m_dailyStartEquity, TimeToString(m_nextResetTime)));
   }
   
   //--- Get status string
   string GetStatus() const
   {
      if(m_isTriggered)
         return StringFormat("LIMIT REACHED (P/L: %.2f%%)", m_dailyPLPercent);
      else if(IsWarning())
         return StringFormat("WARNING (P/L: %.2f%%)", m_dailyPLPercent);
      return StringFormat("OK (P/L: %.2f%%)", m_dailyPLPercent);
   }
   
   //--- Get detailed status
   string GetDetailedStatus() const
   {
      int hoursRemaining = GetSecondsUntilReset() / 3600;
      int minsRemaining  = (GetSecondsUntilReset() % 3600) / 60;
      
      return StringFormat(
         "Daily: P/L=%.2f (%.2f%%) | Limit=%.1f%% | Remaining=%.2f%% | Reset in %dh %dm",
         m_dailyPL, m_dailyPLPercent, m_limitPercent, 
         GetRemainingAllowance(), hoursRemaining, minsRemaining
      );
   }
   
   //--- Check if initialized
   bool IsInitialized() const
   {
      return m_isInitialized;
   }
};
//+------------------------------------------------------------------+
