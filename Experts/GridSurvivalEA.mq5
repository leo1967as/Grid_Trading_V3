//+------------------------------------------------------------------+
//|                                             GridSurvivalEA.mq5   |
//|                                     Grid Survival Protocol EA    |
//|                                                                  |
//| Description: Grid Trading EA with Multi-Layer Protection         |
//|              - ATR-based dynamic grid spacing                    |
//|              - Multi-layer protection system                     |
//|              - Session and news filters                          |
//|              - Performance tracking                              |
//+------------------------------------------------------------------+
#property copyright   "Grid Survival Protocol"
#property link        ""
#property version     "1.00"
#property description "Grid Trading EA with Survival Protocol Protection"
#property strict

//+------------------------------------------------------------------+
//| Include Files                                                    |
//+------------------------------------------------------------------+
// Models
#include "..\Include\Models\GridLevel.mqh"
#include "..\Include\Models\TradeState.mqh"
#include "..\Include\Models\ProtectionState.mqh"

// Utils
#include "..\Include\Utils\Common.mqh"
#include "..\Include\Utils\Logger.mqh"
#include "..\Include\Utils\ConfigLoader.mqh"

// Core
#include "..\Include\Core\GridEngine.mqh"
#include "..\Include\Core\PositionManager.mqh"
#include "..\Include\Core\TradeExecutor.mqh"
#include "..\Include\Core\HedgeManager.mqh" // Phase 5: Soft Lock

// Protection
#include "..\Include\Protection\RiskManager.mqh"
#include "..\Include\Protection\DrawdownMonitor.mqh"
#include "..\Include\Protection\EmergencyStop.mqh"
#include "..\Include\Protection\HardStop.mqh"
#include "..\Include\Protection\DailyLossLimit.mqh"

// Analysis
#include "..\Include\Analysis\MarketState.mqh"
#include "..\Include\Analysis\ATRCalculator.mqh"
#include "..\Include\Analysis\SessionFilter.mqh"
#include "..\Include\Analysis\NewsFilter.mqh"
#include "..\Include\Analysis\TrendFilter.mqh"

// Recovery
#include "..\Include\Recovery\AdaptiveSizing.mqh"
#include "..\Include\Recovery\DeEscalationEngine.mqh" // Phase 6: Recovery

// Metrics
#include "..\Include\Metrics\PerformanceTracker.mqh"
#include "..\Include\Metrics\EquityCurve.mqh"
#include "..\Include\Metrics\AlertManager.mqh"


//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
//--- Basic Settings
input group "=== Basic Settings ==="
input long     InpMagicNumber     = 777777;    // Magic Number
input double   InpBaseLotSize     = 0.01;      // Base Lot Size
input int      InpMaxGridLevels   = 10;        // Max Grid Levels
input ENUM_TRADE_DIRECTION_MODE InpTradeDirection = DIRECTION_LONG_ONLY; // Trade Direction

//--- ATR & Grid Settings
input group "=== ATR & Grid Settings ==="
input ENUM_TIMEFRAMES InpATRTimeframe = PERIOD_H1;  // ATR Timeframe
input int      InpATRPeriod       = 14;        // ATR Period
input double   InpATRMultiplier   = 1.5;       // ATR Multiplier for Grid Spacing
input bool     InpUseDynamicSpacing = true;   // Use Dynamic Spacing (ATR-based)
input int      InpFixedSpacing    = 500;       // Fixed Spacing (points) - Used if Dynamic OFF
input int      InpMinDynamicSpacing = 100;     // Min Dynamic Spacing (points)
input int      InpMaxDynamicSpacing = 2000;    // Max Dynamic Spacing (points)
input double   InpGridMultiplier  = 1.0;       // Lot Multiplier (1.0 = same, 1.5 = Martingale)
input int      InpTakeProfit      = 500;       // Take Profit (points)
input int      InpStopLoss        = 1000;      // Stop Loss (points)

//--- Protection Settings
input group "=== Protection Settings ==="
input bool     InpUseHedge        = false;     // Use Hedge (Soft Lock) when Emergency DD hit
input double   InpEmergencyStopDD = 10.0;      // Emergency Stop DD% (reduce size/Hedge)
input double   InpHardStopDD      = 20.0;      // Hard Stop DD% (close all)
input double   InpDailyLossLimit  = 5.0;       // Daily Loss Limit %
input bool     InpUseTrendFilter  = true;      // Use Trend Filter (Block entry if strong trend)
input int      InpTrendADXThreshold = 30;      // ADX Threshold for strong trend
input bool     InpUseWeeklyReset  = true;      // Enable Weekly Auto-Reset (Sunday)

//--- Risk Management
input group "=== Risk Management ==="
input double   InpRiskPerTrade    = 1.0;       // Risk Per Trade %
input double   InpMaxTotalRisk    = 10.0;      // Max Total Risk %
input double   InpMaxSpread       = 100.0;     // Max Spread (points) - XAUUSD typically 50-200

//--- Session Filter
input group "=== Session Filter ==="
input bool     InpUseSessionFilter = true;     // Use Session Filter
input int      InpSessionStart    = 2;         // Session Start Hour (server time)
input int      InpSessionEnd      = 22;        // Session End Hour (server time)
input bool     InpAvoidFriday     = true;      // Avoid Friday Evening
input int      InpFridayCutoff    = 20;        // Friday Cutoff Hour

