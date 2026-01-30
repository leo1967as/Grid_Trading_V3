# Grid Survival Protocol EA

> **The EA that keeps you in the game when others are wiped out.**

## Philosophy

This EA is built on a simple principle: **Survival First, Profit Second.**

In grid trading, the biggest risk isn't losing trades — it's catastrophic drawdown that wipes out your account. The Grid Survival Protocol implements multiple layers of protection to ensure you live to trade another day.

## Quick Start

1. Copy the `Experts/` folder to your MT5 `MQL5/Experts/` directory
2. Copy the `Include/` folder to your MT5 `MQL5/Include/` directory
3. Compile `GridSurvivalEA.mq5` in MetaEditor
4. Attach to chart and configure parameters

## Key Features

### 🛡️ Multi-Layer Protection System

| Layer | Trigger | Action |
|-------|---------|--------|
| **Emergency Stop** | DD ≥ 10% | Reduce position size, stop new trades |
| **Hard Stop** | DD ≥ 20% | Close ALL positions immediately |
| **Daily Limit** | Daily Loss ≥ 5% | Stop trading until next day |

### 📊 Adaptive Position Sizing

- Automatically reduces lot size as drawdown increases
- Protects capital during losing streaks
- Returns to normal size after recovery

### 🕐 Session & News Filters

- Avoid trading during rollover
- Pause before/after high-impact news
- Configurable trading hours

### 📈 ATR-Based Dynamic Grid

- Grid spacing adapts to market volatility
- Wider grids in volatile markets
- Tighter grids in calm markets

## Project Structure

```
Grid_V3/
├── Experts/
│   └── GridSurvivalEA.mq5          # Main EA file
│
├── Include/
│   ├── Core/                       # Core trading logic
│   │   ├── GridEngine.mqh          # Grid management
│   │   ├── PositionManager.mqh     # Position tracking
│   │   └── TradeExecutor.mqh       # Order execution
│   │
│   ├── Protection/                 # Protection layers
│   │   ├── RiskManager.mqh         # Risk calculation
│   │   ├── DrawdownMonitor.mqh     # DD tracking
│   │   ├── EmergencyStop.mqh       # Level 1 protection
│   │   ├── HardStop.mqh            # Level 2 protection
│   │   └── DailyLossLimit.mqh      # Daily limit
│   │
│   ├── Analysis/                   # Market analysis
│   │   ├── MarketState.mqh         # Trend/range detection
│   │   ├── ATRCalculator.mqh       # Volatility calculation
│   │   ├── SessionFilter.mqh       # Time-based filter
│   │   └── NewsFilter.mqh          # News event filter
│   │
│   ├── Recovery/                   # Recovery strategies
│   │   └── AdaptiveSizing.mqh      # Adaptive lot sizing
│   │
│   ├── Metrics/                    # Performance tracking
│   │   ├── PerformanceTracker.mqh  # Trade statistics
│   │   ├── EquityCurve.mqh         # Equity tracking
│   │   └── AlertManager.mqh        # Notifications
│   │
│   ├── Utils/                      # Utilities
│   │   ├── Common.mqh              # Shared functions
│   │   ├── Logger.mqh              # Logging system
│   │   └── ConfigLoader.mqh        # Settings persistence
│   │
│   └── Models/                     # Data structures
│       ├── GridLevel.mqh           # Grid level data
│       ├── TradeState.mqh          # System states
│       └── ProtectionState.mqh     # Protection states
│
├── Presets/                        # Configuration presets
│   ├── Conservative.set            # Low risk settings
│   ├── Balanced.set                # Medium risk settings
│   └── Aggressive.set              # High risk settings
│
├── Scripts/                        # Testing scripts
│   └── (unit tests)
│
├── Test/                           # Test utilities
│   └── (compilation tests)
│
└── Docs/
    ├── README.md                   # This file
    ├── ARCHITECTURE.md             # Technical architecture
    └── PARAMETERS.md               # Parameter reference
```

## Configuration Presets

### Conservative (Default)

- Emergency Stop: 10%
- Hard Stop: 20%
- Daily Limit: 3%
- Grid Levels: 5
- Lot Multiplier: 1.0 (no martingale)

### Balanced

- Emergency Stop: 12%
- Hard Stop: 25%
- Daily Limit: 5%
- Grid Levels: 8
- Lot Multiplier: 1.0

### Aggressive

- Emergency Stop: 15%
- Hard Stop: 30%
- Daily Limit: 8%
- Grid Levels: 10
- Lot Multiplier: 1.2

## Important Notes

> [!CAUTION]
> Grid trading carries significant risk. Even with protection systems, you can lose money. Never trade with funds you can't afford to lose.

> [!IMPORTANT]
> The Hard Stop is your last line of defense. If it triggers, the EA will close ALL positions immediately and lock until you manually reset. This is intentional.

> [!TIP]
> Start with the Conservative preset and adjust based on your risk tolerance and trading experience.

## Development Phases

### Phase 1 (Current)

- [x] Core trading modules
- [x] Multi-layer protection
- [x] Session/News filters
- [x] Adaptive sizing
- [x] Performance tracking

### Phase 2 (Planned)

- [ ] Advanced recovery strategies
- [ ] Partial position management
- [ ] Hedge mode support

### Phase 3 (Future)

- [ ] Multi-symbol trading
- [ ] Portfolio-level risk management
- [ ] Machine learning optimization

## License

Private use only. Not for redistribution.

---

*Remember: The goal isn't to make the most money — it's to stay in the game long enough to make consistent profits.*
