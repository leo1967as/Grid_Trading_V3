# Grid Survival Protocol EA (V3)

> **"Survival First, Profit Second."**

This EA is designed for **Grid Trading Survival**. It prioritizes account protection over aggressive profit, using multiple layers of defense to handle market crashes, strong trends, and liquidity crises.

---

## 🚀 Key Features (V3 Implemented)

### 🛡️ Layer 1: Prevention (Trend Filter)

**"Don't catch a falling knife."**

- **Logic:** Checks ADX (Trend Strength) before starting a new grid cycle.
- **Action:** If ADX > Threshold (default 30), it **BLOCKS** new buy orders to prevent entering strong downtrends.
- **Toggle:** `InpUseTrendFilter = true`

### 🛡️ Layer 2: Adaptation (Dynamic Spacing)

**"Stretch the net when the fish are big."**

- **Logic:** Adjusts grid distance based on Volatility (ATR).
- **Action:**
  - **Low Volatility:** Tighter grid (collect small profits).
  - **High Volatility:** Wider grid (survive large moves).
- **Settings:** `InpUseDynamicSpacing = true` (uses ATR * Multiplier, clamped between Min/Max).

### 🛡️ Layer 3: Soft Lock (Hedge Guard)

**"Freeze the fire before it spreads."**

- **Trigger:** When Drawdown ≥ **Emergency Limit** (default 10%).
- **Action:** Opens an opposite **Hedge Order** to make Net Exposure = 0.
- **Result:** PnL is "Frozen". The EA stops trading and waits for manual intervention or De-escalation (Phase 6).
- **Toggle:** `InpUseHedge = true` (Default Off, advanced users only).

### 🛡️ Layer 4: Hard Stop (Circuit Breaker)

**"Cut the limb to save the body."**

- **Trigger:** When Drawdown ≥ **Hard Limit** (default 20%).
- **Action:** **CLOSE ALL POSITIONS** immediately.
- **Result:** Accepts loss to prevent margin call or total wipeout.

### 🔄 Weekly Auto-Reset

- **Trigger:** Every Sunday/Monday (New Week detection).
- **Action:** Closes all trades and resets all protection counters.
- **Goal:** Start every week fresh, preventing "bad trades" from dragging on forever.

---

## ⚙️ Quick Start

1. **Install:** Copy `Experts/ST_GridSurvival_V3.mq5` and `Include/` to your MT5 Data Folder.
2. **Compile:** Open MetaEditor and compile `GridSurvivalEA.mq5`.
3. **Configure:**
    - **Symbol:** Any (XAUUSD, EURUSD recommended).
    - **Timeframe:** M15 or H1 (Higher is safer).
    - **Inputs:** Load `Presets/Conservative.set` for a safe start.

4. **Verify:** Check the "Smile" icon and "Algo Trading" is ON.

---

## 📂 Project Structure

```
Grid_V3/
├── Experts/
│   └── GridSurvivalEA.mq5          # Main EA
├── Include/
│   ├── Analysis/                   # Trend, ATR, Filters
│   │   ├── CTrendFilter.mqh        # Feature A
│   ├── Core/
│   │   ├── GridEngine.mqh          # Feature C (Dynamic)
│   │   ├── HedgeManager.mqh        # Feature D (Soft Lock)
│   ├── Protection/                 # HardStop, EmergencyStop
│   ├── Recovery/                   # Adaptive Sizing
│   └── Models/                     # State Enums
└── Docs/
    ├── GAP_ANALYSIS_AND_PLAN.md    # Future Roadmap
    └── README.md                   # This file
```

## ⚠️ Risk Warning

**Grid Trading is inherently risky.**

- This EA contains protection mechanisms, but **Market Gaps (Slippage)** can bypass Stop Losses.
- Never trade with money you cannot afford to lose.
- **Soft Lock (Hedge)** requires manual skill to unlock if De-escalation Auto-mode is off.

---
*Version: 3.0 (Trend Protection Update)*
