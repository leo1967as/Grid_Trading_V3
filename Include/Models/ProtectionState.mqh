//+------------------------------------------------------------------+
//|                                             ProtectionState.mqh  |
//|                               Grid Survival Protocol EA - Models |
//|                                                                  |
//| Description: Protection Layer State Tracking                     |
//|              - Emergency Stop state                              |
//|              - Hard Stop state                                   |
//|              - Daily Loss Limit state                            |
//+------------------------------------------------------------------+
#property copyright "Grid Survival Protocol"
#property link      ""
#property version   "1.00"

//+------------------------------------------------------------------+
//| Protection Level Status                                          |
//+------------------------------------------------------------------+
enum ENUM_PROTECTION_STATUS
{
   PROTECTION_INACTIVE = 0,    // Protection not active
   PROTECTION_WARNING,         // Approaching threshold
   PROTECTION_TRIGGERED,       // Threshold exceeded, action taken
   PROTECTION_COOLDOWN         // In cooldown period after trigger
};

//+------------------------------------------------------------------+
//| Protection Layer Type                                            |
//+------------------------------------------------------------------+
enum ENUM_PROTECTION_LAYER
{
   LAYER_NONE = 0,             // No protection layer
   LAYER_EMERGENCY_STOP,       // Level 1: Emergency Stop (-10%)
   LAYER_HARD_STOP,            // Level 2: Hard Stop (-20%)
   LAYER_DAILY_LIMIT           // Daily Loss Limit
};

//+------------------------------------------------------------------+
//| Individual Layer State                                           |
//+------------------------------------------------------------------+
struct SLayerState
{
   ENUM_PROTECTION_LAYER   layer;             // Which layer
   ENUM_PROTECTION_STATUS  status;            // Current status
   double                  threshold;         // Trigger threshold (%)
   double                  warningThreshold;  // Warning threshold (% before trigger)
   double                  currentValue;      // Current value being monitored
   datetime                triggerTime;       // Time when triggered
   datetime                cooldownEnd;       // Cooldown end time
   int                     triggerCount;      // Number of times triggered today
   string                  lastAction;        // Description of last action taken
   
   //--- Constructor
   void SLayerState()
   {
      Reset();
   }
   
   //--- Reset values
   void Reset()
   {
      layer            = LAYER_NONE;
      status           = PROTECTION_INACTIVE;
      threshold        = 0.0;
      warningThreshold = 0.0;
      currentValue     = 0.0;
      triggerTime      = 0;
      cooldownEnd      = 0;
      triggerCount     = 0;
      lastAction       = "";
   }
   
   //--- Initialize layer
   void Init(ENUM_PROTECTION_LAYER layerType, double triggerPct, double warningPct = 0.0)
   {
      layer            = layerType;
      status           = PROTECTION_INACTIVE;
      threshold        = triggerPct;
      warningThreshold = (warningPct > 0) ? warningPct : triggerPct * 0.8;
      currentValue     = 0.0;
      triggerTime      = 0;
      cooldownEnd      = 0;
      triggerCount     = 0;
      lastAction       = "";
   }
   
   //--- Check if in cooldown
   bool IsInCooldown() const
   {
      return (status == PROTECTION_COOLDOWN && TimeCurrent() < cooldownEnd);
   }
   
   //--- Check if triggered
   bool IsTriggered() const
   {
      return (status == PROTECTION_TRIGGERED);
   }
   
   //--- Check if warning
   bool IsWarning() const
   {
      return (status == PROTECTION_WARNING);
   }
   
   //--- Update status based on current value
   void UpdateStatus(double value)
   {
      currentValue = value;
      
      // Check if in cooldown
      if(IsInCooldown())
         return;
      
      // Check thresholds
      if(currentValue >= threshold)
      {
         if(status != PROTECTION_TRIGGERED)
         {
            status      = PROTECTION_TRIGGERED;
            triggerTime = TimeCurrent();
            triggerCount++;
         }
      }
      else if(currentValue >= warningThreshold)
      {
         if(status != PROTECTION_TRIGGERED)
            status = PROTECTION_WARNING;
      }
      else
      {
         status = PROTECTION_INACTIVE;
      }
   }
   
