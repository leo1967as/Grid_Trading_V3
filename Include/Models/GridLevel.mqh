//+------------------------------------------------------------------+
//|                                                    GridLevel.mqh |
//|                               Grid Survival Protocol EA - Models |
//|                                                                  |
//| Description: Grid Level Data Structure                           |
//|              - Stores information about each grid level          |
//|              - Tracks price, ticket, status, and lot size        |
//+------------------------------------------------------------------+
#property copyright "Grid Survival Protocol"
#property link      ""
#property version   "1.00"

//+------------------------------------------------------------------+
//| Enums                                                            |
//+------------------------------------------------------------------+
enum ENUM_GRID_LEVEL_STATUS
{
   GRID_LEVEL_EMPTY = 0,      // No order placed
   GRID_LEVEL_PENDING,        // Pending order placed
   GRID_LEVEL_ACTIVE,         // Position is open
   GRID_LEVEL_CLOSED          // Position has been closed
};

enum ENUM_GRID_DIRECTION
{
   GRID_DIRECTION_BUY = 0,    // Buy grid (long positions)
   GRID_DIRECTION_SELL        // Sell grid (short positions)
};

//+------------------------------------------------------------------+
//| Structures                                                       |
//+------------------------------------------------------------------+
struct SGridLevel
{
   int                     index;           // Grid level index (0 = entry, 1+ = averaging levels)
   double                  price;           // Price level for this grid
   double                  lotSize;         // Lot size for this level
   ulong                   ticket;          // Order/Position ticket
   ENUM_GRID_LEVEL_STATUS  status;          // Current status
   ENUM_GRID_DIRECTION     direction;       // Buy or Sell
   datetime                openTime;        // Time when order was placed
   datetime                fillTime;        // Time when order was filled
   double                  profit;          // Current profit (if active)
   double                  takeProfit;      // Take profit price
   double                  stopLoss;        // Stop loss price (if any)
   
   //--- Constructor
   void SGridLevel()
   {
      Reset();
   }
   
   //--- Reset to default values
   void Reset()
   {
      index      = -1;
      price      = 0.0;
      lotSize    = 0.0;
      ticket     = 0;
      status     = GRID_LEVEL_EMPTY;
      direction  = GRID_DIRECTION_BUY;
      openTime   = 0;
      fillTime   = 0;
      profit     = 0.0;
      takeProfit = 0.0;
      stopLoss   = 0.0;
   }
   
   //--- Check if level is active
   bool IsActive() const
   {
      return (status == GRID_LEVEL_ACTIVE);
   }
   
   //--- Check if level has pending order
   bool IsPending() const
   {
      return (status == GRID_LEVEL_PENDING);
   }
   
   //--- Check if level is empty
   bool IsEmpty() const
   {
      return (status == GRID_LEVEL_EMPTY);
   }
};

//+------------------------------------------------------------------+
//| Grid Array Helper                                                |
//+------------------------------------------------------------------+
struct SGridArray
{
   SGridLevel levels[];       // Array of grid levels
   int        maxLevels;      // Maximum allowed levels
   int        activeLevels;   // Count of active levels
   int        pendingLevels;  // Count of pending levels
   double     totalLots;      // Total lots in grid
   double     averagePrice;   // Average entry price
   double     totalProfit;    // Total floating profit
   
   //--- Initialize grid array
   bool Init(int maxGridLevels)
   {
      maxLevels     = maxGridLevels;
      activeLevels  = 0;
      pendingLevels = 0;
      totalLots     = 0.0;
      averagePrice  = 0.0;
      totalProfit   = 0.0;
      
      if(ArrayResize(levels, maxLevels) != maxLevels)
         return false;
      
      for(int i = 0; i < maxLevels; i++)
      {
         levels[i].Reset();
         levels[i].index = i;
      }
      
      return true;
   }
   
   //--- Get next empty level index (-1 if full)
   int GetNextEmptyIndex()
   {
      for(int i = 0; i < maxLevels; i++)
      {
         if(levels[i].IsEmpty())
            return i;
      }
      return -1;
   }
   
   //--- Calculate average entry price
   double CalculateAveragePrice()
   {
      double totalValue = 0.0;
      totalLots = 0.0;
      
      for(int i = 0; i < maxLevels; i++)
      {
         if(levels[i].IsActive())
         {
            totalValue += levels[i].price * levels[i].lotSize;
            totalLots  += levels[i].lotSize;
         }
      }
      
      if(totalLots > 0)
         averagePrice = totalValue / totalLots;
      else
         averagePrice = 0.0;
      
      return averagePrice;
   }
   
   //--- Update counts
   void UpdateCounts()
   {
      activeLevels  = 0;
      pendingLevels = 0;
      totalProfit   = 0.0;
      
      for(int i = 0; i < maxLevels; i++)
      {
         if(levels[i].IsActive())
         {
            activeLevels++;
            totalProfit += levels[i].profit;
         }
         else if(levels[i].IsPending())
         {
            pendingLevels++;
         }
      }
   }
   
   //--- Reset all levels
   void ResetAll()
   {
      for(int i = 0; i < maxLevels; i++)
      {
         levels[i].Reset();
         levels[i].index = i;
      }
      activeLevels  = 0;
      pendingLevels = 0;
      totalLots     = 0.0;
      averagePrice  = 0.0;
      totalProfit   = 0.0;
   }
};
//+------------------------------------------------------------------+
