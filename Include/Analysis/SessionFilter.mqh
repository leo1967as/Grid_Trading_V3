//+------------------------------------------------------------------+
//|                                               SessionFilter.mqh  |
//|                            Grid Survival Protocol EA - Analysis  |
//|                                                                  |
//| Description: Trading Session Time Filter                         |
//|              - Filter by trading hours                           |
//|              - Avoid specific sessions (rollover, etc.)          |
//+------------------------------------------------------------------+
#property copyright "Grid Survival Protocol"
#property link      ""
#property version   "1.00"

#include "../Utils/Common.mqh"
#include "../Utils/Logger.mqh"
#include "../Models/TradeState.mqh"

//+------------------------------------------------------------------+
//| Session Type Enum                                                |
//+------------------------------------------------------------------+
enum ENUM_SESSION_TYPE
{
   SESSION_SYDNEY = 0,    // Sydney session
   SESSION_TOKYO,         // Tokyo session
   SESSION_LONDON,        // London session
   SESSION_NEWYORK,       // New York session
   SESSION_CUSTOM         // Custom hours
};

//+------------------------------------------------------------------+
//| Session Filter Class                                             |
//+------------------------------------------------------------------+
class CSessionFilter
{
private:
   bool              m_enabled;          // Filter enabled
   
   int               m_startHour;        // Trading start hour (server time)
   int               m_endHour;          // Trading end hour (server time)
   
   int               m_rolloverStartHour;// Rollover start hour
   int               m_rolloverEndHour;  // Rollover end hour
   
   bool              m_avoidFriday;      // Avoid Friday evening
   int               m_fridayCutoffHour; // Friday cutoff hour
   
   bool              m_avoidMonday;      // Avoid Monday morning
   int               m_mondayStartHour;  // Monday start hour
   
   ENUM_SESSION_STATE m_currentState;    // Current session state
   bool              m_isInitialized;
   
public:
   //--- Constructor
   CSessionFilter()
   {
      m_enabled           = true;
      m_startHour         = 2;    // 02:00 server time
      m_endHour           = 22;   // 22:00 server time
      m_rolloverStartHour = 23;
      m_rolloverEndHour   = 1;
      m_avoidFriday       = true;
      m_fridayCutoffHour  = 20;   // Stop at 20:00 Friday
      m_avoidMonday       = true;
      m_mondayStartHour   = 2;    // Start at 02:00 Monday
      m_currentState      = SESSION_STATE_CLOSED;
      m_isInitialized     = false;
   }
   
   //--- Initialize
   bool Init(int startHour = 2, int endHour = 22, bool enabled = true)
   {
      m_enabled   = enabled;
      m_startHour = startHour;
      m_endHour   = endHour;
      
      m_isInitialized = true;
      
      if(m_enabled)
      {
         Logger.Info(StringFormat("SessionFilter initialized: %02d:00 - %02d:00 (Server Time)",
                                  m_startHour, m_endHour));
      }
      else
      {
         Logger.Info("SessionFilter disabled - trading 24/7");
      }
      
      return true;
   }
   
   //--- Set rollover hours
   void SetRolloverHours(int startHour, int endHour)
   {
      m_rolloverStartHour = startHour;
      m_rolloverEndHour   = endHour;
   }
   
   //--- Set Friday settings
   void SetFridaySettings(bool avoid, int cutoffHour)
   {
      m_avoidFriday      = avoid;
      m_fridayCutoffHour = cutoffHour;
   }
   
   //--- Set Monday settings
   void SetMondaySettings(bool avoid, int startHour)
   {
      m_avoidMonday     = avoid;
      m_mondayStartHour = startHour;
   }
   
