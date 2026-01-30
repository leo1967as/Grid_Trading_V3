//+------------------------------------------------------------------+
//|                                               TradeExecutor.mqh  |
//|                                Grid Survival Protocol EA - Core  |
//|                                                                  |
//| Description: Order Execution with Retry Logic                    |
//|              - Market orders                                     |
//|              - Pending orders                                    |
//|              - Close positions                                   |
//+------------------------------------------------------------------+
#property copyright "Grid Survival Protocol"
#property link      ""
#property version   "1.00"

#include "../Utils/Common.mqh"
#include "../Utils/Logger.mqh"

#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| Trade Result Structure                                           |
//+------------------------------------------------------------------+
struct STradeResult
{
   bool     success;        // Trade was successful
   ulong    ticket;         // Order/Position ticket
   double   price;          // Execution price
   double   volume;         // Executed volume
   int      retcode;        // Result code
   string   comment;        // Result comment
   
   void Reset()
   {
      success = false;
      ticket  = 0;
      price   = 0;
      volume  = 0;
      retcode = 0;
      comment = "";
   }
};

//+------------------------------------------------------------------+
//| Trade Executor Class                                             |
//+------------------------------------------------------------------+
class CTradeExecutor
{
private:
   string            m_symbol;           // Trading symbol
   ulong             m_magicNumber;      // EA magic number
   int               m_slippage;         // Max slippage in points
   int               m_maxRetries;       // Max retry attempts
   int               m_retryDelayMs;     // Delay between retries
   
   CTrade            m_trade;            // MT5 trade object
   bool              m_isInitialized;
   
public:
   //--- Constructor
   CTradeExecutor()
   {
      m_symbol        = "";
      m_magicNumber   = GRID_MAGIC_NUMBER;
      m_slippage      = 10;
      m_maxRetries    = MAX_RETRY_ATTEMPTS;
      m_retryDelayMs  = RETRY_DELAY_MS;
      m_isInitialized = false;
   }
   
   //--- Initialize
   bool Init(string symbol, ulong magicNumber = GRID_MAGIC_NUMBER, 
             int slippage = 10, int maxRetries = 5)
   {
      m_symbol      = symbol;
      m_magicNumber = magicNumber;
      m_slippage    = slippage;
      m_maxRetries  = maxRetries;
      
      // Configure trade object
      m_trade.SetExpertMagicNumber(m_magicNumber);
      m_trade.SetDeviationInPoints(m_slippage);
      m_trade.SetTypeFilling(ORDER_FILLING_IOC);
      m_trade.SetMarginMode();
      m_trade.LogLevel(LOG_LEVEL_ERRORS);
      
      m_isInitialized = true;
      Logger.Info(StringFormat("TradeExecutor initialized: Symbol=%s, Magic=%d, Slippage=%d", 
                               m_symbol, m_magicNumber, m_slippage));
      return true;
   }
   
   //--- Set slippage
   void SetSlippage(int slippage)
   {
      m_slippage = slippage;
      m_trade.SetDeviationInPoints(m_slippage);
   }
   
   //--- Open market buy order
   STradeResult Buy(double lots, double sl = 0, double tp = 0, string comment = "")
   {
      STradeResult result;
      result.Reset();
      
      lots = NormalizeLot(m_symbol, lots);
      
      for(int attempt = 0; attempt < m_maxRetries; attempt++)
      {
         double price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
         
         if(m_trade.Buy(lots, m_symbol, price, sl, tp, comment))
         {
            result.success = true;
            result.ticket  = m_trade.ResultDeal();
            result.price   = m_trade.ResultPrice();
            result.volume  = m_trade.ResultVolume();
            result.retcode = (int)m_trade.ResultRetcode();
            result.comment = "Success";
            
            Logger.LogTrade("BUY", m_symbol, lots, result.price, comment);
            return result;
         }
         
         // Log retry
         result.retcode = (int)m_trade.ResultRetcode();
         Logger.Warning(StringFormat("Buy attempt %d failed: %d - %s", 
                                     attempt + 1, result.retcode, 
                                     m_trade.ResultRetcodeDescription()));
         
         // Check if retryable
         if(!IsRetryableError(result.retcode))
            break;
         
         Sleep(m_retryDelayMs);
      }
      
      result.comment = m_trade.ResultRetcodeDescription();
      Logger.Error(StringFormat("Buy failed after %d attempts: %s", 
                                m_maxRetries, result.comment));
      return result;
   }
   