//--- News Filter
input group "=== News Filter ==="
input bool     InpUseNewsFilter   = true;      // Use News Filter
input int      InpStopBeforeNews  = 30;        // Stop Minutes Before News
input int      InpResumeAfterNews = 15;        // Resume Minutes After News

//--- Sizing Mode
input group "=== Sizing Mode ==="
input ENUM_SIZING_MODE InpSizingMode = SIZING_MODE_ADAPTIVE; // Lot Sizing Mode
input double   InpDDReductionStart = 5.0;      // DD% to Start Size Reduction
input double   InpDDReductionFull  = 15.0;     // DD% for Full Reduction

//--- Alerts
input group "=== Alerts ==="
input bool     InpEnableAlerts    = true;      // Enable Alerts
input bool     InpUsePushNotify   = false;     // Use Push Notifications

//--- Debug
input group "=== Debug ==="
input ENUM_LOG_LEVEL InpLogLevel = LOG_LEVEL_INFO; // Log Level
input bool     InpEnableFileLog   = false;     // Enable File Logging

//--- Recovery Settings (Phase 6)
input group "=== Recovery Settings (Phase 6) ==="
input bool     InpUseDeEscalation   = true;    // Enable De-escalation
input double   InpRecoveryLotSize   = 0.01;    // Recovery Scalp Lot
input int      InpRecoveryTP        = 50;      // Recovery TP (points)
input int      InpScalpCooldown     = 60;      // Seconds between scalps

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
// Core components
CGridEngine        g_GridEngine;
CPositionManager   g_PositionManager;
CTradeExecutor     g_TradeExecutor;
CHedgeManager      g_HedgeManager;

// Protection components
CRiskManager       g_RiskManager;
CDrawdownMonitor   g_DrawdownMonitor;
CEmergencyStop     g_EmergencyStop;
CHardStop          g_HardStop;
CDailyLossLimit    g_DailyLimit;

// Analysis components
CMarketState       g_MarketState;
CATRCalculator     g_ATRCalculator;
CSessionFilter     g_SessionFilter;
CNewsFilter        g_NewsFilter;
CTrendFilter       g_TrendFilter;

// Recovery & Metrics
CAdaptiveSizing       g_AdaptiveSizing;
CDeEscalationEngine   g_DeEscalationEngine;  // Phase 6
CPerformanceTracker   g_PerformanceTracker;
CEquityCurve          g_EquityCurve;
CAlertManager         g_AlertManager;

// State tracking
SSystemState       g_SystemState;
SProtectionState   g_ProtectionState;

// Symbol info
// Symbol info
string             g_Symbol;
bool               g_IsInitialized = false;
datetime           g_LastGridTradeTime = 0;
datetime           g_LastWeekStart = 0; // Track week start for auto-reset
string             g_BlockingReason = "None"; // UI feedback for why trading is blocked

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   g_Symbol = _Symbol;
   
   //--- Initialize Logger
   Logger.SetLevel(InpLogLevel);
   Logger.SetPrefix("GridEA");
   Logger.EnableFileLogging(InpEnableFileLog);
   Logger.Info("=== Grid Survival Protocol EA Starting ===");
   
   //--- Initialize Core Components
   if(!InitializeCoreComponents())
   {
      Logger.Error("Failed to initialize core components");
      return INIT_FAILED;
   }
   
   //--- Initialize Protection Components
   if(!InitializeProtectionComponents())
   {
      Logger.Error("Failed to initialize protection components");
      return INIT_FAILED;
   }
   
   //--- Initialize Analysis Components
   if(!InitializeAnalysisComponents())
   {
      Logger.Error("Failed to initialize analysis components");
      return INIT_FAILED;
   }
   
   //--- Initialize Metrics Components
   if(!InitializeMetricsComponents())
   {
      Logger.Error("Failed to initialize metrics components");
      return INIT_FAILED;
   }
   
   //--- Initialize System State
   g_SystemState.Init();
   g_ProtectionState.Init(InpEmergencyStopDD, InpHardStopDD, InpDailyLossLimit);
   
   //--- Initialize De-escalation Engine (Phase 6)
   g_DeEscalationEngine.Init(g_Symbol, InpMagicNumber, InpRecoveryLotSize, InpRecoveryTP, InpScalpCooldown);
   
   g_IsInitialized = true;
   Logger.Info("=== EA Initialized Successfully [Version: PENDING_ORDERS_V1] ===");
   Logger.Info(StringFormat("Symbol: %s | Magic: %d | BaseLot: %.2f | GridLevels: %d | TP/SL: %d/%d",
                            g_Symbol, InpMagicNumber, InpBaseLotSize, InpMaxGridLevels, InpTakeProfit, InpStopLoss));
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Logger.Info(StringFormat("EA Deinitializing: Reason=%d", reason));
   
   // Cleanup components
   g_GridEngine.Deinit();
   g_MarketState.Deinit();
   g_ATRCalculator.Deinit();
   
   // Log final performance
   if(g_PerformanceTracker.IsInitialized())
   {
      Logger.Info(g_PerformanceTracker.GetDetailedReport());
   }
   
   // Clean up UI objects (Phase 5: DDGuard)
   ObjectDelete(0, "DDGuardLabel");
   Comment(""); // Clear comment
   
   Logger.Info("=== EA Shutdown Complete ===");
}



