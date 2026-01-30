//+------------------------------------------------------------------+
//|                                           PerformanceTracker.mqh |
//|                             Grid Survival Protocol EA - Metrics  |
//|                                                                  |
//| Description: Performance Tracking and Statistics                 |
//|              - Win rate, profit factor                           |
//|              - Max drawdown, recovery time                       |
//|              - Trade statistics                                  |
//+------------------------------------------------------------------+
#property copyright "Grid Survival Protocol"
#property link      ""
#property version   "1.00"

#include "../Utils/Common.mqh"
#include "../Utils/Logger.mqh"

//+------------------------------------------------------------------+
//| Performance Metrics Structure                                    |
//+------------------------------------------------------------------+
struct SPerformanceMetrics
{
   //--- Trade counts
   int      totalTrades;          // Total closed trades
   int      winTrades;            // Winning trades
   int      lossTrades;           // Losing trades
   
   //--- Profit/Loss
   double   grossProfit;          // Total profit
   double   grossLoss;            // Total loss (absolute value)
   double   netProfit;            // Net profit
   double   profitFactor;         // Gross profit / Gross loss
   
   //--- Win rate
   double   winRate;              // Win trades / Total trades (%)
   
   //--- Average trade
   double   avgWin;               // Average winning trade
   double   avgLoss;              // Average losing trade
   double   avgTrade;             // Average trade result
   double   expectancy;           // Expected value per trade
   
   //--- Drawdown
   double   maxDrawdown;          // Maximum drawdown (%)
   double   maxDrawdownMoney;     // Maximum drawdown ($)
   datetime maxDDTime;            // Time of max DD
   
   //--- Consecutive
   int      maxConsecutiveWins;   // Max consecutive wins
   int      maxConsecutiveLosses; // Max consecutive losses
   int      currentStreak;        // Current streak (+= win, -= loss)
   
   //--- Time
   datetime startTime;            // Tracking start time
   double   tradingDays;          // Number of trading days
   
   void Reset()
   {
      totalTrades = 0;
      winTrades   = 0;
      lossTrades  = 0;
      
      grossProfit   = 0;
      grossLoss     = 0;
      netProfit     = 0;
      profitFactor  = 0;
      
      winRate = 0;
      
      avgWin     = 0;
      avgLoss    = 0;
      avgTrade   = 0;
      expectancy = 0;
      
      maxDrawdown      = 0;
      maxDrawdownMoney = 0;
      maxDDTime        = 0;
      
      maxConsecutiveWins   = 0;
      maxConsecutiveLosses = 0;
      currentStreak        = 0;
      
      startTime   = 0;
      tradingDays = 0;
   }
};

//+------------------------------------------------------------------+
//| Performance Tracker Class                                        |
//+------------------------------------------------------------------+
class CPerformanceTracker
{
private:
   SPerformanceMetrics m_metrics;         // Current metrics
   int                 m_consecutiveCount;// Current consecutive counter
   bool                m_lastWasWin;      // Last trade was a win
   double              m_highWaterMark;   // Highest equity
   double              m_currentEquity;   // Current equity
   
   bool                m_isInitialized;
   
public:
   //--- Constructor
   CPerformanceTracker()
   {
      m_metrics.Reset();
      m_consecutiveCount = 0;
      m_lastWasWin       = false;
      m_highWaterMark    = 0;
      m_currentEquity    = 0;
      m_isInitialized    = false;
   }
   
   //--- Initialize
   bool Init()
   {
      m_metrics.Reset();
      m_metrics.startTime = TimeCurrent();
      m_highWaterMark     = GetEquity();
      m_currentEquity     = m_highWaterMark;
      m_consecutiveCount  = 0;
      
      m_isInitialized = true;
      Logger.Info("PerformanceTracker initialized");
      return true;
   }
   
   //--- Record a closed trade
   void RecordTrade(double profit)
   {
      m_metrics.totalTrades++;
      m_metrics.netProfit += profit;
      
      if(profit >= 0)
      {
         // Winning trade
         m_metrics.winTrades++;
         m_metrics.grossProfit += profit;
         
         // Update streak
         if(m_lastWasWin)
            m_consecutiveCount++;
         else
            m_consecutiveCount = 1;
         
         m_lastWasWin = true;
         
         if(m_consecutiveCount > m_metrics.maxConsecutiveWins)
            m_metrics.maxConsecutiveWins = m_consecutiveCount;
         
         m_metrics.currentStreak = m_consecutiveCount;
      }
      else
      {
         // Losing trade
         m_metrics.lossTrades++;
         m_metrics.grossLoss += MathAbs(profit);
         
         // Update streak
         if(!m_lastWasWin)
            m_consecutiveCount++;
         else
            m_consecutiveCount = 1;
         
         m_lastWasWin = false;
         
         if(m_consecutiveCount > m_metrics.maxConsecutiveLosses)
            m_metrics.maxConsecutiveLosses = m_consecutiveCount;
         
         m_metrics.currentStreak = -m_consecutiveCount;
      }
      
      // Calculate derived metrics
      CalculateMetrics();
      
      Logger.Debug(StringFormat("Trade recorded: %.2f | Total: %d | Win Rate: %.1f%%",
                                profit, m_metrics.totalTrades, m_metrics.winRate));
   }
   
