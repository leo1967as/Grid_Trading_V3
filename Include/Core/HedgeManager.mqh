//+------------------------------------------------------------------+
//|                                                 HedgeManager.mqh |
//|                                     Grid Survival Protocol EA    |
//|                                                                  |
//| Description: Soft Lock (Hedge) Manager                           |
//|              - Freezes drawdown by hedging net exposure          |
//|              - Monitors locked state                             |
//+------------------------------------------------------------------+
#property copyright "Grid Survival Protocol"
#property link      ""
#property version   "1.00"

#include "../Utils/Common.mqh"
#include "../Utils/Logger.mqh"
#include "../Models/TradeState.mqh"
#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| Hedge Manager Class                                              |
//+------------------------------------------------------------------+
class CHedgeManager
{
private:
   string         m_symbol;
   long           m_magic;
   CTrade         m_trade;
   
   bool           m_isLocked;
   ulong          m_hedgeTicket;
   double         m_lockedEquity;
   
public:
   //--- Constructor
   CHedgeManager()
   {
      m_symbol        = "";
      m_magic         = 0;
      m_isLocked      = false;
      m_hedgeTicket   = 0;
      m_lockedEquity  = 0;
   }
   
   //--- Destructor
   ~CHedgeManager() {}
   
   //--- Initialize
   bool Init(string symbol, long magic)
   {
      m_symbol = symbol;
      m_magic  = magic;
      
      m_trade.SetExpertMagicNumber(m_magic);
      m_trade.SetMarginMode();
      m_trade.SetTypeFillingBySymbol(m_symbol);
      m_trade.SetDeviationInPoints(10);
      
      m_isLocked = false;
      m_hedgeTicket = 0;
      
      return true;
   }
   
   //--- Check if system is locked
   bool IsLocked() const
   {
      return m_isLocked;
   }
   
   //--- Check condition and execute lock if needed
   bool CheckAndExecuteLock(double currentDD, double triggerDD, SSystemState &state)
   {
      // If already locked, do nothing (or monitor lock health)
      if(m_isLocked) 
         return true;
         
      // Check trigger
      if(currentDD < triggerDD)
         return false;
         
      Logger.Warning(StringFormat("Emergency DD Triggered (%.2f%% >= %.2f%%)! Executing Soft Lock...", 
                                  currentDD, triggerDD));
                                  
      // Calculate Net Exposure
      double buyLots  = 0;
      double sellLots = 0;
      int buyCount    = 0;
      int sellCount   = 0;
      
      CalculateExposure(buyLots, sellLots, buyCount, sellCount);
      
      double netLots = buyLots - sellLots;
      
      // Execute Hedge
      if(MathAbs(netLots) < 0.01)
      {
         Logger.Info("Net exposure is already balanced. System Locked without new order.");
         LockSystem(state);
         return true;
      }
      
      bool result = false;
      if(netLots > 0)
      {
         // Net Long -> Open Sell
         Logger.Info(StringFormat("Net Long %.2f lots. Opening SELL Hedge...", netLots));
         result = ExecuteHedgeTrade(ORDER_TYPE_SELL, netLots);
      }
      else
      {
         // Net Short -> Open Buy
         Logger.Info(StringFormat("Net Short %.2f lots. Opening BUY Hedge...", MathAbs(netLots)));
         result = ExecuteHedgeTrade(ORDER_TYPE_BUY, MathAbs(netLots));
      }
      
      if(result)
      {
         LockSystem(state);
         return true;
      }
      else
      {
         Logger.Error("Failed to execute Hedge Order! System NOT Locked.");
         return false;
      }
   }
   
   //--- Release lock (Manual or Strategy)
   void Unlock(SSystemState &state)
   {
      m_isLocked = false;
      m_hedgeTicket = 0;
      state.SetState(EA_STATE_RECOVERY, "Hedge released");
      Logger.Info("Soft Lock Released. System entering RECOVERY mode.");
   }

private:
   //--- Helpers
   void CalculateExposure(double &buyLots, double &sellLots, int &buyCount, int &sellCount)
   {
      buyLots = 0; sellLots = 0;
      buyCount = 0; sellCount = 0;
      
      for(int i=0; i<PositionsTotal(); i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket <= 0) continue;
         
         if(PositionGetString(POSITION_SYMBOL) == m_symbol &&
            PositionGetInteger(POSITION_MAGIC) == m_magic)
         {
            double vol = PositionGetDouble(POSITION_VOLUME);
            long type  = PositionGetInteger(POSITION_TYPE);
            
            if(type == POSITION_TYPE_BUY)
            {
               buyLots += vol;
               buyCount++;
            }
            else if(type == POSITION_TYPE_SELL)
            {
               sellLots += vol;
               sellCount++;
            }
         }
      }
   }
   
   bool ExecuteHedgeTrade(ENUM_ORDER_TYPE type, double vol)
   {
      double price = (type == ORDER_TYPE_BUY) ? SymbolInfoDouble(m_symbol, SYMBOL_ASK) : SymbolInfoDouble(m_symbol, SYMBOL_BID);
      
      if(m_trade.PositionOpen(m_symbol, type, vol, price, 0, 0, "Soft Lock Hedge"))
      {
         m_hedgeTicket = m_trade.ResultOrder();
         Logger.Info(StringFormat("Hedge Order Opened: Ticket=%d, Vol=%.2f", m_hedgeTicket, vol));
         return true;
      }
      
      Logger.Error(StringFormat("Hedge Open Failed: %d", m_trade.ResultRetcode()));
      return false;
   }
   
   void LockSystem(SSystemState &state)
   {
      m_isLocked = true;
      m_lockedEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      state.SetState(EA_STATE_LOCKED, "Emergency Soft Lock Active");
   }
};
