//+------------------------------------------------------------------+
//|                                          DeEscalationEngine.mqh |
//|                               Grid Survival Protocol EA - Phase 6|
//|                                                                  |
//| Description: De-escalation Engine for Locked State Recovery     |
//|              - Micro Scalping to generate profit                 |
//|              - Partial Close worst positions using profit bucket |
//+------------------------------------------------------------------+
#property copyright "Grid Survival Protocol"
#property link      ""
#property version   "1.00"

#include <Trade/Trade.mqh>
#include "../Utils/Logger.mqh"
#include "../Models/TradeState.mqh"

//+------------------------------------------------------------------+
//| De-escalation Engine Class                                        |
//+------------------------------------------------------------------+
class CDeEscalationEngine
{
private:
   string         m_symbol;
   long           m_magic;
   CTrade         m_trade;
   
   double         m_recoveryBucket;     // Accumulated profit ($)
   ulong          m_scalpTicket;        // Current scalp position ticket
   double         m_recoveryLot;        // Fixed lot for scalps
   int            m_recoveryTP;         // TP points
   int            m_scalpCooldown;      // Seconds between scalp attempts
   
   bool           m_isScalpActive;
   datetime       m_lastScalpTime;
   
public:
   //--- Constructor
   CDeEscalationEngine()
   {
      m_symbol          = "";
      m_magic           = 0;
      m_recoveryBucket  = 0;
      m_scalpTicket     = 0;
      m_recoveryLot     = 0.01;
      m_recoveryTP      = 50;
      m_scalpCooldown   = 60;
      m_isScalpActive   = false;
      m_lastScalpTime   = 0;
   }
   
   //--- Destructor
   ~CDeEscalationEngine() {}
   
   //--- Initialize
   bool Init(string symbol, long magic, double lot, int tp, int cooldown = 60)
   {
      m_symbol        = symbol;
      m_magic         = magic;
      m_recoveryLot   = lot;
      m_recoveryTP    = tp;
      m_scalpCooldown = cooldown;
      
      m_trade.SetExpertMagicNumber(m_magic);
      m_trade.SetMarginMode();
      m_trade.SetTypeFillingBySymbol(m_symbol);
      m_trade.SetDeviationInPoints(10);
      
      m_recoveryBucket = 0;
      m_scalpTicket    = 0;
      m_isScalpActive  = false;
      
      Logger.Info("DeEscalationEngine initialized");
      return true;
   }
   
   //--- Main Process Loop (Call from OnTick when LOCKED/DE_ESCALATING)
   void Process(SSystemState &state)
   {
      // 1. Update scalp status
      UpdateScalpStatus();
      
      // 2. Try to reduce positions if bucket has enough
      CheckAndReducePositions(state);
      
      // 3. Open new scalp if conditions met
      if(!m_isScalpActive && CanOpenScalp())
      {
         ExecuteScalp();
      }
   }
   
   //--- Called from OnTradeTransaction when a position closes
   void OnTradeClose(ulong ticket, double profit)
   {
      if(ticket == m_scalpTicket)
      {
         m_isScalpActive = false;
         m_scalpTicket   = 0;
         
         if(profit > 0)
         {
            m_recoveryBucket += profit;
            Logger.Info(StringFormat("Scalp Profit: +%.2f | Bucket: %.2f", profit, m_recoveryBucket));
         }
         else
         {
            Logger.Warning(StringFormat("Scalp Loss: %.2f | Bucket unchanged: %.2f", profit, m_recoveryBucket));
         }
      }
   }
   
   //--- Getters
   double GetRecoveryBucket() const { return m_recoveryBucket; }
   bool   IsScalpActive() const     { return m_isScalpActive; }
   
private:
   //--- Check if scalp position is still open
   void UpdateScalpStatus()
   {
      if(m_scalpTicket == 0)
      {
         m_isScalpActive = false;
         return;
      }
      
      // Check if position still exists
      if(!PositionSelectByTicket(m_scalpTicket))
      {
         // Position closed (TP/SL hit or manually)
         m_isScalpActive = false;
         m_scalpTicket   = 0;
      }
   }
   
   //--- Check cooldown
   bool CanOpenScalp()
   {
      if(TimeCurrent() - m_lastScalpTime < m_scalpCooldown)
         return false;
      
      return true;
   }
   