   //--- Enter cooldown
   void EnterCooldown(int cooldownSeconds)
   {
      status      = PROTECTION_COOLDOWN;
      cooldownEnd = TimeCurrent() + cooldownSeconds;
   }
   
   //--- Get status description
   string GetStatusDescription() const
   {
      switch(status)
      {
         case PROTECTION_INACTIVE:  return "Inactive";
         case PROTECTION_WARNING:   return "WARNING";
         case PROTECTION_TRIGGERED: return "TRIGGERED";
         case PROTECTION_COOLDOWN:  return "Cooldown";
         default:                   return "Unknown";
      }
   }
};

//+------------------------------------------------------------------+
//| Protection System State (All Layers)                             |
//+------------------------------------------------------------------+
struct SProtectionState
{
   SLayerState emergencyStop;    // Level 1: Emergency Stop
   SLayerState hardStop;         // Level 2: Hard Stop
   SLayerState dailyLimit;       // Daily Loss Limit
   
   datetime    dailyResetTime;   // Time for daily reset
   bool        isSystemLocked;   // True if system completely locked
   string      lockReason;       // Reason for system lock
   
   //--- Constructor
   void SProtectionState()
   {
      Reset();
   }
   
   //--- Reset all
   void Reset()
   {
      emergencyStop.Reset();
      hardStop.Reset();
      dailyLimit.Reset();
      dailyResetTime = 0;
      isSystemLocked = false;
      lockReason     = "";
   }
   
   //--- Initialize all layers
   void Init(double emergencyPct, double hardStopPct, double dailyLimitPct)
   {
      emergencyStop.Init(LAYER_EMERGENCY_STOP, emergencyPct, emergencyPct * 0.8);
      hardStop.Init(LAYER_HARD_STOP, hardStopPct, hardStopPct * 0.8);
      dailyLimit.Init(LAYER_DAILY_LIMIT, dailyLimitPct, dailyLimitPct * 0.8);
      
      // Set daily reset time (next day 00:00 server time)
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      dt.hour = 0;
      dt.min  = 0;
      dt.sec  = 0;
      dt.day  += 1;
      dailyResetTime = StructToTime(dt);
      
      isSystemLocked = false;
      lockReason     = "";
   }
   
   //--- Check if any layer triggered
   bool IsAnyLayerTriggered() const
   {
      return emergencyStop.IsTriggered() || 
             hardStop.IsTriggered() || 
             dailyLimit.IsTriggered();
   }
   
   //--- Get highest triggered layer
   ENUM_PROTECTION_LAYER GetHighestTriggeredLayer() const
   {
      if(hardStop.IsTriggered())
         return LAYER_HARD_STOP;
      if(dailyLimit.IsTriggered())
         return LAYER_DAILY_LIMIT;
      if(emergencyStop.IsTriggered())
         return LAYER_EMERGENCY_STOP;
      return LAYER_NONE;
   }
   
   //--- Lock system
   void LockSystem(string reason)
   {
      isSystemLocked = true;
      lockReason     = reason;
   }
   
   //--- Unlock system
   void UnlockSystem()
   {
      isSystemLocked = false;
      lockReason     = "";
   }
   
   //--- Check and reset daily counters
   void CheckDailyReset()
   {
      if(TimeCurrent() >= dailyResetTime)
      {
         // Reset daily limit counter
         dailyLimit.triggerCount = 0;
         dailyLimit.status = PROTECTION_INACTIVE;
         
         // Update reset time for next day
         dailyResetTime += 86400; // Add 24 hours
         
         // Unlock if locked by daily limit
         if(StringFind(lockReason, "Daily") >= 0)
            UnlockSystem();
      }
   }
   
   //--- Get overall status string
   string GetOverallStatus() const
   {
      if(isSystemLocked)
         return "LOCKED: " + lockReason;
      if(hardStop.IsTriggered())
         return "HARD STOP TRIGGERED";
      if(dailyLimit.IsTriggered())
         return "DAILY LIMIT REACHED";
      if(emergencyStop.IsTriggered())
         return "EMERGENCY MODE";
      if(emergencyStop.IsWarning() || hardStop.IsWarning() || dailyLimit.IsWarning())
         return "WARNING";
      return "NORMAL";
   }
};
//+------------------------------------------------------------------+
