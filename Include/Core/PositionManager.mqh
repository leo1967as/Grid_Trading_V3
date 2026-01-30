//+------------------------------------------------------------------+
//|                                             PositionManager.mqh  |
//|                                Grid Survival Protocol EA - Core  |
//|                                                                  |
//| Description: Position Tracking and Management                    |
//|              - Track open positions                              |
//|              - Calculate total exposure                          |
//|              - Sync with MT5 positions                           |
//+------------------------------------------------------------------+
#property copyright "Grid Survival Protocol"
#property link      ""
#property version   "1.00"

#include "../Utils/Common.mqh"
#include "../Utils/Logger.mqh"
#include "../Models/GridLevel.mqh"

#include <Trade/PositionInfo.mqh>

//+------------------------------------------------------------------+
//| Position Summary Structure                                       |
//+------------------------------------------------------------------+
struct SPositionSummary
{
   int      totalPositions;     // Total open positions
   int      buyPositions;       // Buy positions count
   int      sellPositions;      // Sell positions count
   double   totalBuyLots;       // Total buy lots
   double   totalSellLots;      // Total sell lots
   double   netLots;            // Net exposure (buy - sell)
   double   buyProfit;          // Buy positions profit
   double   sellProfit;         // Sell positions profit
   double   totalProfit;        // Total floating profit
   double   avgBuyPrice;        // Average buy price
   double   avgSellPrice;       // Average sell price
   
   void Reset()
   {
      totalPositions = 0;
      buyPositions   = 0;
      sellPositions  = 0;
      totalBuyLots   = 0;
      totalSellLots  = 0;
      netLots        = 0;
      buyProfit      = 0;
      sellProfit     = 0;
      totalProfit    = 0;
      avgBuyPrice    = 0;
      avgSellPrice   = 0;
   }
};

//+------------------------------------------------------------------+
//| Position Manager Class                                           |
//+------------------------------------------------------------------+
class CPositionManager
{
private:
   string            m_symbol;           // Trading symbol
   ulong             m_magicNumber;      // EA magic number
   CPositionInfo     m_positionInfo;     // MT5 position info object
   
   SPositionSummary  m_summary;          // Current position summary
   ulong             m_positionTickets[];// Array of position tickets
   
   bool              m_isInitialized;
   
public:
   //--- Constructor
   CPositionManager()
   {
      m_symbol        = "";
      m_magicNumber   = GRID_MAGIC_NUMBER;
      m_isInitialized = false;
      m_summary.Reset();
   }
   
   //--- Initialize
   bool Init(string symbol, ulong magicNumber = GRID_MAGIC_NUMBER)
   {
      m_symbol      = symbol;
      m_magicNumber = magicNumber;
      m_summary.Reset();
      ArrayResize(m_positionTickets, 0);
      
      m_isInitialized = true;
      Logger.Info(StringFormat("PositionManager initialized: Symbol=%s, Magic=%d", 
                               m_symbol, m_magicNumber));
      return true;
   }
   
   //--- Update (call on each tick) - alias for UpdateSummary
   void Update()
   {
      UpdateSummary();
   }
   
   //--- Update position summary (call on each tick)
   void UpdateSummary()
   {
      m_summary.Reset();
      ArrayResize(m_positionTickets, 0);
      
      double buyValue  = 0;
      double sellValue = 0;
      
      int total = PositionsTotal();
      
      for(int i = 0; i < total; i++)
      {
         ulong ticket = PositionGetTicket(i);
         
         if(!m_positionInfo.SelectByTicket(ticket))
            continue;
         
         // Filter by symbol and magic number
         if(m_positionInfo.Symbol() != m_symbol)
            continue;
         
         if(m_positionInfo.Magic() != m_magicNumber)
            continue;
         
         // Add to tickets array
         int size = ArraySize(m_positionTickets);
         ArrayResize(m_positionTickets, size + 1);
         m_positionTickets[size] = ticket;
         
         // Update summary
         m_summary.totalPositions++;
         m_summary.totalProfit += m_positionInfo.Profit() + 
                                  m_positionInfo.Swap() + 
                                  m_positionInfo.Commission();
         
         double lots  = m_positionInfo.Volume();
         double price = m_positionInfo.PriceOpen();
         
         if(m_positionInfo.PositionType() == POSITION_TYPE_BUY)
         {
            m_summary.buyPositions++;
            m_summary.totalBuyLots += lots;
            m_summary.buyProfit    += m_positionInfo.Profit();
            buyValue               += lots * price;
         }
         else if(m_positionInfo.PositionType() == POSITION_TYPE_SELL)
         {
            m_summary.sellPositions++;
            m_summary.totalSellLots += lots;
            m_summary.sellProfit    += m_positionInfo.Profit();
            sellValue               += lots * price;
         }
      }
      
      // Calculate averages
      if(m_summary.totalBuyLots > 0)
         m_summary.avgBuyPrice = buyValue / m_summary.totalBuyLots;
      
      if(m_summary.totalSellLots > 0)
         m_summary.avgSellPrice = sellValue / m_summary.totalSellLots;
      
      m_summary.netLots = m_summary.totalBuyLots - m_summary.totalSellLots;
   }
   
