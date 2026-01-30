//+------------------------------------------------------------------+
//|                                                  NewsFilter.mqh  |
//|                            Grid Survival Protocol EA - Analysis  |
//|                                                                  |
//| Description: High Impact News Filter                             |
//|              - Pause trading before/after news events            |
//|              - Configurable buffer times                         |
//|              - Manual news time entry                            |
//+------------------------------------------------------------------+
#property copyright "Grid Survival Protocol"
#property link      ""
#property version   "1.00"

#include "../Utils/Common.mqh"
#include "../Utils/Logger.mqh"

//+------------------------------------------------------------------+
//| News Event Structure                                             |
//+------------------------------------------------------------------+
struct SNewsEvent
{
   datetime    time;           // Event time
   string      currency;       // Affected currency (e.g., "USD")
   string      title;          // Event title
   int         impact;         // Impact level (1=low, 2=medium, 3=high)
   bool        isActive;       // Event is still relevant
   
   void Reset()
   {
      time     = 0;
      currency = "";
      title    = "";
      impact   = 0;
      isActive = false;
   }
};

//+------------------------------------------------------------------+
//| News Filter Class                                                |
//+------------------------------------------------------------------+
class CNewsFilter
{
private:
   bool              m_enabled;              // Filter enabled
   string            m_symbol;               // Trading symbol
   string            m_baseCurrency;         // Base currency of symbol
   string            m_quoteCurrency;        // Quote currency of symbol
   
   int               m_stopMinutesBefore;    // Stop X minutes before news
   int               m_resumeMinutesAfter;   // Resume X minutes after news
   
   SNewsEvent        m_events[];             // Upcoming news events
   int               m_maxEvents;            // Max events to track
   
   bool              m_isNewsTime;           // Currently in news pause
   datetime          m_nextNewsTime;         // Next news event time
   datetime          m_resumeTime;           // Time to resume trading
   
   bool              m_isInitialized;
   
public:
   //--- Constructor
   CNewsFilter()
   {
      m_enabled            = true;
      m_symbol             = "";
      m_baseCurrency       = "";
      m_quoteCurrency      = "";
      m_stopMinutesBefore  = 30;
      m_resumeMinutesAfter = 15;
      m_maxEvents          = 20;
      m_isNewsTime         = false;
      m_nextNewsTime       = 0;
      m_resumeTime         = 0;
      m_isInitialized      = false;
   }
   
   //--- Initialize
   bool Init(string symbol, int stopMinsBefore = 30, int resumeMinsAfter = 15, bool enabled = true)
   {
      m_enabled            = enabled;
      m_symbol             = symbol;
      m_stopMinutesBefore  = stopMinsBefore;
      m_resumeMinutesAfter = resumeMinsAfter;
      
      // Extract currencies from symbol (e.g., EURUSD -> EUR, USD)
      m_baseCurrency  = StringSubstr(m_symbol, 0, 3);
      m_quoteCurrency = StringSubstr(m_symbol, 3, 3);
      
      ArrayResize(m_events, 0);
      
      m_isInitialized = true;
      
      if(m_enabled)
      {
         Logger.Info(StringFormat("NewsFilter initialized: Symbol=%s, StopBefore=%dmin, ResumeAfter=%dmin",
                                  m_symbol, m_stopMinutesBefore, m_resumeMinutesAfter));
      }
      else
      {
         Logger.Info("NewsFilter disabled");
      }
      
      return true;
   }
   
   //--- Add manual news event
   void AddNewsEvent(datetime eventTime, string currency, string title, int impact = 3)
   {
      int size = ArraySize(m_events);
      
      // Check if already exists
      for(int i = 0; i < size; i++)
      {
         if(m_events[i].time == eventTime && m_events[i].currency == currency)
            return;  // Already added
      }
      
      // Add new event
      ArrayResize(m_events, size + 1);
      m_events[size].time     = eventTime;
      m_events[size].currency = currency;
      m_events[size].title    = title;
      m_events[size].impact   = impact;
      m_events[size].isActive = true;
      
      Logger.Info(StringFormat("News event added: %s %s - %s (Impact: %d)",
                               TimeToString(eventTime), currency, title, impact));
      
      // Update next news time
      UpdateNextNewsTime();
   }
   
   //--- Add today's news events (batch)
   void AddTodayEvents(datetime &times[], string &currencies[], string &titles[], int &impacts[])
   {
      int count = ArraySize(times);
      for(int i = 0; i < count; i++)
      {
         AddNewsEvent(times[i], currencies[i], titles[i], impacts[i]);
      }
   }
   
