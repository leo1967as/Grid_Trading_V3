//+------------------------------------------------------------------+
//|                                                  GridEngine.mqh  |
//|                                Grid Survival Protocol EA - Core  |
//|                                                                  |
//| Description: Grid Management Engine                              |
//|              - Calculate grid levels based on ATR                |
//|              - Manage pending orders                             |
//|              - Track grid state                                  |
//+------------------------------------------------------------------+
#property copyright "Grid Survival Protocol"
#property link      ""
#property version   "1.00"

#include "../Utils/Common.mqh"
#include "../Utils/Logger.mqh"
#include "../Models/GridLevel.mqh"

//+------------------------------------------------------------------+
//| Grid Engine Class                                                |
//+------------------------------------------------------------------+
class CGridEngine
{
private:
   string            m_symbol;           // Trading symbol
   int               m_maxLevels;        // Maximum grid levels
   double            m_gridSpacing;      // Grid spacing in points
   double            m_manualSpacing;    // Manual grid spacing (if > 0, override ATR)
   double            m_atrMultiplier;    // ATR multiplier for spacing
   int               m_atrPeriod;        // ATR period
   ENUM_TIMEFRAMES   m_atrTimeframe;     // ATR timeframe
   int               m_atrHandle;        // ATR indicator handle
   double            m_atrBuffer[];      // ATR values buffer
   
   SGridArray        m_buyGrid;          // Buy grid levels
   SGridArray        m_sellGrid;         // Sell grid levels
   
   double            m_basePrice;        // Starting price for grid
   double            m_currentPrice;     // Current market price
   bool              m_isInitialized;    // Initialization flag
   
public:
   //--- Constructor
   CGridEngine()
   {
      m_symbol        = "";
      m_maxLevels     = 10;
      m_gridSpacing   = 0;
      m_manualSpacing = 0;
      m_atrMultiplier = 1.5;
      m_atrPeriod     = 14;
      m_atrTimeframe  = PERIOD_H1;
      m_atrHandle     = INVALID_HANDLE;
      m_basePrice     = 0;
      m_currentPrice  = 0;
      m_isInitialized = false;
      
      ArraySetAsSeries(m_atrBuffer, true);
   }
   
   //--- Destructor
   ~CGridEngine()
   {
      Deinit();
   }
   
