//+------------------------------------------------------------------+
//|                                                 EquityCurve.mqh  |
//|                             Grid Survival Protocol EA - Metrics  |
//|                                                                  |
//| Description: Equity Curve Tracking                               |
//|              - Record equity snapshots                           |
//|              - Calculate curve statistics                        |
//+------------------------------------------------------------------+
#property copyright "Grid Survival Protocol"
#property link      ""
#property version   "1.00"

#include "../Utils/Common.mqh"
#include "../Utils/Logger.mqh"

//+------------------------------------------------------------------+
//| Equity Point Structure                                           |
//+------------------------------------------------------------------+
struct SEquityPoint
{
   datetime    time;        // Snapshot time
   double      equity;      // Equity value
   double      balance;     // Balance value
   double      profit;      // Open profit at time
};

//+------------------------------------------------------------------+
//| Equity Curve Class                                               |
//+------------------------------------------------------------------+
class CEquityCurve
{
private:
   SEquityPoint      m_points[];       // Equity history
   int               m_maxPoints;      // Maximum points to store
   datetime          m_lastRecordTime; // Last recording time
   int               m_recordInterval; // Recording interval (seconds)
   
   double            m_startEquity;    // Starting equity
   double            m_highWaterMark;  // Highest equity
   double            m_lowWaterMark;   // Lowest equity since HWM
   
   bool              m_isInitialized;
   
public:
   //--- Constructor
   CEquityCurve()
   {
      m_maxPoints      = 1440;  // Store 24 hours at 1-minute intervals
      m_lastRecordTime = 0;
      m_recordInterval = 60;    // 1 minute default
      m_startEquity    = 0;
      m_highWaterMark  = 0;
      m_lowWaterMark   = 0;
      m_isInitialized  = false;
      
      ArrayResize(m_points, 0);
   }
   
   //--- Initialize
   bool Init(int maxPoints = 1440, int recordIntervalSecs = 60)
   {
      m_maxPoints      = maxPoints;
      m_recordInterval = recordIntervalSecs;
      m_startEquity    = GetEquity();
      m_highWaterMark  = m_startEquity;
      m_lowWaterMark   = m_startEquity;
      m_lastRecordTime = 0;
      
      ArrayResize(m_points, 0);
      RecordPoint();  // Record initial point
      
      m_isInitialized = true;
      Logger.Info(StringFormat("EquityCurve initialized: MaxPoints=%d, Interval=%ds",
                               m_maxPoints, m_recordInterval));
      return true;
   }
   
   //--- Update (call on each tick, will auto-throttle)
   void Update()
   {
      if(!m_isInitialized)
         return;
      
      datetime now = TimeCurrent();
      
      // Check if enough time has passed
      if(now - m_lastRecordTime >= m_recordInterval)
      {
         RecordPoint();
         m_lastRecordTime = now;
      }
      
      // Always update HWM/LWM
      double equity = GetEquity();
      if(equity > m_highWaterMark)
      {
         m_highWaterMark = equity;
         m_lowWaterMark  = equity;  // Reset LWM at new HWM
      }
      else if(equity < m_lowWaterMark)
      {
         m_lowWaterMark = equity;
      }
   }
   
   //--- Force record a point
   void RecordPoint()
   {
      SEquityPoint point;
      point.time    = TimeCurrent();
      point.equity  = GetEquity();
      point.balance = GetBalance();
      point.profit  = GetCurrentPL();
      
      // Add to array
      int size = ArraySize(m_points);
      
      // If at capacity, remove oldest
      if(size >= m_maxPoints)
      {
         for(int i = 0; i < size - 1; i++)
            m_points[i] = m_points[i + 1];
         m_points[size - 1] = point;
      }
      else
      {
         ArrayResize(m_points, size + 1);
         m_points[size] = point;
      }
   }
   
   //--- Get current point count
   int GetPointCount() const
   {
      return ArraySize(m_points);
   }
   
   //--- Get point at index
   bool GetPoint(int index, SEquityPoint &point) const
   {
      if(index < 0 || index >= ArraySize(m_points))
         return false;
      
      point = m_points[index];
      return true;
   }
   
   //--- Get last N points
   int GetLastPoints(int count, SEquityPoint &points[])
   {
      int total = ArraySize(m_points);
      int start = MathMax(0, total - count);
      int actual = total - start;
      
      ArrayResize(points, actual);
      for(int i = 0; i < actual; i++)
         points[i] = m_points[start + i];
      
      return actual;
   }
   
   //--- Get starting equity
   double GetStartEquity() const
   {
      return m_startEquity;
   }
   
   //--- Get high water mark
   double GetHighWaterMark() const
   {
      return m_highWaterMark;
   }
   
   //--- Get current drawdown from HWM
   double GetCurrentDrawdown() const
   {
      double equity = GetEquity();
      if(m_highWaterMark > 0)
         return ((m_highWaterMark - equity) / m_highWaterMark) * 100.0;
      return 0;
   }
   
   //--- Get max drawdown from HWM
   double GetMaxDrawdownFromHWM() const
   {
      if(m_highWaterMark > 0)
         return ((m_highWaterMark - m_lowWaterMark) / m_highWaterMark) * 100.0;
      return 0;
   }
   
   //--- Get total return percentage
   double GetTotalReturn() const
   {
      double current = GetEquity();
      if(m_startEquity > 0)
         return ((current - m_startEquity) / m_startEquity) * 100.0;
      return 0;
   }
   
   //--- Calculate slope of equity curve (trend)
   double CalculateSlope(int periods = 20)
   {
      int total = ArraySize(m_points);
      if(total < periods)
         periods = total;
      
      if(periods < 2)
         return 0;
      
      int start = total - periods;
      
      // Simple linear regression slope
      double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
      
      for(int i = 0; i < periods; i++)
      {
         double x = (double)i;
         double y = m_points[start + i].equity;
         
         sumX  += x;
         sumY  += y;
         sumXY += x * y;
         sumX2 += x * x;
      }
      
      double n = (double)periods;
      double denominator = (n * sumX2) - (sumX * sumX);
      
      if(MathAbs(denominator) < 0.0001)
         return 0;
      
      return ((n * sumXY) - (sumX * sumY)) / denominator;
   }
   
   //--- Check if curve is trending up
   bool IsTrendingUp(int periods = 20)
   {
      return CalculateSlope(periods) > 0;
   }
   
   //--- Get status summary
   string GetStatusSummary()
   {
      return StringFormat(
         "Equity: Start=%.2f | HWM=%.2f | Current=%.2f | Return=%.2f%% | DD=%.2f%%",
         m_startEquity, m_highWaterMark, GetEquity(), 
         GetTotalReturn(), GetCurrentDrawdown()
      );
   }
   
   //--- Clear all points
   void Clear()
   {
      ArrayResize(m_points, 0);
      m_lastRecordTime = 0;
   }
   
   //--- Reset with new start
   void Reset()
   {
      Clear();
      m_startEquity   = GetEquity();
      m_highWaterMark = m_startEquity;
      m_lowWaterMark  = m_startEquity;
      RecordPoint();
   }
   
   //--- Check if initialized
   bool IsInitialized() const
   {
      return m_isInitialized;
   }
};
//+------------------------------------------------------------------+