//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!g_IsInitialized)
      return;
   
   //--- Weekly Auto-Reset Check
   CheckWeeklyReset();
   
   //--- Update components
   UpdateAllComponents();
   
   //--- Check protection layers (in priority order)
   if(!CheckProtectionLayers())
   {
      // Protection triggered - check if De-escalation should run
      if(g_SystemState.eaState == EA_STATE_LOCKED && InpUseDeEscalation)
      {
         g_SystemState.eaState = EA_STATE_DE_ESCALATING;
         g_DeEscalationEngine.Process(g_SystemState);
      }
      DisplayStatus();
      return;
   }
   
   //--- Check if trading is allowed
   if(!IsTradingAllowed())
   {
      DisplayStatus();
      return;
   }
   
   //--- Main trading logic
   ProcessTradingLogic();
   
   //--- Update display
   DisplayStatus();
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Placeholder for timer-based operations
}

//+------------------------------------------------------------------+
//| Trade transaction function                                       |
//+------------------------------------------------------------------+
// Trade transaction function removed (duplicate)

//+------------------------------------------------------------------+
//| Initialize Core Components                                       |
//+------------------------------------------------------------------+
bool InitializeCoreComponents()
{
   // Grid Engine
   if(!g_GridEngine.Init(g_Symbol, InpATRTimeframe, InpATRPeriod, 
                         InpATRMultiplier, InpMaxGridLevels,
                         InpUseDynamicSpacing, InpFixedSpacing, InpMinDynamicSpacing, InpMaxDynamicSpacing))
   {
      Logger.Error("Failed to initialize GridEngine");
      return false;
   }
   
   // Position Manager
   if(!g_PositionManager.Init(g_Symbol, InpMagicNumber))
   {
      Logger.Error("Failed to initialize PositionManager");
      return false;
   }
   
   // Trade Executor
   if(!g_TradeExecutor.Init(g_Symbol, InpMagicNumber, 5, 3))  // 5 slippage, 3 retries
   {
      Logger.Error("Failed to initialize TradeExecutor");
      return false;
   }
   
   // Hedge Manager
   if(!g_HedgeManager.Init(g_Symbol, InpMagicNumber))
   {
      Logger.Error("Failed to initialize HedgeManager");
      return false;
   }
   
   // Adaptive Sizing
   if(!g_AdaptiveSizing.Init(InpSizingMode, InpBaseLotSize, InpRiskPerTrade))
   {
      Logger.Error("Failed to initialize AdaptiveSizing");
      return false;
   }
   g_AdaptiveSizing.SetReductionThresholds(InpDDReductionStart, InpDDReductionFull);
   
   return true;
}