   //--- Initialize engine
   bool Init(string symbol, ENUM_TIMEFRAMES timeframe, int atrPeriod, double atrMultiplier, int maxLevels, int manualSpacing = 0)
   {
      m_symbol        = symbol;
      m_atrTimeframe  = timeframe;
      m_atrPeriod     = atrPeriod;
      m_atrMultiplier = atrMultiplier;
      m_maxLevels     = maxLevels;
      m_manualSpacing = manualSpacing;
      
      // Initialize grids
      if(!m_buyGrid.Init(maxLevels) || !m_sellGrid.Init(maxLevels))
      {
         Logger.Error("Failed to initialize grid arrays");
         return false;
      }
      
      // Create ATR indicator
      m_atrHandle = iATR(m_symbol, m_atrTimeframe, m_atrPeriod);
      if(m_atrHandle == INVALID_HANDLE)
      {
         Logger.Error("Failed to create ATR indicator");
         return false;
      }
      
      m_isInitialized = true;
      Logger.Info(StringFormat("GridEngine initialized: Symbol=%s, MaxLevels=%d, ATR=%d", 
                               m_symbol, m_maxLevels, m_atrPeriod));
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
   
   //--- Update with current price
   void Update(double currentPrice)
   {
      m_currentPrice = currentPrice;
      UpdateGridSpacing();
   }
   
   //--- Update grid spacing based on current ATR or manual value
   bool UpdateGridSpacing()
   {
      // If manual spacing is set, use it directly
      if(m_manualSpacing > 0)
      {
         m_gridSpacing = m_manualSpacing;
         return true;
      }
      
      // Otherwise, calculate from ATR
      if(m_atrHandle == INVALID_HANDLE)
         return false;
      
      if(CopyBuffer(m_atrHandle, 0, 0, 1, m_atrBuffer) <= 0)
      {
         Logger.Error("Failed to copy ATR buffer");
         return false;
      }
      
      double atrValue = m_atrBuffer[0];
      double point    = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      
      // Calculate grid spacing in points
      m_gridSpacing = (atrValue / point) * m_atrMultiplier;
      
      return true;
   }
   
   //--- Get current grid spacing in points
   double GetGridSpacing() const
   {
      return m_gridSpacing;
   }
   
   //--- Get current grid spacing in price
   double GetGridSpacingInPrice() const
   {
      return m_gridSpacing * SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   }
   
   //--- Set base price for grid calculation
   void SetBasePrice(double price)
   {
      m_basePrice = NormalizePrice(m_symbol, price);
      Logger.Info(StringFormat("Base price set: %.5f", m_basePrice));
   }
   
   //--- Calculate price for a grid level
   double CalculateLevelPrice(int levelIndex, ENUM_GRID_DIRECTION direction)
   {
      if(m_basePrice == 0 || m_gridSpacing == 0)
         return 0;
      
      double point       = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double priceOffset = m_gridSpacing * point * levelIndex;
      double price;
      
      if(direction == GRID_DIRECTION_BUY)
      {
         // Buy levels go down from base price
         price = m_basePrice - priceOffset;
      }
      else
      {
         // Sell levels go up from base price
         price = m_basePrice + priceOffset;
      }
      
      return NormalizePrice(m_symbol, price);
   }
   
   //--- Generate buy grid levels
   bool GenerateBuyGridLevels(double baseLot)
   {
      m_buyGrid.ResetAll();
      
      for(int i = 0; i < m_maxLevels; i++)
      {
         m_buyGrid.levels[i].index     = i;
         m_buyGrid.levels[i].price     = CalculateLevelPrice(i, GRID_DIRECTION_BUY);
         m_buyGrid.levels[i].lotSize   = baseLot;
         m_buyGrid.levels[i].direction = GRID_DIRECTION_BUY;
         m_buyGrid.levels[i].status    = GRID_LEVEL_EMPTY;
      }
      
      return true;
   }
   
   //--- Generate sell grid levels
   bool GenerateSellGridLevels(double baseLot)
   {
      m_sellGrid.ResetAll();
      
      for(int i = 0; i < m_maxLevels; i++)
      {
         m_sellGrid.levels[i].index     = i;
         m_sellGrid.levels[i].price     = CalculateLevelPrice(i, GRID_DIRECTION_SELL);
         m_sellGrid.levels[i].lotSize   = baseLot;
         m_sellGrid.levels[i].direction = GRID_DIRECTION_SELL;
         m_sellGrid.levels[i].status    = GRID_LEVEL_EMPTY;
      }
      
      return true;
   }
   
   //--- Get buy grid level by index
   SGridLevel GetBuyLevel(int index) const
   {
      if(index >= 0 && index < m_maxLevels)
         return m_buyGrid.levels[index];
      
      SGridLevel empty;
      return empty;
   }
   
   //--- Get sell grid level by index
   SGridLevel GetSellLevel(int index) const
   {
      if(index >= 0 && index < m_maxLevels)
         return m_sellGrid.levels[index];
      
      SGridLevel empty;
      return empty;
   }
   
   //--- Update buy level status
   void UpdateBuyLevelStatus(int index, ENUM_GRID_LEVEL_STATUS status, ulong ticket = 0)
   {
      if(index >= 0 && index < m_maxLevels)
      {
         m_buyGrid.levels[index].status = status;
         if(ticket > 0)
            m_buyGrid.levels[index].ticket = ticket;
         if(status == GRID_LEVEL_ACTIVE)
            m_buyGrid.levels[index].fillTime = TimeCurrent();
      }
   }
   
   //--- Update sell level status
   void UpdateSellLevelStatus(int index, ENUM_GRID_LEVEL_STATUS status, ulong ticket = 0)
   {
      if(index >= 0 && index < m_maxLevels)
      {
         m_sellGrid.levels[index].status = status;
         if(ticket > 0)
            m_sellGrid.levels[index].ticket = ticket;
         if(status == GRID_LEVEL_ACTIVE)
            m_sellGrid.levels[index].fillTime = TimeCurrent();
      }
   }
   
   //--- Get total active positions count
   int GetTotalActivePositions()
   {
      m_buyGrid.UpdateCounts();
      m_sellGrid.UpdateCounts();
      return m_buyGrid.activeLevels + m_sellGrid.activeLevels;
   }
   
   //--- Get total pending orders count
   int GetTotalPendingOrders()
   {
      m_buyGrid.UpdateCounts();
      m_sellGrid.UpdateCounts();
      return m_buyGrid.pendingLevels + m_sellGrid.pendingLevels;
   }
   
   //--- Get total lots in grid
   double GetTotalLots()
   {
      m_buyGrid.CalculateAveragePrice();
      m_sellGrid.CalculateAveragePrice();
      return m_buyGrid.totalLots + m_sellGrid.totalLots;
   }
   
   //--- Get total floating profit
   double GetTotalFloatingProfit()
   {
      m_buyGrid.UpdateCounts();
      m_sellGrid.UpdateCounts();
      return m_buyGrid.totalProfit + m_sellGrid.totalProfit;
   }
   
   //--- Find level index by ticket in buy grid
   int FindBuyLevelByTicket(ulong ticket)
   {
      for(int i = 0; i < m_maxLevels; i++)
      {
         if(m_buyGrid.levels[i].ticket == ticket)
            return i;
      }
      return -1;
   }
   
   //--- Find level index by ticket in sell grid
   int FindSellLevelByTicket(ulong ticket)
   {
      for(int i = 0; i < m_maxLevels; i++)
      {
         if(m_sellGrid.levels[i].ticket == ticket)
            return i;
      }
      return -1;
   }
   
   //--- Get next empty buy level index
   int GetNextEmptyBuyLevel()
   {
      return m_buyGrid.GetNextEmptyIndex();
   }
   
   //--- Get next empty sell level index
   int GetNextEmptySellLevel()
   {
      return m_sellGrid.GetNextEmptyIndex();
   }
   
   //--- Check if should add new buy level
   bool ShouldAddNewBuyLevel(double currentPrice)
   {
      int nextIndex = m_buyGrid.GetNextEmptyIndex();
      if(nextIndex < 0)
         return false;
      
      double nextLevelPrice = CalculateLevelPrice(nextIndex, GRID_DIRECTION_BUY);
      return currentPrice <= nextLevelPrice;
   }
   
   //--- Check if should add new sell level
   bool ShouldAddNewSellLevel(double currentPrice)
   {
      int nextIndex = m_sellGrid.GetNextEmptyIndex();
      if(nextIndex < 0)
         return false;
      
      double nextLevelPrice = CalculateLevelPrice(nextIndex, GRID_DIRECTION_SELL);
      return currentPrice >= nextLevelPrice;
   }
   
   //--- Reset all grids
   void ResetAllGrids()
   {
      m_buyGrid.ResetAll();
      m_sellGrid.ResetAll();
      m_basePrice = 0;
      Logger.Info("All grids reset");
   }
   
   //--- Check if initialized
   bool IsInitialized() const
   {
      return m_isInitialized;
   }
   
   //--- Get status summary
   string GetStatusSummary()
   {
      m_buyGrid.UpdateCounts();
      m_sellGrid.UpdateCounts();
      
      return StringFormat(
         "Grid Status: Buy[A:%d P:%d] Sell[A:%d P:%d] TotalLots:%.2f Profit:%.2f",
         m_buyGrid.activeLevels, m_buyGrid.pendingLevels,
         m_sellGrid.activeLevels, m_sellGrid.pendingLevels,
         GetTotalLots(), GetTotalFloatingProfit()
      );
   }
};
//+------------------------------------------------------------------+