   //--- Open market sell order
   STradeResult Sell(double lots, double sl = 0, double tp = 0, string comment = "")
   {
      STradeResult result;
      result.Reset();
      
      lots = NormalizeLot(m_symbol, lots);
      
      for(int attempt = 0; attempt < m_maxRetries; attempt++)
      {
         double price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
         
         if(m_trade.Sell(lots, m_symbol, price, sl, tp, comment))
         {
            result.success = true;
            result.ticket  = m_trade.ResultDeal();
            result.price   = m_trade.ResultPrice();
            result.volume  = m_trade.ResultVolume();
            result.retcode = (int)m_trade.ResultRetcode();
            result.comment = "Success";
            
            Logger.LogTrade("SELL", m_symbol, lots, result.price, comment);
            return result;
         }
         
         result.retcode = (int)m_trade.ResultRetcode();
         Logger.Warning(StringFormat("Sell attempt %d failed: %d - %s", 
                                     attempt + 1, result.retcode,
                                     m_trade.ResultRetcodeDescription()));
         
         if(!IsRetryableError(result.retcode))
            break;
         
         Sleep(m_retryDelayMs);
      }
      
      result.comment = m_trade.ResultRetcodeDescription();
      Logger.Error(StringFormat("Sell failed after %d attempts: %s", 
                                m_maxRetries, result.comment));
      return result;
   }
   
   //--- Place buy limit order
   STradeResult BuyLimit(double lots, double price, double sl = 0, double tp = 0, 
                         datetime expiration = 0, string comment = "")
   {
      STradeResult result;
      result.Reset();
      
      lots  = NormalizeLot(m_symbol, lots);
      price = NormalizePrice(m_symbol, price);
      
      for(int attempt = 0; attempt < m_maxRetries; attempt++)
      {
         if(m_trade.BuyLimit(lots, price, m_symbol, sl, tp, 
                             ORDER_TIME_GTC, expiration, comment))
         {
            result.success = true;
            result.ticket  = m_trade.ResultOrder();
            result.price   = price;
            result.volume  = lots;
            result.retcode = (int)m_trade.ResultRetcode();
            result.comment = "Success";
            
            Logger.LogTrade("BUY_LIMIT", m_symbol, lots, price, comment);
            return result;
         }
         
         result.retcode = (int)m_trade.ResultRetcode();
         Logger.Warning(StringFormat("BuyLimit attempt %d failed: %d", 
                                     attempt + 1, result.retcode));
         
         if(!IsRetryableError(result.retcode))
            break;
         
         Sleep(m_retryDelayMs);
      }
      
      result.comment = m_trade.ResultRetcodeDescription();
      return result;
   }
   
   //--- Place sell limit order
   STradeResult SellLimit(double lots, double price, double sl = 0, double tp = 0,
                          datetime expiration = 0, string comment = "")
   {
      STradeResult result;
      result.Reset();
      
      lots  = NormalizeLot(m_symbol, lots);
      price = NormalizePrice(m_symbol, price);
      
      for(int attempt = 0; attempt < m_maxRetries; attempt++)
      {
         if(m_trade.SellLimit(lots, price, m_symbol, sl, tp,
                              ORDER_TIME_GTC, expiration, comment))
         {
            result.success = true;
            result.ticket  = m_trade.ResultOrder();
            result.price   = price;
            result.volume  = lots;
            result.retcode = (int)m_trade.ResultRetcode();
            result.comment = "Success";
            
            Logger.LogTrade("SELL_LIMIT", m_symbol, lots, price, comment);
            return result;
         }
         
         result.retcode = (int)m_trade.ResultRetcode();
         Logger.Warning(StringFormat("SellLimit attempt %d failed: %d",
                                     attempt + 1, result.retcode));
         
         if(!IsRetryableError(result.retcode))
            break;
         
         Sleep(m_retryDelayMs);
      }
      
      result.comment = m_trade.ResultRetcodeDescription();
      return result;
   }
   
