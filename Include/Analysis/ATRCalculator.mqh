//+------------------------------------------------------------------+
//|                                               ATRCalculator.mqh  |
//|                            Grid Survival Protocol EA - Analysis  |
//|                                                                  |
//| Description: ATR-Based Grid Spacing Calculator                   |
//|              - Dynamic grid spacing based on volatility          |
//|              - Multi-timeframe support                           |
//+------------------------------------------------------------------+
#property copyright "Grid Survival Protocol"
#property link      ""
#property version   "1.00"

#include "../Utils/Common.mqh"
#include "../Utils/Logger.mqh"

//+------------------------------------------------------------------+
//| ATR Calculator Class                                             |
//+------------------------------------------------------------------+
class CATRCalculator
{
private:
   string            m_symbol;           // Trading symbol
   ENUM_TIMEFRAMES   m_timeframe;        // ATR timeframe
   int               m_period;           // ATR period
   double            m_multiplier;       // Grid spacing multiplier
   
   int               m_atrHandle;        // ATR indicator handle
   double            m_atrBuffer[];      // ATR values buffer
   
   double            m_currentATR;       // Current ATR value
   double            m_gridSpacing;      // Calculated grid spacing (in price)
   double            m_gridSpacingPoints;// Grid spacing in points
   
   bool              m_isInitialized;
   
public:
   //--- Constructor
   CATRCalculator()
   {
      m_symbol           = "";
      m_timeframe        = PERIOD_CURRENT;
      m_period           = 14;
      m_multiplier       = 1.5;
      m_atrHandle        = INVALID_HANDLE;
      m_currentATR       = 0;
      m_gridSpacing      = 0;
      m_gridSpacingPoints = 0;
      m_isInitialized    = false;
      
      ArraySetAsSeries(m_atrBuffer, true);
   }
   
   //--- Destructor
   ~CATRCalculator()
   {
      Deinit();
   }
   
   //--- Initialize
   bool Init(string symbol, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT,
             int period = 14, double multiplier = 1.5)
   {
      m_symbol     = symbol;
      m_timeframe  = timeframe;
      m_period     = period;
      m_multiplier = multiplier;
      
      // Create ATR indicator
      m_atrHandle = iATR(m_symbol, m_timeframe, m_period);
      if(m_atrHandle == INVALID_HANDLE)
      {
         Logger.Error("Failed to create ATR indicator for calculator");
         return false;
      }
      
      m_isInitialized = true;
      Logger.Info(StringFormat("ATRCalculator initialized: Symbol=%s, TF=%s, Period=%d, Mult=%.2f",
                               m_symbol, EnumToString(m_timeframe), m_period, m_multiplier));
      return true;
   }
   
   //--- Deinitialize
   void Deinit()
   {
      if(m_atrHandle != INVALID_HANDLE)
      {
         IndicatorRelease(m_atrHandle);
         m_atrHandle = INVALID_HANDLE;
      }
      m_isInitialized = false;
   }
   
   //--- Update ATR values (call on each bar or regularly)
   bool Update()
   {
      if(!m_isInitialized || m_atrHandle == INVALID_HANDLE)
         return false;
      
      if(CopyBuffer(m_atrHandle, 0, 0, 5, m_atrBuffer) <= 0)
      {
         Logger.Error("Failed to copy ATR buffer");
         return false;
      }
      
      m_currentATR = m_atrBuffer[0];
      
      // Calculate grid spacing
      m_gridSpacing = m_currentATR * m_multiplier;
      
      // Convert to points
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      if(point > 0)
         m_gridSpacingPoints = m_gridSpacing / point;
      
      return true;
   }
   
   //--- Get current ATR value
   double GetATR() const
   {
      return m_currentATR;
   }
   
   //--- Get grid spacing in price
   double GetGridSpacing() const
   {
      return m_gridSpacing;
   }
   
   //--- Get grid spacing in points
   double GetGridSpacingPoints() const
   {
      return m_gridSpacingPoints;
   }
   
   //--- Set multiplier
   void SetMultiplier(double multiplier)
   {
      m_multiplier = multiplier;
      Update();  // Recalculate
   }
   
   //--- Get multiplier
   double GetMultiplier() const
   {
      return m_multiplier;
   }
   
   //--- Calculate grid levels based on base price
   bool CalculateLevels(double basePrice, int numLevels, 
                        double &buyLevels[], double &sellLevels[])
   {
      if(!m_isInitialized || m_gridSpacing == 0)
         return false;
      
      ArrayResize(buyLevels, numLevels);
      ArrayResize(sellLevels, numLevels);
      
      for(int i = 0; i < numLevels; i++)
      {
         buyLevels[i]  = NormalizePrice(m_symbol, basePrice - (m_gridSpacing * (i + 1)));
         sellLevels[i] = NormalizePrice(m_symbol, basePrice + (m_gridSpacing * (i + 1)));
      }
      
      return true;
   }
   
   //--- Get average ATR over N periods
   double GetAverageATR(int periods = 5)
   {
      if(!m_isInitialized || m_atrHandle == INVALID_HANDLE)
         return 0;
      
      double buffer[];
      ArraySetAsSeries(buffer, true);
      
      if(CopyBuffer(m_atrHandle, 0, 0, periods, buffer) <= 0)
         return m_currentATR;
      
      double sum = 0;
      for(int i = 0; i < periods; i++)
         sum += buffer[i];
      
      return sum / periods;
   }
   
   //--- Check if volatility is high (ATR > average)
   bool IsHighVolatility()
   {
      double avgATR = GetAverageATR(20);
      return m_currentATR > avgATR * 1.2;  // 20% above average
   }
   
   //--- Check if volatility is low
   bool IsLowVolatility()
   {
      double avgATR = GetAverageATR(20);
      return m_currentATR < avgATR * 0.8;  // 20% below average
   }
   
   //--- Get status summary
   string GetStatusSummary() const
   {
      return StringFormat("ATR: %.5f | Spacing: %.5f (%.0f pts) | Mult: %.2f",
                          m_currentATR, m_gridSpacing, m_gridSpacingPoints, m_multiplier);
   }
   
   //--- Check if initialized
   bool IsInitialized() const
   {
      return m_isInitialized;
   }
};
//+------------------------------------------------------------------+