   //--- Execute Scalp Trade (Simple: Alternating Buy/Sell based on last bar)
   bool ExecuteScalp()
   {
      double point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
      double ask   = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      double bid   = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      
      // Simple Logic: Check last candle direction
      double open1  = iOpen(m_symbol, PERIOD_M5, 1);
      double close1 = iClose(m_symbol, PERIOD_M5, 1);
      
      bool result = false;
      
      if(close1 > open1)
      {
         // Bullish -> Buy Scalp
         double tp = ask + (m_recoveryTP * point);
         double sl = ask - (m_recoveryTP * 2 * point); // SL = 2x TP (1:0.5 RR)
         
         if(m_trade.Buy(m_recoveryLot, m_symbol, ask, sl, tp, "Recovery_Scalp_BUY"))
         {
            m_scalpTicket   = m_trade.ResultOrder();
            m_isScalpActive = true;
            m_lastScalpTime = TimeCurrent();
            Logger.Info(StringFormat("Recovery Scalp BUY opened: Ticket=%d", m_scalpTicket));
            result = true;
         }
      }
      else
      {
         // Bearish -> Sell Scalp
         double tp = bid - (m_recoveryTP * point);
         double sl = bid + (m_recoveryTP * 2 * point);
         
         if(m_trade.Sell(m_recoveryLot, m_symbol, bid, sl, tp, "Recovery_Scalp_SELL"))
         {
            m_scalpTicket   = m_trade.ResultOrder();
            m_isScalpActive = true;
            m_lastScalpTime = TimeCurrent();
            Logger.Info(StringFormat("Recovery Scalp SELL opened: Ticket=%d", m_scalpTicket));
            result = true;
         }
      }
      
      return result;
   }
   
   //--- Check and Reduce Positions
   void CheckAndReducePositions(SSystemState &state)
   {
      // Find worst position (largest unrealized loss)
      ulong  worstTicket = 0;
      double worstLoss   = 0;
      double worstVolume = 0;
      
      for(int i = 0; i < PositionsTotal(); i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket <= 0) continue;
         
         if(PositionGetString(POSITION_SYMBOL) == m_symbol &&
            PositionGetInteger(POSITION_MAGIC) == m_magic)
         {
            string comment = PositionGetString(POSITION_COMMENT);
            // Skip scalp positions
            if(StringFind(comment, "Recovery_Scalp") >= 0) continue;
            if(StringFind(comment, "Soft Lock Hedge") >= 0) continue;
            
            double profit = PositionGetDouble(POSITION_PROFIT);
            if(profit < worstLoss)
            {
               worstLoss   = profit;
               worstTicket = ticket;
               worstVolume = PositionGetDouble(POSITION_VOLUME);
            }
         }
      }
      
      if(worstTicket == 0) 
      {
         // No more grid positions -> Unlock
         Logger.Info("No more grid positions. Unlocking system.");
         state.SetState(EA_STATE_IDLE, "De-escalation Complete");
         m_recoveryBucket = 0;
         return;
      }
      
      // Calculate cost to close 0.01 lot of worst position
      double costToClose = MathAbs(worstLoss) * (m_recoveryLot / worstVolume);
      
      Logger.Debug(StringFormat("Worst Position: Ticket=%d, Loss=%.2f, Cost to close 0.01=%.2f, Bucket=%.2f",
                                worstTicket, worstLoss, costToClose, m_recoveryBucket));
      
      // If bucket has enough, partial close
      if(m_recoveryBucket >= costToClose && costToClose > 0)
      {
         if(PartialClose(worstTicket, m_recoveryLot))
         {
            m_recoveryBucket -= costToClose;
            Logger.Info(StringFormat("Partial Closed 0.01 of Ticket %d. Bucket remaining: %.2f", 
                                     worstTicket, m_recoveryBucket));
         }
      }
   }
   
   //--- Partial Close a position
   bool PartialClose(ulong ticket, double lot)
   {
      if(!PositionSelectByTicket(ticket))
         return false;
      
      double volume = PositionGetDouble(POSITION_VOLUME);
      double closeVol = MathMin(lot, volume);
      
      long posType = PositionGetInteger(POSITION_TYPE);
      double price = (posType == POSITION_TYPE_BUY) ? 
                     SymbolInfoDouble(m_symbol, SYMBOL_BID) : 
                     SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      
      if(m_trade.PositionClosePartial(ticket, closeVol))
      {
         return true;
      }
      
      Logger.Error(StringFormat("Failed to partial close Ticket %d: %d", ticket, m_trade.ResultRetcode()));
      return false;
   }
};