   //--- Close position by ticket
   bool ClosePosition(ulong ticket)
   {
      for(int attempt = 0; attempt < m_maxRetries; attempt++)
      {
         if(m_trade.PositionClose(ticket, m_slippage))
         {
            Logger.Info(StringFormat("Position %d closed successfully", ticket));
            return true;
         }
         
         uint retcode = m_trade.ResultRetcode();
         Logger.Warning(StringFormat("Close position %d attempt %d failed: %d",
                                     ticket, attempt + 1, retcode));
         
         if(!IsRetryableError((int)retcode))
            break;
         
         Sleep(m_retryDelayMs);
      }
      
      Logger.Error(StringFormat("Failed to close position %d", ticket));
      return false;
   }
   
   //--- Close all EA positions
   int CloseAllPositions()
   {
      int closed = 0;
      int total  = PositionsTotal();
      
      // Close in reverse order
      for(int i = total - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         
         if(PositionSelectByTicket(ticket))
         {
            if(PositionGetString(POSITION_SYMBOL) != m_symbol)
               continue;
            
            if(PositionGetInteger(POSITION_MAGIC) != (long)m_magicNumber)
               continue;
            
            if(ClosePosition(ticket))
               closed++;
         }
      }
      
      Logger.Info(StringFormat("Closed %d positions", closed));
      return closed;
   }
   
   //--- Delete pending order by ticket
   bool DeleteOrder(ulong ticket)
   {
      for(int attempt = 0; attempt < m_maxRetries; attempt++)
      {
         if(m_trade.OrderDelete(ticket))
         {
            Logger.Info(StringFormat("Order %d deleted successfully", ticket));
            return true;
         }
         
         uint retcode = m_trade.ResultRetcode();
         Logger.Warning(StringFormat("Delete order %d attempt %d failed: %d",
                                     ticket, attempt + 1, retcode));
         
         if(!IsRetryableError((int)retcode))
            break;
         
         Sleep(m_retryDelayMs);
      }
      
      Logger.Error(StringFormat("Failed to delete order %d", ticket));
      return false;
   }
   
   //--- Delete all EA pending orders
   int DeleteAllOrders()
   {
      int deleted = 0;
      int total   = OrdersTotal();
      
      for(int i = total - 1; i >= 0; i--)
      {
         ulong ticket = OrderGetTicket(i);
         
         if(OrderSelect(ticket))
         {
            if(OrderGetString(ORDER_SYMBOL) != m_symbol)
               continue;
            
            if(OrderGetInteger(ORDER_MAGIC) != (long)m_magicNumber)
               continue;
            
            if(DeleteOrder(ticket))
               deleted++;
         }
      }
      
      Logger.Info(StringFormat("Deleted %d orders", deleted));
      return deleted;
   }
   
   //--- Check if initialized
   bool IsInitialized() const
   {
      return m_isInitialized;
   }
   
private:
   //--- Check if error is retryable
   bool IsRetryableError(int retcode)
   {
      switch(retcode)
      {
         case TRADE_RETCODE_REQUOTE:
         case TRADE_RETCODE_CONNECTION:
         case TRADE_RETCODE_PRICE_CHANGED:
         case TRADE_RETCODE_TIMEOUT:
         case TRADE_RETCODE_PRICE_OFF:
         case TRADE_RETCODE_SERVER_DISABLES_AT:
         case TRADE_RETCODE_CLIENT_DISABLES_AT:
            return true;
         default:
            return false;
      }
   }
};
//+------------------------------------------------------------------+