   //--- Clear all events
   void ClearAllEvents()
   {
      ArrayResize(m_events, 0);
      m_nextNewsTime = 0;
   }
   
   //--- Clean up expired events
   void CleanupExpiredEvents()
   {
      datetime now = TimeCurrent();
      
      for(int i = ArraySize(m_events) - 1; i >= 0; i--)
      {
         // Event has passed + resume time
         if(now > m_events[i].time + m_resumeMinutesAfter * 60)
         {
            m_events[i].isActive = false;
         }
      }
      
      UpdateNextNewsTime();
   }
   
   //--- Check if trading is allowed (call every tick)
   bool IsTradingAllowed()
   {
      if(!m_enabled || !m_isInitialized)
         return true;
      
      datetime now = TimeCurrent();
      
      // Clean up old events periodically
      CleanupExpiredEvents();
      
      // Check if we're in the news pause window
      for(int i = 0; i < ArraySize(m_events); i++)
      {
         if(!m_events[i].isActive)
            continue;
         
         // Check if this event affects our currencies
         if(!IsRelevantCurrency(m_events[i].currency))
            continue;
         
         // Only check high impact events
         if(m_events[i].impact < 3)
            continue;
         
         // Check time window
         datetime stopTime   = m_events[i].time - m_stopMinutesBefore * 60;
         datetime resumeTime = m_events[i].time + m_resumeMinutesAfter * 60;
         
         if(now >= stopTime && now <= resumeTime)
         {
            m_isNewsTime   = true;
            m_nextNewsTime = m_events[i].time;
            m_resumeTime   = resumeTime;
            return false;  // Don't trade
         }
      }
      
      m_isNewsTime = false;
      return true;  // Safe to trade
   }
   
   //--- Check if currently in news pause
   bool IsNewsTime() const
   {
      return m_isNewsTime;
   }
   
   //--- Get next news time
   datetime GetNextNewsTime() const
   {
      return m_nextNewsTime;
   }
   
   //--- Get resume time
   datetime GetResumeTime() const
   {
      return m_resumeTime;
   }
   
   //--- Get seconds until next news
   int GetSecondsUntilNews()
   {
      if(m_nextNewsTime == 0)
         return -1;
      return (int)(m_nextNewsTime - TimeCurrent());
   }
   
   //--- Get seconds until resume
   int GetSecondsUntilResume()
   {
      if(m_resumeTime == 0 || !m_isNewsTime)
         return 0;
      return (int)(m_resumeTime - TimeCurrent());
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
   
   //--- Get upcoming events count
   int GetUpcomingEventsCount()
   {
      int count = 0;
      datetime now = TimeCurrent();
      
      for(int i = 0; i < ArraySize(m_events); i++)
      {
         if(m_events[i].isActive && m_events[i].time > now)
            count++;
      }
      return count;
   }
   
   //--- Get status summary
   string GetStatusSummary()
   {
      if(!m_enabled)
         return "News: Filter Disabled";
      
      if(m_isNewsTime)
      {
         int minsRemaining = GetSecondsUntilResume() / 60;
         return StringFormat("News: PAUSED - Resume in %d min", minsRemaining);
      }
      
      int minsToNews = GetSecondsUntilNews() / 60;
      if(minsToNews > 0 && minsToNews <= 60)
         return StringFormat("News: WARNING - Event in %d min", minsToNews);
      
      return StringFormat("News: OK (%d events upcoming)", GetUpcomingEventsCount());
   }
   
   //--- Check if initialized
   bool IsInitialized() const
   {
      return m_isInitialized;
   }
   
private:
   //--- Check if currency is relevant to our symbol
   bool IsRelevantCurrency(string currency)
   {
      return currency == m_baseCurrency ||
             currency == m_quoteCurrency ||
             currency == "USD";  // USD affects most pairs
   }
   
   //--- Update next news time
   void UpdateNextNewsTime()
   {
      m_nextNewsTime = 0;
      datetime now = TimeCurrent();
      
      for(int i = 0; i < ArraySize(m_events); i++)
      {
         if(!m_events[i].isActive)
            continue;
         
         if(!IsRelevantCurrency(m_events[i].currency))
            continue;
         
         if(m_events[i].time > now)
         {
            if(m_nextNewsTime == 0 || m_events[i].time < m_nextNewsTime)
               m_nextNewsTime = m_events[i].time;
         }
      }
   }
};
//+------------------------------------------------------------------+
