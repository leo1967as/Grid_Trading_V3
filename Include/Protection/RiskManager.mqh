//+------------------------------------------------------------------+
//|                                                 RiskManager.mqh  |
//|                           Grid Survival Protocol EA - Protection |
//|                                                                  |
//| Description: Risk Management and Position Sizing                 |
//|              - Calculate safe lot size                           |
//|              - Track max drawdown                                |
//|              - Enforce risk limits                               |
//+------------------------------------------------------------------+
#property copyright "Grid Survival Protocol"
#property link      ""
#property version   "1.00"

#include "../Utils/Common.mqh"
#include "../Utils/Logger.mqh"

//+------------------------------------------------------------------+
//| Risk Parameters Structure                                        |
//+------------------------------------------------------------------+
struct SRiskParams
{
   double   riskPerTrade;       // Risk per trade (%)
   double   maxTotalRisk;       // Max total grid risk (%)
   double   maxLotSize;         // Maximum lot size per order
   double   maxTotalLots;       // Maximum total lots exposure
   double   minEquity;          // Minimum equity to trade
   double   maxSpread;          // Maximum spread to trade (points)
   
   void SetDefaults()
   {
      riskPerTrade = 1.0;
      maxTotalRisk = 10.0;
      maxLotSize   = 1.0;
      maxTotalLots = 5.0;
      minEquity    = 100.0;
      maxSpread    = 30.0;
   }
};

//+------------------------------------------------------------------+
//| Risk Manager Class                                               |
//+------------------------------------------------------------------+
class CRiskManager
{
private:
   string         m_symbol;           // Trading symbol
   SRiskParams    m_params;           // Risk parameters
   
   double         m_startingEquity;   // Equity at start
   double         m_highWaterMark;    // Highest equity reached
   double         m_currentEquity;    // Current equity
   double         m_currentDrawdown;  // Current DD percent
   
   bool           m_isInitialized;
   
public:
   //--- Constructor
   CRiskManager()
   {
      m_symbol          = "";
      m_startingEquity  = 0;
      m_highWaterMark   = 0;
      m_currentEquity   = 0;
      m_currentDrawdown = 0;
      m_isInitialized   = false;
      m_params.SetDefaults();
   }
   
   //--- Initialize
   bool Init(string symbol, double riskPerTrade = 1.0, double maxTotalRisk = 10.0)
   {
      m_symbol              = symbol;
      m_params.riskPerTrade = riskPerTrade;
      m_params.maxTotalRisk = maxTotalRisk;
      
      m_startingEquity = GetEquity();
      m_highWaterMark  = m_startingEquity;
      m_currentEquity  = m_startingEquity;
      m_currentDrawdown = 0;
      
      m_isInitialized = true;
      Logger.Info(StringFormat("RiskManager initialized: Risk=%.1f%%, MaxRisk=%.1f%%, Equity=%.2f",
                               m_params.riskPerTrade, m_params.maxTotalRisk, m_startingEquity));
      return true;
   }
   
   //--- Set risk parameters
   void SetParams(SRiskParams &params)
   {
      m_params = params;
   }
   
   //--- Get risk parameters
   SRiskParams GetParams() const
   {
      return m_params;
   }
   
   //--- Update equity tracking (call on each tick)
   void UpdateEquity()
   {
      m_currentEquity = GetEquity();
      
      // Update high water mark
      if(m_currentEquity > m_highWaterMark)
         m_highWaterMark = m_currentEquity;
      
      // Calculate drawdown
      if(m_highWaterMark > 0)
         m_currentDrawdown = ((m_highWaterMark - m_currentEquity) / m_highWaterMark) * 100.0;
      else
         m_currentDrawdown = 0;
   }
   
   //--- Get current drawdown percent
   double GetCurrentDrawdown() const
   {
      return m_currentDrawdown;
   }
   
   //--- Get high water mark
   double GetHighWaterMark() const
   {
      return m_highWaterMark;
   }
   
   //--- Get starting equity
   double GetStartingEquity() const
   {
      return m_startingEquity;
   }
   
