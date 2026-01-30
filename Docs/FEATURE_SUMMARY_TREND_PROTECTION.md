# Feature Implementation Summary: Trend Protection & Auto-Reset
>
> **Branch:** `feature/trend-protection`
> **Date:** 2026-01-30

## Overview

This update introduces intelligent filtering to avoid trading during extreme trends and a simulation-friendly "Auto-Reset" feature for long-term testing.

---

## 1. Feature A: Trend Filter (Prevention)

**Objective:** Stop the EA from opening *new* grid cycles when the market is trending strongly (to avoid "catching a falling knife").

### Changes Made

- **New Class:** `Include/Analysis/TrendFilter.mqh`
  - Uses **ADX (Average Directional Index)** to measure trend strength.
  - Ignores direction (works for both strong BULL and strong BEAR).
- **Inputs Added:**
  - `input bool InpUseTrendFilter = true;`
  - `input int InpTrendADXThreshold = 30;`
- **Logic Integration:**
  - In `IsTradingAllowed()`: Checks if `ADX > 30` AND `No Open Positions`.
  - Result: If Trend is Strong, **Wait**. If Trend triggers *after* we are already in a grid, we continue management (don't abandon existing trades).

---

## 2. Weekly Auto-Reset (Testing & Simulation)

**Objective:** Allow continuous backtesting/forward testing without stopping permanently when a Hard Stop hits.

### Changes Made

- **Inputs Added:**
  - `input bool InpUseWeeklyReset = true;`
- **Logic:**
  - Detects the start of a **New Week** (Sunday/Monday).
  - Automatically executes a full system reset:
        1. **Close All Positions** (Force Close).
        2. **Delete Pending Orders**.
        3. **Reset Protection** (Unlocks Hard Stop, Resets Daily Limit, Resets Emergency Stop).
        4. **Reset Metrics** (Clears Drawdown History & High Water Mark).
        5. **Resume Trading** (Sets State to `IDLE`).

### Why this is important?

It allows you to simulate "What if I reset the bot every Monday?" over a 1-year period, instead of the backtest ending in January because of one bad day.

---

## Files Modified

1. `Experts/GridSurvivalEA.mq5` (Main Logic & Inputs)
2. `Include/Analysis/TrendFilter.mqh` (New)