   //--- Check if trading is allowed now (call every tick)
   bool IsTradingAllowed()
   {
      if(!m_enabled)
      {
         m_currentState = SESSION_STATE_OPEN;
         return true;
      }
      
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      
      int hour      = dt.hour;
      int dayOfWeek = dt.day_of_week;  // 0=Sunday, 1=Monday, ..., 6=Saturday
      
      // Weekend check
      if(dayOfWeek == 0 || dayOfWeek == 6)
      {
         m_currentState = SESSION_STATE_CLOSED;
         return false;
      }
      
      // Monday morning check
      if(m_avoidMonday && dayOfWeek == 1 && hour < m_mondayStartHour)
      {
         m_currentState = SESSION_STATE_CLOSED;
         return false;
      }
      
      // Friday evening check
      if(m_avoidFriday && dayOfWeek == 5 && hour >= m_fridayCutoffHour)
      {
         m_currentState = SESSION_STATE_CLOSED;
         return false;
      }
      
      // Rollover check
      if(IsRolloverTime(hour))
      {
         m_currentState = SESSION_STATE_ROLLOVER;
         return false;
      }
      
      // Normal session check
      if(m_startHour < m_endHour)
      {
         // Same day range (e.g., 02:00 - 22:00)
         if(hour >= m_startHour && hour < m_endHour)
         {
            m_currentState = SESSION_STATE_OPEN;
            return true;
         }
      }
      else
      {
         // Overnight range (e.g., 22:00 - 02:00)
         if(hour >= m_startHour || hour < m_endHour)
         {
            m_currentState = SESSION_STATE_OPEN;
            return true;
         }
      }
      
      m_currentState = SESSION_STATE_CLOSED;
      return false;
   }
   
   //--- Get current session state
   ENUM_SESSION_STATE GetState() const
   {
      return m_currentState;
   }
   
   //--- Get state string
   string GetStateString() const
   {
      switch(m_currentState)
      {
         case SESSION_STATE_OPEN:     return "OPEN";
         case SESSION_STATE_CLOSED:   return "CLOSED";
         case SESSION_STATE_NEWS_PAUSE: return "NEWS_PAUSE";
         case SESSION_STATE_ROLLOVER: return "ROLLOVER";
         default:                     return "UNKNOWN";
      }
   }
   
   //--- Get time until next session open
   int GetSecondsUntilOpen()
   {
      if(IsTradingAllowed())
         return 0;
      
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      
      // Calculate next opening time
      // This is a simplified calculation
      int currentMinutes = dt.hour * 60 + dt.min;
      int openMinutes    = m_startHour * 60;
      
      if(currentMinutes < openMinutes)
         return (openMinutes - currentMinutes) * 60;
      else
         return (24 * 60 - currentMinutes + openMinutes) * 60;  // Next day
   }
   
   //--- Get time until session close
   int GetSecondsUntilClose()
   {
      if(!IsTradingAllowed())
         return 0;
      
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      
      int currentMinutes = dt.hour * 60 + dt.min;
      int closeMinutes   = m_endHour * 60;
      
      if(currentMinutes < closeMinutes)
         return (closeMinutes - currentMinutes) * 60;
      else
         return 0;
   }
   
   //--- Enable/disable filter
   void SetEnabled(bool enabled)
   {
      m_enabled = enabled;
   }
   
   //--- Check if enabled
   bool IsEnabled() const
   {
      return m_enabled;
   }
   
   //--- Get status summary
   string GetStatusSummary() const
   {
      if(!m_enabled)
         return "Session: 24/7 Trading";
      
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      
      return StringFormat("Session: %s | Hours: %02d:00-%02d:00 | Current: %02d:%02d | Day: %d",
                          GetStateString(), m_startHour, m_endHour, 
                          dt.hour, dt.min, dt.day_of_week);
   }
   
   //--- Check if initialized
   bool IsInitialized() const
   {
      return m_isInitialized;
   }
   
private:
   //--- Check if in rollover period
   bool IsRolloverTime(int hour)
   {
      if(m_rolloverStartHour < m_rolloverEndHour)
         return hour >= m_rolloverStartHour && hour < m_rolloverEndHour;
      else
         return hour >= m_rolloverStartHour || hour < m_rolloverEndHour;
   }
};
//+------------------------------------------------------------------+