   //--- Update equity tracking (call every tick or bar)
   void UpdateEquity(double equity)
   {
      m_currentEquity = equity;
      
      if(m_currentEquity > m_highWaterMark)
         m_highWaterMark = m_currentEquity;
      
      // Calculate drawdown
      double dd = 0;
      double ddMoney = 0;
      
      if(m_highWaterMark > 0)
      {
         ddMoney = m_highWaterMark - m_currentEquity;
         dd = (ddMoney / m_highWaterMark) * 100.0;
      }
      
      // Update max drawdown
      if(dd > m_metrics.maxDrawdown)
      {
         m_metrics.maxDrawdown = dd;
         m_metrics.maxDrawdownMoney = ddMoney;
         m_metrics.maxDDTime = TimeCurrent();
      }
   }
   
   //--- Get current metrics
   SPerformanceMetrics GetMetrics() const
   {
      return m_metrics;
   }
   
   //--- Get win rate
   double GetWinRate() const
   {
      return m_metrics.winRate;
   }
   
   //--- Get profit factor
   double GetProfitFactor() const
   {
      return m_metrics.profitFactor;
   }
   
   //--- Get net profit
   double GetNetProfit() const
   {
      return m_metrics.netProfit;
   }
   
   //--- Get max drawdown
   double GetMaxDrawdown() const
   {
      return m_metrics.maxDrawdown;
   }
   
   //--- Get expectancy
   double GetExpectancy() const
   {
      return m_metrics.expectancy;
   }
   
   //--- Get total trades
   int GetTotalTrades() const
   {
      return m_metrics.totalTrades;
   }
   
   //--- Get trading days
   double GetTradingDays()
   {
      if(m_metrics.startTime == 0)
         return 0;
      
      m_metrics.tradingDays = (double)(TimeCurrent() - m_metrics.startTime) / SECONDS_PER_DAY;
      return m_metrics.tradingDays;
   }
   
   //--- Get status summary
   string GetStatusSummary()
   {
      return StringFormat(
         "Performance: Trades=%d | WR=%.1f%% | PF=%.2f | Net=%.2f | MaxDD=%.2f%%",
         m_metrics.totalTrades, m_metrics.winRate, m_metrics.profitFactor,
         m_metrics.netProfit, m_metrics.maxDrawdown
      );
   }
   
   //--- Get detailed report
   string GetDetailedReport()
   {
      string report = StringFormat(
         "=== Performance Report ===\n"
         "Total Trades: %d (W:%d / L:%d)\n"
         "Win Rate: %.1f%%\n"
         "Profit Factor: %.2f\n"
         "Net Profit: %.2f\n"
         "Gross Profit: %.2f | Gross Loss: %.2f\n"
         "Avg Win: %.2f | Avg Loss: %.2f\n"
         "Expectancy: %.2f per trade\n"
         "Max Drawdown: %.2f%% (%.2f)\n"
         "Max Consecutive: Wins=%d, Losses=%d\n"
         "Trading Days: %.1f",
         m_metrics.totalTrades, m_metrics.winTrades, m_metrics.lossTrades,
         m_metrics.winRate,
         m_metrics.profitFactor,
         m_metrics.netProfit,
         m_metrics.grossProfit, m_metrics.grossLoss,
         m_metrics.avgWin, m_metrics.avgLoss,
         m_metrics.expectancy,
         m_metrics.maxDrawdown, m_metrics.maxDrawdownMoney,
         m_metrics.maxConsecutiveWins, m_metrics.maxConsecutiveLosses,
         GetTradingDays()
      );
      return report;
   }
   
   //--- Reset all metrics
   void Reset()
   {
      m_metrics.Reset();
      m_metrics.startTime = TimeCurrent();
      m_highWaterMark = GetEquity();
      m_consecutiveCount = 0;
   }
   
   //--- Check if initialized
   bool IsInitialized() const
   {
      return m_isInitialized;
   }
   
private:
   //--- Calculate derived metrics
   void CalculateMetrics()
   {
      // Win rate
      if(m_metrics.totalTrades > 0)
         m_metrics.winRate = ((double)m_metrics.winTrades / m_metrics.totalTrades) * 100.0;
      
      // Profit factor
      if(m_metrics.grossLoss > 0)
         m_metrics.profitFactor = m_metrics.grossProfit / m_metrics.grossLoss;
      else if(m_metrics.grossProfit > 0)
         m_metrics.profitFactor = 999.99;  // Infinite (no losses)
      
      // Average trades
      if(m_metrics.winTrades > 0)
         m_metrics.avgWin = m_metrics.grossProfit / m_metrics.winTrades;
      
      if(m_metrics.lossTrades > 0)
         m_metrics.avgLoss = m_metrics.grossLoss / m_metrics.lossTrades;
      
      if(m_metrics.totalTrades > 0)
         m_metrics.avgTrade = m_metrics.netProfit / m_metrics.totalTrades;
      
      // Expectancy
      double winProb = m_metrics.winRate / 100.0;
      m_metrics.expectancy = (winProb * m_metrics.avgWin) - 
                             ((1 - winProb) * m_metrics.avgLoss);
   }
};
//+------------------------------------------------------------------+
