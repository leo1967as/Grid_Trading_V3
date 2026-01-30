//+------------------------------------------------------------------+
//|                                               EmergencyStop.mqh  |
//|                           Grid Survival Protocol EA - Protection |
//|                                                                  |
//| Description: Level 1 Protection Layer                            |
//|              - Trigger at configurable DD% (default 10%)         |
//|              - Reduce grid size                                  |
//|              - Stop opening new positions                        |
//+------------------------------------------------------------------+
#property copyright "Grid Survival Protocol"
#property link      ""
#property version   "1.00"

#include "../Utils/Common.mqh"
#include "../Utils/Logger.mqh"
#include "DrawdownMonitor.mqh"

//+------------------------------------------------------------------+
//| Emergency Stop Actions                                           |
//+------------------------------------------------------------------+
enum ENUM_EMERGENCY_ACTION
{
   EMERGENCY_ACTION_NONE = 0,       // No action
   EMERGENCY_ACTION_REDUCE_SIZE,    // Reduce grid/lot size
   EMERGENCY_ACTION_STOP_NEW,       // Stop new trades
   EMERGENCY_ACTION_CLOSE_PROFIT,   // Close profitable positions only
   EMERGENCY_ACTION_CLOSE_HALF      // Close half of positions
};

//+------------------------------------------------------------------+
//| Emergency Stop Class                                             |
//+------------------------------------------------------------------+
class CEmergencyStop
{
private:
   double            m_triggerPercent;     // DD% to trigger (e.g., 10%)
   double            m_warningPercent;     // Warning level (e.g., 8%)
   double            m_sizeReduction;      // Size reduction multiplier (e.g., 0.5 = 50%)
   
   bool              m_isTriggered;        // Currently triggered
   bool              m_isWarning;          // Warning state
   datetime          m_triggerTime;        // Time of trigger
   int               m_triggerCount;       // How many times triggered today
   
   ENUM_EMERGENCY_ACTION m_lastAction;     // Last action taken
   bool              m_isInitialized;
   
public:
   //--- Constructor
   CEmergencyStop()
   {
      m_triggerPercent = 10.0;
      m_warningPercent = 8.0;
      m_sizeReduction  = 0.5;
      m_isTriggered    = false;
      m_isWarning      = false;
      m_triggerTime    = 0;
      m_triggerCount   = 0;
      m_lastAction     = EMERGENCY_ACTION_NONE;
      m_isInitialized  = false;
   }
   
   //--- Initialize
   bool Init(double triggerPercent = 10.0, double sizeReduction = 0.5)
   {
      m_triggerPercent = triggerPercent;
      m_warningPercent = triggerPercent * 0.8;  // Warning at 80% of trigger
      m_sizeReduction  = sizeReduction;
      
      Reset();
      
      m_isInitialized = true;
      Logger.Info(StringFormat("EmergencyStop initialized: Trigger=%.1f%%, Warning=%.1f%%, Reduction=%.0f%%",
                               m_triggerPercent, m_warningPercent, m_sizeReduction * 100));
      return true;
   }
   
   //--- Check drawdown and determine action (call every tick)
   ENUM_EMERGENCY_ACTION Check(double currentDrawdown)
   {
      if(!m_isInitialized)
         return EMERGENCY_ACTION_NONE;
      
      // Check trigger level
      if(currentDrawdown >= m_triggerPercent)
      {
         if(!m_isTriggered)
         {
            // First time triggering
            m_isTriggered  = true;
            m_isWarning    = false;
            m_triggerTime  = TimeCurrent();
            m_triggerCount++;
            m_lastAction   = EMERGENCY_ACTION_STOP_NEW;
            
            Logger.LogProtection("EmergencyStop", "TRIGGERED - Stop new trades", currentDrawdown);
            return m_lastAction;
         }
         
         // Already triggered, maintain state
         return EMERGENCY_ACTION_STOP_NEW;
      }
      // Check warning level
      else if(currentDrawdown >= m_warningPercent)
      {
         if(!m_isWarning && !m_isTriggered)
         {
            m_isWarning  = true;
            m_lastAction = EMERGENCY_ACTION_REDUCE_SIZE;
            
            Logger.LogProtection("EmergencyStop", "WARNING - Reduce size", currentDrawdown);
            return m_lastAction;
         }
         
         if(m_isTriggered)
         {
            // Still above warning, maintain stop new
            return EMERGENCY_ACTION_STOP_NEW;
         }
         
         return EMERGENCY_ACTION_REDUCE_SIZE;
      }
      else
      {
         // Below warning level
         if(m_isTriggered || m_isWarning)
         {
            // Recovery - but don't reset immediately, wait for better recovery
            if(currentDrawdown < m_warningPercent * 0.5)  // Below 50% of warning
            {
               Logger.Info(StringFormat("EmergencyStop recovered: DD=%.2f%%", currentDrawdown));
               m_isTriggered = false;
               m_isWarning   = false;
               m_lastAction  = EMERGENCY_ACTION_NONE;
            }
         }
         
         return EMERGENCY_ACTION_NONE;
      }
   }
   
   //--- Check if triggered
   bool IsTriggered() const
   {
      return m_isTriggered;
   }
   
   //--- Check if in warning state
   bool IsWarning() const
   {
      return m_isWarning;
   }
   
   //--- Get size multiplier (1.0 = normal, 0.5 = half size)
   double GetSizeMultiplier() const
   {
      if(m_isTriggered)
         return m_sizeReduction * 0.5;  // Even smaller when triggered
      else if(m_isWarning)
         return m_sizeReduction;
      return 1.0;
   }
   
   //--- Check if new trades allowed
   bool CanOpenNewTrades() const
   {
      return !m_isTriggered;
   }
   
   //--- Get trigger time
   datetime GetTriggerTime() const
   {
      return m_triggerTime;
   }
   
   //--- Get trigger count today
   int GetTriggerCount() const
   {
      return m_triggerCount;
   }
   
   //--- Get last action
   ENUM_EMERGENCY_ACTION GetLastAction() const
   {
      return m_lastAction;
   }
   
   //--- Reset (use with caution)
   void Reset()
   {
      m_isTriggered  = false;
      m_isWarning    = false;
      m_triggerTime  = 0;
      m_lastAction   = EMERGENCY_ACTION_NONE;
      // Note: don't reset trigger count here
   }
   
   //--- Reset daily counters
   void ResetDaily()
   {
      m_triggerCount = 0;
      Reset();
   }
   
   //--- Get status string
   string GetStatus() const
   {
      if(m_isTriggered)
         return StringFormat("TRIGGERED (Count: %d)", m_triggerCount);
      else if(m_isWarning)
         return "WARNING";
      return "OK";
   }
   
   //--- Check if initialized
   bool IsInitialized() const
   {
      return m_isInitialized;
   }
};
//+------------------------------------------------------------------+