   //--- Get position summary
   SPositionSummary GetSummary()
   {
      return m_summary;
   }
   
   //--- Get total positions count
   int GetTotalPositions()
   {
      return m_summary.totalPositions;
   }
   
   //--- Get total floating profit
   double GetTotalProfit()
   {
      return m_summary.totalProfit;
   }
   
   //--- Get total lots
   double GetTotalLots()
   {
      return m_summary.totalBuyLots + m_summary.totalSellLots;
   }
   
   //--- Get net exposure
   double GetNetExposure()
   {
      return m_summary.netLots;
   }
   
   //--- Check if any positions exist
   bool HasPositions()
   {
      return m_summary.totalPositions > 0;
   }
   
   //--- Check if buy positions exist
   bool HasBuyPositions()
   {
      return m_summary.buyPositions > 0;
   }
   
   //--- Check if sell positions exist
   bool HasSellPositions()
   {
      return m_summary.sellPositions > 0;
   }
   
   //--- Get position tickets array
   void GetPositionTickets(ulong &tickets[])
   {
      ArrayResize(tickets, ArraySize(m_positionTickets));
      ArrayCopy(tickets, m_positionTickets);
   }
   
   //--- Check if position exists by ticket
   bool PositionExists(ulong ticket)
   {
      for(int i = 0; i < ArraySize(m_positionTickets); i++)
      {
         if(m_positionTickets[i] == ticket)
            return true;
      }
      return false;
   }
   
   //--- Calculate breakeven price for all positions
   double CalculateBreakevenPrice()
   {
      if(m_summary.totalPositions == 0)
         return 0;
      
      double totalValue = 0;
      double totalLots  = 0;
      
      for(int i = 0; i < ArraySize(m_positionTickets); i++)
      {
         if(!m_positionInfo.SelectByTicket(m_positionTickets[i]))
            continue;
         
         double lots  = m_positionInfo.Volume();
         double price = m_positionInfo.PriceOpen();
         
         // Adjust for direction
         if(m_positionInfo.PositionType() == POSITION_TYPE_BUY)
         {
            totalValue += lots * price;
            totalLots  += lots;
         }
         else
         {
            totalValue -= lots * price;
            totalLots  -= lots;
         }
      }
      
      if(MathAbs(totalLots) > LOT_EPSILON)
         return totalValue / totalLots;
      
      return 0;
   }
   
   //--- Calculate margin used by EA positions
   double CalculateMarginUsed()
   {
      double totalMargin = 0;
      
      for(int i = 0; i < ArraySize(m_positionTickets); i++)
      {
         if(!m_positionInfo.SelectByTicket(m_positionTickets[i]))
            continue;
         
         // Get margin for this position
         double margin = 0;
         ENUM_ORDER_TYPE orderType = (m_positionInfo.PositionType() == POSITION_TYPE_BUY) ?
                                     ORDER_TYPE_BUY : ORDER_TYPE_SELL;
         
         if(OrderCalcMargin(orderType, m_symbol, m_positionInfo.Volume(),
                            m_positionInfo.PriceCurrent(), margin))
         {
            totalMargin += margin;
         }
      }
      
      return totalMargin;
   }
   
   //--- Get oldest position time
   datetime GetOldestPositionTime()
   {
      datetime oldest = TimeCurrent();
      
      for(int i = 0; i < ArraySize(m_positionTickets); i++)
      {
         if(!m_positionInfo.SelectByTicket(m_positionTickets[i]))
            continue;
         
         if(m_positionInfo.Time() < oldest)
            oldest = m_positionInfo.Time();
      }
      
      return oldest;
   }
   
   //--- Get status summary string
   string GetStatusSummary()
   {
      return StringFormat(
         "Positions: Buy[%d/%.2f lots] Sell[%d/%.2f lots] Profit:%.2f",
         m_summary.buyPositions, m_summary.totalBuyLots,
         m_summary.sellPositions, m_summary.totalSellLots,
         m_summary.totalProfit
      );
   }
   
   //--- Check if initialized
   bool IsInitialized() const
   {
      return m_isInitialized;
   }
};
//+------------------------------------------------------------------+