   //--- Calculate safe lot size based on risk
   double CalculateLotSize(double stopLossPoints)
   {
      if(stopLossPoints <= 0)
      {
         Logger.Warning("Invalid stop loss for lot calculation");
         return SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
      }
      
      double equity      = GetEquity();
      double riskAmount  = equity * (m_params.riskPerTrade / 100.0);
      double tickValue   = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize    = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
      double point       = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      
      // Calculate point value
      double pointValue = tickValue * (point / tickSize);
      
      // Calculate lot size
      double lots = 0;
      if(pointValue > 0 && stopLossPoints > 0)
         lots = riskAmount / (stopLossPoints * pointValue);
      
      // Normalize and clamp
      lots = NormalizeLot(m_symbol, lots);
      lots = MathMin(lots, m_params.maxLotSize);
      
      Logger.Debug(StringFormat("Calculated lot: %.2f (Risk: %.2f, SL: %.0f pts)",
                                lots, riskAmount, stopLossPoints));
      return lots;
   }
   
   //--- Calculate lot size for grid level
   double CalculateGridLotSize(int levelIndex, double baseLot, double multiplier = 1.0)
   {
      // Simple: same lot for all levels
      // Martingale: baseLot * multiplier^levelIndex
      double lots = baseLot * MathPow(multiplier, levelIndex);
      return NormalizeLot(m_symbol, MathMin(lots, m_params.maxLotSize));
   }
   
   //--- Check if additional lot is within risk limits
   bool CanAddLot(double currentTotalLots, double additionalLot)
   {
      double newTotal = currentTotalLots + additionalLot;
      return newTotal <= m_params.maxTotalLots;
   }
   
   //--- Check if current risk is acceptable
   bool IsRiskAcceptable(double currentTotalRiskPercent)
   {
      return currentTotalRiskPercent <= m_params.maxTotalRisk;
   }
   
   //--- Check if equity is sufficient
   bool HasSufficientEquity()
   {
      return GetEquity() >= m_params.minEquity;
   }
   
   //--- Set max spread
   void SetMaxSpread(double maxSpread)
   {
      m_params.maxSpread = maxSpread;
   }
   
   //--- Check if spread is acceptable
   bool IsSpreadAcceptable()
   {
      double spread = GetSpread(m_symbol);
      if(spread > m_params.maxSpread)
      {
         // Only log occasionally to avoid spam
         static datetime lastLog = 0;
         if(TimeCurrent() - lastLog > 60)
         {
            Logger.Debug(StringFormat("Spread too high: %.1f > %.1f (max)", spread, m_params.maxSpread));
            lastLog = TimeCurrent();
         }
         return false;
      }
      return true;
   }
   
   //--- Check all trading conditions
   bool CanTrade(double currentTotalLots, double additionalLot)
   {
      // Check equity
      if(!HasSufficientEquity())
      {
         Logger.Warning("Insufficient equity");
         return false;
      }
      
      // Check spread
      if(!IsSpreadAcceptable())
      {
         Logger.Warning(StringFormat("Spread too wide: %.0f > %.0f", 
                                     GetSpread(m_symbol), m_params.maxSpread));
         return false;
      }
      
      // Check lot limits
      if(!CanAddLot(currentTotalLots, additionalLot))
      {
         Logger.Warning(StringFormat("Would exceed max lots: %.2f + %.2f > %.2f",
                                     currentTotalLots, additionalLot, m_params.maxTotalLots));
         return false;
      }
      
      return true;
   }
   
   //--- Reset high water mark (after recovery)
   void ResetHighWaterMark()
   {
      m_highWaterMark = GetEquity();
      m_currentDrawdown = 0;
      Logger.Info(StringFormat("High water mark reset to: %.2f", m_highWaterMark));
   }
   
   //--- Get status summary
   string GetStatusSummary()
   {
      return StringFormat(
         "Risk: Equity=%.2f HWM=%.2f DD=%.2f%%",
         m_currentEquity, m_highWaterMark, m_currentDrawdown
      );
   }
   
   //--- Check if initialized
   bool IsInitialized() const
   {
      return m_isInitialized;
   }
};
//+------------------------------------------------------------------+
