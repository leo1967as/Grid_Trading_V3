//+------------------------------------------------------------------+
//|                                              AdaptiveSizing.mqh  |
//|                            Grid Survival Protocol EA - Recovery  |
//|                                                                  |
//| Description: Adaptive Position Sizing based on Equity Curve      |
//|              - Reduce size after losses                          |
//|              - Increase size during recovery                     |
//|              - Protect capital during drawdown                   |
//+------------------------------------------------------------------+
#property copyright "Grid Survival Protocol"
#property link      ""
#property version   "1.00"

#include "../Utils/Common.mqh"
#include "../Utils/Logger.mqh"

//+------------------------------------------------------------------+
//| Sizing Mode Enum                                                 |
//+------------------------------------------------------------------+
enum ENUM_SIZING_MODE
{
   SIZING_MODE_FIXED = 0,     // Fixed lot size
   SIZING_MODE_PERCENT,       // Percent of equity
   SIZING_MODE_ADAPTIVE       // Adaptive based on DD
};

//+------------------------------------------------------------------+
//| Adaptive Sizing Class                                            |
//+------------------------------------------------------------------+
class CAdaptiveSizing
{
private:
   ENUM_SIZING_MODE  m_mode;              // Sizing mode
   double            m_baseLotSize;       // Base lot size
   double            m_baseRiskPercent;   // Base risk percent
   
   double            m_currentMultiplier; // Current size multiplier (0.0 - 1.0)
   double            m_minMultiplier;     // Minimum multiplier (e.g., 0.25)
   double            m_maxMultiplier;     // Maximum multiplier (e.g., 1.5)
   
   double            m_ddReductionStart;  // DD% to start reducing (e.g., 5%)
   double            m_ddReductionFull;   // DD% for full reduction (e.g., 15%)
   
   double            m_recoveryBoost;     // Boost multiplier after recovery (e.g., 1.0)
   bool              m_inRecoveryMode;    // Currently in recovery
   
   bool              m_isInitialized;
   
public:
   //--- Constructor
   CAdaptiveSizing()
   {
      m_mode              = SIZING_MODE_ADAPTIVE;
      m_baseLotSize       = 0.01;
      m_baseRiskPercent   = 1.0;
      m_currentMultiplier = 1.0;
      m_minMultiplier     = 0.25;
      m_maxMultiplier     = 1.5;
      m_ddReductionStart  = 5.0;
      m_ddReductionFull   = 15.0;
      m_recoveryBoost     = 1.0;
      m_inRecoveryMode    = false;
      m_isInitialized     = false;
   }
   
   //--- Initialize
   bool Init(ENUM_SIZING_MODE mode = SIZING_MODE_ADAPTIVE,
             double baseLot = 0.01, double baseRisk = 1.0)
   {
      m_mode            = mode;
      m_baseLotSize     = baseLot;
      m_baseRiskPercent = baseRisk;
      m_currentMultiplier = 1.0;
      m_inRecoveryMode  = false;
      
      m_isInitialized = true;
      Logger.Info(StringFormat("AdaptiveSizing initialized: Mode=%s, BaseLot=%.2f, BaseRisk=%.1f%%",
                               EnumToString(m_mode), m_baseLotSize, m_baseRiskPercent));
      return true;
   }
   
   //--- Set reduction thresholds
   void SetReductionThresholds(double ddStart, double ddFull, double minMult = 0.25)
   {
      m_ddReductionStart = ddStart;
      m_ddReductionFull  = ddFull;
      m_minMultiplier    = minMult;
   }
   
   //--- Update multiplier based on current drawdown
   void UpdateMultiplier(double currentDrawdown)
   {
      if(m_mode != SIZING_MODE_ADAPTIVE)
      {
         m_currentMultiplier = 1.0;
         return;
      }
      
      // No drawdown - can use full or slightly boosted size
      if(currentDrawdown <= 0)
      {
         if(m_inRecoveryMode)
         {
            m_currentMultiplier = m_recoveryBoost;
         }
         else
         {
            m_currentMultiplier = 1.0;
         }
         return;
      }
      
      // Below start threshold - full size
      if(currentDrawdown < m_ddReductionStart)
      {
         m_currentMultiplier = 1.0;
         m_inRecoveryMode = false;
         return;
      }
      
      // In reduction zone - calculate linear reduction
      if(currentDrawdown < m_ddReductionFull)
      {
         double range = m_ddReductionFull - m_ddReductionStart;
         double progress = (currentDrawdown - m_ddReductionStart) / range;
         m_currentMultiplier = 1.0 - (progress * (1.0 - m_minMultiplier));
         m_inRecoveryMode = true;
         return;
      }
      
      // Above full reduction threshold - minimum size
      m_currentMultiplier = m_minMultiplier;
      m_inRecoveryMode = true;
   }
   
   //--- Get adjusted lot size
   double GetAdjustedLotSize(string symbol)
   {
      double lot = m_baseLotSize * m_currentMultiplier;
      return NormalizeLot(symbol, lot);
   }
   
   //--- Get adjusted lot size with risk calculation
   double GetRiskAdjustedLotSize(string symbol, double equity, double stopLossPoints)
   {
      if(m_mode == SIZING_MODE_FIXED)
         return GetAdjustedLotSize(symbol);
      
      if(stopLossPoints <= 0)
         return GetAdjustedLotSize(symbol);
      
      // Calculate lot based on risk percent
      double adjustedRisk = m_baseRiskPercent * m_currentMultiplier;
      double riskAmount   = equity * (adjustedRisk / 100.0);
      
      double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      double point     = SymbolInfoDouble(symbol, SYMBOL_POINT);
      
      if(tickSize == 0)
         return GetAdjustedLotSize(symbol);
      
      double pointValue = tickValue * (point / tickSize);
      
      double lot = 0;
      if(pointValue > 0 && stopLossPoints > 0)
         lot = riskAmount / (stopLossPoints * pointValue);
      
      return NormalizeLot(symbol, lot);
   }
   
   //--- Get current multiplier
   double GetMultiplier() const
   {
      return m_currentMultiplier;
   }
   
   //--- Get base lot size
   double GetBaseLotSize() const
   {
      return m_baseLotSize;
   }
   
   //--- Set base lot size
   void SetBaseLotSize(double lot)
   {
      m_baseLotSize = lot;
   }
   
   //--- Check if in recovery mode
   bool IsInRecoveryMode() const
   {
      return m_inRecoveryMode;
   }
   
   //--- Reset multiplier to 1.0
   void Reset()
   {
      m_currentMultiplier = 1.0;
      m_inRecoveryMode = false;
   }
   
   //--- Get reduction percentage
   double GetReductionPercent() const
   {
      return (1.0 - m_currentMultiplier) * 100.0;
   }
   
   //--- Get status summary
   string GetStatusSummary() const
   {
      return StringFormat("Sizing: Mode=%s | Mult=%.2f (%.0f%% of base) | Recovery=%s",
                          EnumToString(m_mode), m_currentMultiplier,
                          m_currentMultiplier * 100, m_inRecoveryMode ? "YES" : "NO");
   }
   
   //--- Check if initialized
   bool IsInitialized() const
   {
      return m_isInitialized;
   }
};
//+------------------------------------------------------------------+