//+------------------------------------------------------------------+
//| Initialize Protection Components                                 |
//+------------------------------------------------------------------+
bool InitializeProtectionComponents()
{
   // Risk Manager
   if(!g_RiskManager.Init(g_Symbol, InpRiskPerTrade, InpMaxTotalRisk))
   {
      Logger.Error("Failed to initialize RiskManager");
      return false;
   }
   g_RiskManager.SetMaxSpread(InpMaxSpread);  // Set max spread from input
   
   // Drawdown Monitor
   if(!g_DrawdownMonitor.Init())
   {
      Logger.Error("Failed to initialize DrawdownMonitor");
      return false;
   }
   
   // Emergency Stop (Level 1)
   if(!g_EmergencyStop.Init(InpEmergencyStopDD))
   {
      Logger.Error("Failed to initialize EmergencyStop");
      return false;
   }
   
   // Hard Stop (Level 2)
   if(!g_HardStop.Init(InpHardStopDD))
   {
      Logger.Error("Failed to initialize HardStop");
      return false;
   }
   
   // Daily Loss Limit
   if(!g_DailyLimit.Init(InpDailyLossLimit))
   {
      Logger.Error("Failed to initialize DailyLossLimit");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Initialize Analysis Components                                   |
//+------------------------------------------------------------------+
bool InitializeAnalysisComponents()
{
   // Market State (ADX-based)
   if(!g_MarketState.Init(g_Symbol, InpATRTimeframe))
   {
      Logger.Error("Failed to initialize MarketState");
      return false;
   }
   
   // ATR Calculator
   if(!g_ATRCalculator.Init(g_Symbol, InpATRTimeframe, InpATRPeriod, InpATRMultiplier))
   {
      Logger.Error("Failed to initialize ATRCalculator");
      return false;
   }
   
   // Session Filter
   if(!g_SessionFilter.Init(InpSessionStart, InpSessionEnd, InpUseSessionFilter))
   {
      Logger.Error("Failed to initialize SessionFilter");
      return false;
   }
   g_SessionFilter.SetFridaySettings(InpAvoidFriday, InpFridayCutoff);
   
   // News Filter
   if(!g_NewsFilter.Init(g_Symbol, InpStopBeforeNews, InpResumeAfterNews, InpUseNewsFilter))
   {
      Logger.Error("Failed to initialize NewsFilter");
      return false;
   }
   
   // Trend Filter (Feature A)
   if(!g_TrendFilter.Init(g_Symbol, InpATRTimeframe, 14, InpTrendADXThreshold))
   {
      Logger.Error("Failed to initialize TrendFilter");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Initialize Metrics Components                                    |
//+------------------------------------------------------------------+
bool InitializeMetricsComponents()
{
   // Performance Tracker
   if(!g_PerformanceTracker.Init())
   {
      Logger.Error("Failed to initialize PerformanceTracker");
      return false;
   }
   
   // Equity Curve
   if(!g_EquityCurve.Init(1440, 60))  // 24 hours at 1-minute intervals
   {
      Logger.Error("Failed to initialize EquityCurve");
      return false;
   }
   
   // Alert Manager
   if(!g_AlertManager.Init(InpEnableAlerts, "[GridEA]"))
   {
      Logger.Error("Failed to initialize AlertManager");
      return false;
   }
   g_AlertManager.Configure(true, InpUsePushNotify, false, false);
   
   return true;
}

//+------------------------------------------------------------------+
//| Update All Components                                            |
//+------------------------------------------------------------------+
void UpdateAllComponents()
{
   // Update equity tracking
   g_DrawdownMonitor.Update();
   g_RiskManager.UpdateEquity();
   g_EquityCurve.Update();
   
   // Update daily limit tracking
   g_DailyLimit.Update();
   
   // Update position tracking
   g_PositionManager.Update();
   
   // Update adaptive sizing based on current DD
   g_AdaptiveSizing.UpdateMultiplier(g_DrawdownMonitor.GetCurrentDrawdown());
}

//+------------------------------------------------------------------+
//| Check Protection Layers                                          |
//+------------------------------------------------------------------+
bool CheckProtectionLayers()
{
   double currentDD = g_DrawdownMonitor.GetCurrentDrawdown();
   
   //--- Layer 2: Hard Stop (highest priority)
   if(g_HardStop.Check(currentDD))
   {
      if(!g_HardStop.IsLocked())
      {
         // First trigger - close all positions
         g_AlertManager.Critical("HARD STOP TRIGGERED - Closing all positions!");
         CloseAllPositions();
      }
      g_SystemState.eaState = EA_STATE_EMERGENCY;
      return false;
   }
   
   //--- Daily Loss Limit
   if(g_DailyLimit.Check())
   {
      // ... (existing logic)
      if(g_SystemState.eaState != EA_STATE_PAUSED)
      {
         g_AlertManager.Warning("Daily loss limit reached - Trading paused");
         g_SystemState.eaState = EA_STATE_PAUSED;
      }
      return false;
   }
   else if(g_SystemState.eaState == EA_STATE_PAUSED)
   {
      // ... (existing logic)
      if(!g_HardStop.IsLocked() && !g_EmergencyStop.IsTriggered())
      {
         Logger.Info("Daily loss limit reset - Resuming trading operations");
         g_SystemState.eaState = EA_STATE_IDLE;
      }
   }

   //--- Layer 1.5: Hedge Soft Lock (Phase 5)
   // If Hedge is enabled and Triggered, this will Lock the system
   if(InpUseHedge && g_HedgeManager.CheckAndExecuteLock(currentDD, InpEmergencyStopDD, g_SystemState))
   {
       return false; // Stop further processing if Locked
   }
   
   //--- Layer 1: Emergency Stop
   ENUM_EMERGENCY_ACTION action = g_EmergencyStop.Check(currentDD);
   if(action == EMERGENCY_ACTION_STOP_NEW)
   {
      g_AlertManager.Warning("Emergency stop - No new trades");
      g_SystemState.tradingMode = TRADING_MODE_CLOSE_ONLY;
      // Can still manage existing positions
   }
   else if(action == EMERGENCY_ACTION_REDUCE_SIZE)
   {
      g_SystemState.tradingMode = TRADING_MODE_REDUCED;
   }
   else
   {
      g_SystemState.tradingMode = TRADING_MODE_NORMAL;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check if Trading is Allowed                                      |
//+------------------------------------------------------------------+
bool IsTradingAllowed()
{
   g_BlockingReason = "None"; // Reset reason

   // Check EA state
   if(g_SystemState.eaState != EA_STATE_TRADING && 
      g_SystemState.eaState != EA_STATE_IDLE)
   {
      g_BlockingReason = "State: " + EnumToString(g_SystemState.eaState);
      Logger.Debug(StringFormat("IsTradingAllowed: Blocked by EA state: %s", EnumToString(g_SystemState.eaState)));
      return false;
   }
   
   // Check session filter (only if enabled)
   if(InpUseSessionFilter && !g_SessionFilter.IsTradingAllowed())
   {
      g_SystemState.sessionState = g_SessionFilter.GetState();
      g_BlockingReason = "Session: " + EnumToString(g_SystemState.sessionState);
      Logger.Debug(StringFormat("IsTradingAllowed: Blocked by Session Filter: %s", EnumToString(g_SystemState.sessionState)));
      return false;
   }
   g_SystemState.sessionState = SESSION_STATE_OPEN;
   
   // Check news filter (only if enabled)
   if(InpUseNewsFilter && !g_NewsFilter.IsTradingAllowed())
   {
      g_SystemState.sessionState = SESSION_STATE_NEWS_PAUSE;
      g_BlockingReason = "News Event";
      Logger.Debug("IsTradingAllowed: Blocked by News Filter");
      return false;
   }
   
   // Check spread
   if(!g_RiskManager.IsSpreadAcceptable())
   {
      g_BlockingReason = StringFormat("Spread Too High (Max: %.0f)", InpMaxSpread);
      Logger.Debug("IsTradingAllowed: Blocked by Spread check");
      return false;
   }
   
   // Check trend filter (Feature A)
   if(InpUseTrendFilter && g_TrendFilter.IsTrendTooStrong())
   {
      // Only block NEW grids, allow managing existing ones? 
      // For now, block grid entry.
      SPositionSummary summary = g_PositionManager.GetSummary();
      if(summary.totalPositions == 0) // Only block if we are starting a new grid
      {
         g_BlockingReason = StringFormat("Strong Trend (ADX > %d)", InpTrendADXThreshold);
         Logger.Debug(StringFormat("IsTradingAllowed: Blocked by Strong Trend (ADX > %d)", InpTrendADXThreshold));
         return false;
      }
   }
   
   // Check market conditions (optional - grid can work in trends too)
   g_MarketState.Update();
   g_SystemState.marketCondition = g_MarketState.GetCondition();
   
   return true;
}

//+------------------------------------------------------------------+
//| Process Main Trading Logic                                       |
//+------------------------------------------------------------------+
void ProcessTradingLogic()
{
   //--- Update grid engine
   double currentBid = SymbolInfoDouble(g_Symbol, SYMBOL_BID);
   g_GridEngine.Update(currentBid);
   
   //--- Get current lot size (adjusted for risk/DD)
   double lotSize = g_AdaptiveSizing.GetAdjustedLotSize(g_Symbol);
   
   // Get position summary
   SPositionSummary summary = g_PositionManager.GetSummary();
   int pendingOrders = g_GridEngine.GetTotalPendingOrders();
   
   //--- ถ้ายังไม่มี position เลย ให้เปิด First Order และวาง Pending Orders
   if(summary.totalPositions == 0)
   {
      if(OpenFirstGridOrder(lotSize))
      {
         // After first order, place pending orders immediately
         PlaceGridPendingOrders(lotSize);
      }
      return;
   }
   
   //--- ถ้ามี positions แต่ pending หายไป (เช่น โดน cancel หรือ expire) ให้เติม
   if(summary.totalPositions > 0 && pendingOrders < (InpMaxGridLevels - summary.totalPositions))
   {
      // Refill pending orders corresponding to empty levels
      PlaceGridPendingOrders(lotSize);
   }
   
   //--- Check for profit target (simple TP logic)
   CheckProfitTarget(summary);
   
   // Update system state
   if(summary.totalPositions > 0)
      g_SystemState.eaState = EA_STATE_TRADING;
   else
      g_SystemState.eaState = EA_STATE_IDLE;
}

//+------------------------------------------------------------------+
//| Open First Grid Order                                            |
//+------------------------------------------------------------------+
bool OpenFirstGridOrder(double lotSize)
{
   Logger.Info("Opening first grid order...");
   
   // Set base price at current price
   double currentBid = SymbolInfoDouble(g_Symbol, SYMBOL_BID);
   double currentAsk = SymbolInfoDouble(g_Symbol, SYMBOL_ASK);
   g_GridEngine.SetBasePrice(currentBid);
   
   // Generate grid levels (Both sides are prepared, usage depends on InpTradeDirection)
   g_GridEngine.GenerateBuyGridLevels(lotSize);
   g_GridEngine.GenerateSellGridLevels(lotSize);
   
   double point = SymbolInfoDouble(g_Symbol, SYMBOL_POINT);
   bool buyOpened  = false;
   bool sellOpened = false;
   
   //--- LONG (Buy First Order)
   if(InpTradeDirection == DIRECTION_LONG_ONLY || InpTradeDirection == DIRECTION_BOTH)
   {
      double sl_buy = (InpStopLoss > 0) ? currentBid - (InpStopLoss * point) : 0;
      double tp_buy = (InpTakeProfit > 0) ? currentBid + (InpTakeProfit * point) : 0;
      
      if(g_TradeExecutor.OpenBuy(lotSize, sl_buy, tp_buy, "Grid_L0_BUY"))
      {
         g_GridEngine.UpdateBuyLevelStatus(0, GRID_LEVEL_ACTIVE);
         Logger.Info(StringFormat("First BUY order opened: Lot=%.2f", lotSize));
         buyOpened = true;
      }
      else
      {
         Logger.Error("Failed to open first BUY order");
      }
   }
   
   //--- SHORT (Sell First Order)
   if(InpTradeDirection == DIRECTION_SHORT_ONLY || InpTradeDirection == DIRECTION_BOTH)
   {
      double sl_sell = (InpStopLoss > 0) ? currentAsk + (InpStopLoss * point) : 0;
      double tp_sell = (InpTakeProfit > 0) ? currentAsk - (InpTakeProfit * point) : 0;
      
      if(g_TradeExecutor.OpenSell(lotSize, sl_sell, tp_sell, "Grid_L0_SELL"))
      {
         g_GridEngine.UpdateSellLevelStatus(0, GRID_LEVEL_ACTIVE);
         Logger.Info(StringFormat("First SELL order opened: Lot=%.2f", lotSize));
         sellOpened = true;
      }
      else
      {
         Logger.Error("Failed to open first SELL order");
      }
   }
   
   if(buyOpened || sellOpened)
   {
      g_LastGridTradeTime = TimeCurrent();
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Place Pending Orders for Grid                                    |
//+------------------------------------------------------------------+
void PlaceGridPendingOrders(double lotSize)
{
   double point = SymbolInfoDouble(g_Symbol, SYMBOL_POINT);
   
   // Ensure base price is set (Fix for refill scenario)
   if(g_GridEngine.GetBasePrice() == 0)
   {
      double currentBid = SymbolInfoDouble(g_Symbol, SYMBOL_BID);
      g_GridEngine.SetBasePrice(currentBid);
      g_GridEngine.GenerateBuyGridLevels(lotSize);
      g_GridEngine.GenerateSellGridLevels(lotSize);
      Logger.Info(StringFormat("PlaceGridPendingOrders: BasePrice was 0, reset to %.5f", currentBid));
   }
   
   // Validate grid spacing
   if(g_GridEngine.GetGridSpacing() == 0)
   {
      Logger.Warning("Grid spacing is 0. Cannot place pending orders.");
      return;
   }
   
   // Loop through all levels starting from 1 (Level 0 is market order)
   for(int i = 1; i < InpMaxGridLevels; i++)
   {
      //--- BUY Grid (If Long or Both)
      if(InpTradeDirection == DIRECTION_LONG_ONLY || InpTradeDirection == DIRECTION_BOTH)
      {
         SGridLevel buyLevel = g_GridEngine.GetBuyLevel(i);
         if(buyLevel.status == GRID_LEVEL_EMPTY)
         {
            double entryPrice = g_GridEngine.CalculateLevelPrice(i, GRID_DIRECTION_BUY);
            
            // Validate entry price
            if(entryPrice <= 0)
            {
               Logger.Warning(StringFormat("Invalid entry price for Buy L%d: %.5f (skipping)", i, entryPrice));
               continue;
            }
            
            double sl = (InpStopLoss > 0) ? entryPrice - (InpStopLoss * point) : 0;
            double tp = (InpTakeProfit > 0) ? entryPrice + (InpTakeProfit * point) : 0;
            
            // Validate SL/TP
            if(sl < 0) sl = 0;
            if(tp < 0) tp = 0;
            
            double adjustedLot = lotSize * MathPow(InpGridMultiplier, i);
            adjustedLot = NormalizeLot(g_Symbol, adjustedLot);
            
            string comment = StringFormat("Grid_L%d_BUY", i);
            STradeResult result = g_TradeExecutor.BuyLimit(adjustedLot, entryPrice, sl, tp, 0, comment);
            
            if(result.success)
            {
               g_GridEngine.UpdateBuyLevelStatus(i, GRID_LEVEL_PENDING, result.ticket);
               Logger.Info(StringFormat("Placed Buy Limit L%d at %.5f", i, entryPrice));
            }
         }
      }
      
      //--- SELL Grid (If Short or Both)
      if(InpTradeDirection == DIRECTION_SHORT_ONLY || InpTradeDirection == DIRECTION_BOTH)
      {
         SGridLevel sellLevel = g_GridEngine.GetSellLevel(i);
         if(sellLevel.status == GRID_LEVEL_EMPTY)
         {
            double entryPrice = g_GridEngine.CalculateLevelPrice(i, GRID_DIRECTION_SELL);
            
            // Validate entry price
            if(entryPrice <= 0)
            {
               Logger.Warning(StringFormat("Invalid entry price for Sell L%d: %.5f (skipping)", i, entryPrice));
               continue;
            }
            
            double sl = (InpStopLoss > 0) ? entryPrice + (InpStopLoss * point) : 0;
            double tp = (InpTakeProfit > 0) ? entryPrice - (InpTakeProfit * point) : 0;
            
            // Validate SL/TP
            if(sl < 0) sl = 0;
            if(tp < 0) tp = 0;
            
            double adjustedLot = lotSize * MathPow(InpGridMultiplier, i);
            adjustedLot = NormalizeLot(g_Symbol, adjustedLot);
            
            string comment = StringFormat("Grid_L%d_SELL", i);
            STradeResult result = g_TradeExecutor.SellLimit(adjustedLot, entryPrice, sl, tp, 0, comment);
            
            if(result.success)
            {
               g_GridEngine.UpdateSellLevelStatus(i, GRID_LEVEL_PENDING, result.ticket);
               Logger.Info(StringFormat("Placed Sell Limit L%d at %.5f", i, entryPrice));
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check Profit Target - Close All When in Profit                   |
//+------------------------------------------------------------------+
void CheckProfitTarget(SPositionSummary &summary)
{
   // Simple TP: Close all when total profit > certain threshold
   // ใช้ profit เป็น % ของ equity
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double profitPercent = (summary.totalProfit / equity) * 100.0;
   
   // TP เมื่อกำไร > 0.5% ของ equity (ปรับได้ตามต้องการ)
   double tpPercent = 0.5;
   
   // Debug Log (Print every 1 minute to avoid spam)
   static datetime lastDebug = 0;
   if(TimeCurrent() - lastDebug > 60 && summary.totalPositions > 0)
   {
      Logger.Debug(StringFormat("Profit Check: Equity=%.2f, Profit=%.2f (%.2f%%), Target=%.2f%%", 
                                equity, summary.totalProfit, profitPercent, tpPercent));
      lastDebug = TimeCurrent();
   }
   
   if(profitPercent >= tpPercent && summary.totalPositions > 0)
   {
      Logger.Info(StringFormat("PROFIT TARGET REACHED: Profit=%.2f (%.2f%%) >= Target (%.2f%%) - Closing All", 
                               summary.totalProfit, profitPercent, tpPercent));
      CloseAllPositions();
      
      // Reset grid after close
      g_GridEngine.ResetAllGrids();
      
      // Reset throttling
      g_LastGridTradeTime = 0;
   }
}

//+------------------------------------------------------------------+
//| Trade Transaction Event                                          |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Trade Transaction Event                                          |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      ulong order = trans.order;
      ulong deal  = trans.deal;
      
      if(HistoryDealSelect(deal))
      {
         string symbol = HistoryDealGetString(deal, DEAL_SYMBOL);
         long magic = HistoryDealGetInteger(deal, DEAL_MAGIC);
         
         // Verify Symbol and Magic Number
         if(symbol == g_Symbol && magic == InpMagicNumber)
         {
            long entryType = HistoryDealGetInteger(deal, DEAL_ENTRY);
            
            // 1. Handle Closed Trades (OUT / OUT_BY) -> Update Performance
            if(entryType == DEAL_ENTRY_OUT || entryType == DEAL_ENTRY_OUT_BY)
            {
               double profit = HistoryDealGetDouble(deal, DEAL_PROFIT);
               double swap = HistoryDealGetDouble(deal, DEAL_SWAP);
               double comm = HistoryDealGetDouble(deal, DEAL_COMMISSION);
               double totalResult = profit + swap + comm;
               
               g_PerformanceTracker.RecordTrade(totalResult);
               Logger.Debug(StringFormat("Trade Closed: Ticket=%d, Result=%.2f", deal, totalResult));
            }
            
            // 2. Handle New Trades (IN) -> Update Grid Status
            // Check comment for "Grid_L" pattern
            string comment = HistoryDealGetString(deal, DEAL_COMMENT);
            if(StringFind(comment, "Grid_L") >= 0)
            {
               string parts[];
               StringSplit(comment, '_', parts);
               if(ArraySize(parts) >= 2)
               {
                  string levelPart = parts[1]; // L1
                  int level = (int)StringSubstr(levelPart, 1);
                  
                  if(StringFind(comment, "BUY") >= 0)
                  {
                     g_GridEngine.UpdateBuyLevelStatus(level, GRID_LEVEL_ACTIVE, (ulong)trans.position);
                     Logger.Info(StringFormat("Grid BUY L%d executed (Entry)", level));
                  }
                  else if(StringFind(comment, "SELL") >= 0)
                  {
                     g_GridEngine.UpdateSellLevelStatus(level, GRID_LEVEL_ACTIVE, (ulong)trans.position);
                     Logger.Info(StringFormat("Grid SELL L%d executed (Entry)", level));
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Close All Positions and Pending Orders                           |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   Logger.Warning("Closing all positions and pending orders...");
   
   // 1. Close Open Positions
   ulong tickets[];
   g_PositionManager.GetPositionTickets(tickets);
   
   for(int i = 0; i < ArraySize(tickets); i++)
   {
      g_TradeExecutor.ClosePosition(tickets[i]);
   }
   
   // 2. Delete Pending Orders
   DeleteAllPendingOrders();
   
   Logger.Info("All positions closed and pending orders deleted");
}

//+------------------------------------------------------------------+
//| Delete All Pending Orders                                        |
//+------------------------------------------------------------------+
void DeleteAllPendingOrders()
{
   // Loop through orders and delete those belonging to this EA (magic number)
   int total = OrdersTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0)
      {
         if(OrderGetInteger(ORDER_MAGIC) == InpMagicNumber &&
            OrderGetString(ORDER_SYMBOL) == g_Symbol)
         {
            g_TradeExecutor.DeleteOrder(ticket);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Display Status on Chart                                          |
//+------------------------------------------------------------------+
void DisplayStatus()
{
   string status = "";
   
   //--- Header
   status += "═══════════ GRID SURVIVAL PROTOCOL ═══════════\n";
   
   //--- State
   status += StringFormat("State: %s | Mode: %s\n", 
                          EnumToString(g_SystemState.eaState),
                          EnumToString(g_SystemState.tradingMode));
   
   //--- Equity & Drawdown
   status += StringFormat("Equity: %.2f | DD: %.2f%% | Daily: %.2f%%\n",
                          AccountInfoDouble(ACCOUNT_EQUITY),
                          g_DrawdownMonitor.GetCurrentDrawdown(),
                          g_DailyLimit.GetDailyPLPercent());
   
   //--- Positions
   SPositionSummary summary = g_PositionManager.GetSummary();
   status += StringFormat("Positions: %d/%d | Profit: %.2f\n",
                          summary.totalPositions, InpMaxGridLevels,
                          summary.totalProfit);
   
   //--- Protection Status
   status += StringFormat("Protection: Emergency=%s | Hard=%s | Daily=%s\n",
                          g_EmergencyStop.GetStatus(),
                          g_HardStop.IsLocked() ? "LOCKED" : "OK",
                          g_DailyLimit.IsTriggered() ? "LIMIT" : "OK");
   
   //--- Session/News
   status += StringFormat("Session: %s | News: %s\n",
                          g_SessionFilter.GetStateString(),
                          g_NewsFilter.IsNewsTime() ? "PAUSE" : "OK"); 
                          
   //--- Trend & Features (New)
   string trendInfo = "OFF";
   if(InpUseTrendFilter)
      trendInfo = StringFormat("ADX:%.1f (%s)", g_TrendFilter.GetCurrentADX(), g_TrendFilter.IsTrendTooStrong() ? "STRONG" : "WEAK");
      
   status += StringFormat("Trend: %s | Week Start: %s\n", trendInfo, g_LastWeekStart > 0 ? TimeToString(g_LastWeekStart, TIME_DATE) : "-");
   
   //--- Blocking Reason
   if(g_SystemState.eaState == EA_STATE_IDLE && g_BlockingReason != "None")
   {
      status += StringFormat("⚠ BLOCKED: %s\n", g_BlockingReason);
   }
   
   //--- Sizing
   status += StringFormat("Lot Size: %.2f (%.0f%% of base)\n",
                          g_AdaptiveSizing.GetAdjustedLotSize(g_Symbol),
                          g_AdaptiveSizing.GetMultiplier() * 100);
   
   //--- Performance
   status += StringFormat("Performance: WR=%.1f%% | PF=%.2f | Trades=%d\n",
                          g_PerformanceTracker.GetWinRate(),
                          g_PerformanceTracker.GetProfitFactor(),
                          g_PerformanceTracker.GetTotalTrades());

   //--- Blocking Status (Feedback line)
   if(g_BlockingReason != "None" && g_BlockingReason != "")
   {
      status += "⚠️ BLOCKED BY: " + g_BlockingReason + "\n";
   }
   
   status += "═══════════════════════════════════════════════";
   
   Comment(status);
   
   //--- Specific UI for DDGuard (Yellow Label as requested)
   string lblName = "DDGuardLabel";
   if(ObjectFind(0, lblName) < 0)
   {
      ObjectCreate(0, lblName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, lblName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, lblName, OBJPROP_XDISTANCE, 15);
      ObjectSetInteger(0, lblName, OBJPROP_YDISTANCE, 320); // Position below Comment block
      ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, lblName, OBJPROP_FONT, "Arial Bold");
   }
   
   string ddText = "DDGuard: OFF";
   color ddColor = clrGray;
   
   if(InpUseHedge)
   {
      if(g_HedgeManager.IsLocked())
      {
         ddText = "⚠️ DDGuard: LOCKED (Net Zero) ⚠️";
         ddColor = clrRed; // Critical state
      }
      else
      {
         ddText = "🛡️ DDGuard: ARMED (Ready)";
         ddColor = clrYellow; // Active but waiting
      }
   }
   
   ObjectSetString(0, lblName, OBJPROP_TEXT, ddText);
   ObjectSetInteger(0, lblName, OBJPROP_COLOR, ddColor);
}

//+------------------------------------------------------------------+
//| Check and Perform Weekly Auto-Reset                              |
//+------------------------------------------------------------------+
void CheckWeeklyReset()
{
   if(!InpUseWeeklyReset) return;
   
   datetime currentTime = TimeCurrent();
   
   // Calculate Start of Current Week (Sunday 00:00)
   // TimeDayOfWeek: 0=Sun, 1=Mon, ... 6=Sat
   MqlDateTime dt;
   TimeToStruct(currentTime, dt);
   
   // Calculate seconds elapsed since Sunday 00:00
   int secondsSinceWeekStart = (dt.day_of_week * 86400) + (dt.hour * 3600) + (dt.min * 60) + dt.sec;
   datetime currentWeekStart = currentTime - secondsSinceWeekStart;
   
   // Initialization
   if(g_LastWeekStart == 0)
   {
      g_LastWeekStart = currentWeekStart;
      return;
   }
   
   // Detect new week (Current week start is newer than stored)
   if(currentWeekStart > g_LastWeekStart)
   {
      Logger.Info(StringFormat("NEW WEEK DETECTED (Start: %s) - Performing Weekly Auto-Reset...", 
                               TimeToString(currentWeekStart)));
      
      // 1. Force Close All Positions (Start Fresh)
      if(g_PositionManager.GetSummary().totalPositions > 0)
      {
         Logger.Info("Weekly Reset: Closing all existing positions...");
         CloseAllPositions();
      }
      DeleteAllPendingOrders();
      
      // 2. Reset All Protection Layers
      g_HardStop.ManualReset(true);
      g_EmergencyStop.ResetDaily(); // Use ResetDaily to clear counters too
      g_DailyLimit.ResetDaily();
      
      // 3. Reset Drawdown History
      g_DrawdownMonitor.ResetHighWaterMark();
      g_DrawdownMonitor.ForceDailyReset();
      
      // 4. Reset Grid & EA State
      g_GridEngine.ResetAllGrids();
      g_SystemState.eaState = EA_STATE_IDLE;
      g_SystemState.tradingMode = TRADING_MODE_NORMAL;
      
      // Update week tracker
      g_LastWeekStart = currentWeekStart;
      
      Logger.Info("WEEKLY AUTO-RESET COMPLETED - SYSTEM RESTARTED");
   }
}
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
