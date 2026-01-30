//+------------------------------------------------------------------+
//|                                                    HardStop.mqh  |
//|                           Grid Survival Protocol EA - Protection |
//|                                                                  |
//| Description: Level 2 Protection Layer - Ultimate Defense         |
//|              - Trigger at configurable DD% (default 20%)         |
//|              - Close ALL positions immediately                   |
//|              - Stop EA completely until manual reset             |
//+------------------------------------------------------------------+
#property copyright "Grid Survival Protocol"
#property link      ""
#property version   "1.00"

#include "../Utils/Common.mqh"
#include "../Utils/Logger.mqh"

//+------------------------------------------------------------------+
//| Hard Stop Class                                                  |
//+------------------------------------------------------------------+
class CHardStop
{
private:
   double            m_triggerPercent;     // DD% to trigger (e.g., 20%)
   double            m_warningPercent;     // Warning level (e.g., 18%)
   
   bool              m_isTriggered;        // Currently triggered
   bool              m_isLocked;           // System locked (requires manual reset)
   datetime          m_triggerTime;        // Time of trigger
   double            m_triggerDrawdown;    // DD when triggered
   string            m_triggerReason;      // Reason for trigger
   
   bool              m_isInitialized;
   
public:
   //--- Constructor
   CHardStop()
   {
      m_triggerPercent   = 20.0;
      m_warningPercent   = 18.0;
      m_isTriggered      = false;
      m_isLocked         = false;
      m_triggerTime      = 0;
      m_triggerDrawdown  = 0;
      m_triggerReason    = "";
      m_isInitialized    = false;
   }
   
   //--- Initialize
   bool Init(double triggerPercent = 20.0)
   {
      m_triggerPercent = triggerPercent;
      m_warningPercent = triggerPercent * 0.9;  // Warning at 90% of trigger
      
      m_isTriggered     = false;
      m_isLocked        = false;
      m_triggerTime     = 0;
      m_triggerDrawdown = 0;
      m_triggerReason   = "";
      
      m_isInitialized = true;
      Logger.Info(StringFormat("HardStop initialized: Trigger=%.1f%%, Warning=%.1f%%",
                               m_triggerPercent, m_warningPercent));
      return true;
   }
   
   //--- Check drawdown (call every tick)
   //--- Returns true if should close all positions
   bool Check(double currentDrawdown)
   {
      if(!m_isInitialized)
         return false;
      
      // If already locked, stay locked
      if(m_isLocked)
         return true;
      
      // Check trigger level
      if(currentDrawdown >= m_triggerPercent)
      {
         if(!m_isTriggered)
         {
            Trigger(currentDrawdown, "Drawdown exceeded hard stop limit");
         }
         return true;
      }
      
      // Check warning level
      if(currentDrawdown >= m_warningPercent && !m_isTriggered)
      {
         Logger.Warning(StringFormat("HardStop WARNING: DD=%.2f%% approaching trigger at %.1f%%",
                                     currentDrawdown, m_triggerPercent));
      }
      
      return false;
   }
   
   //--- Manual trigger (for external events)
   void Trigger(double drawdown, string reason)
   {
      m_isTriggered     = true;
      m_isLocked        = true;
      m_triggerTime     = TimeCurrent();
      m_triggerDrawdown = drawdown;
      m_triggerReason   = reason;
      
      Logger.Critical(StringFormat("HARD STOP TRIGGERED: DD=%.2f%%, Reason: %s",
                                   drawdown, reason));
      
      // Send alert
      Alert("GRID EA HARD STOP: ", reason, " DD=", DoubleToString(drawdown, 2), "%");
   }
   
   //--- Check if triggered
   bool IsTriggered() const
   {
      return m_isTriggered;
   }
   
   //--- Check if locked
   bool IsLocked() const
   {
      return m_isLocked;
   }
   
   //--- Check if approaching trigger
   bool IsApproaching(double currentDrawdown) const
   {
      return currentDrawdown >= m_warningPercent;
   }
   
   //--- Get trigger time
   datetime GetTriggerTime() const
   {
      return m_triggerTime;
   }
   
   //--- Get trigger drawdown
   double GetTriggerDrawdown() const
   {
      return m_triggerDrawdown;
   }
   
   //--- Get trigger reason
   string GetTriggerReason() const
   {
      return m_triggerReason;
   }
   
   //--- Manual reset (use with extreme caution!)
   //--- Should only be called after user confirmation
   bool ManualReset(bool confirmed)
   {
      if(!confirmed)
      {
         Logger.Warning("HardStop reset rejected - confirmation required");
         return false;
      }
      
      Logger.Warning("HardStop manually reset - USE WITH CAUTION!");
      
      m_isTriggered     = false;
      m_isLocked        = false;
      m_triggerTime     = 0;
      m_triggerDrawdown = 0;
      m_triggerReason   = "";
      
      return true;
   }
   
   //--- Get status string
   string GetStatus() const
   {
      if(m_isLocked)
         return StringFormat("LOCKED (DD: %.2f%%, Time: %s, Reason: %s)", 
                             m_triggerDrawdown,
                             TimeToString(m_triggerTime, TIME_SECONDS),
                             m_triggerReason);
      else if(m_isTriggered)
         return "TRIGGERED";
      return "OK";
   }
   
   //--- Get trigger percent
   double GetTriggerPercent() const
   {
      return m_triggerPercent;
   }
   
   //--- Check if initialized
   bool IsInitialized() const
   {
      return m_isInitialized;
   }
};
//+------------------------------------------------------------------+
