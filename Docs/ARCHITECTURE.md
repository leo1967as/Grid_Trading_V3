# Architecture Overview

## System Design

The Grid Survival Protocol EA follows a **modular, layered architecture** designed for:

- **Testability**: Each module can be tested independently
- **Maintainability**: Clear separation of concerns
- **Extensibility**: Easy to add new features
- **Safety**: Multiple protection layers

## Component Diagram

```mermaid
flowchart TB
    subgraph Main["Main EA"]
        EA[GridSurvivalEA.mq5]
    end
    
    subgraph Core["Core Layer"]
        GE[GridEngine]
        PM[PositionManager]
        TE[TradeExecutor]
    end
    
    subgraph Protection["Protection Layer"]
        RM[RiskManager]
        DM[DrawdownMonitor]
        ES[EmergencyStop]
        HS[HardStop]
        DL[DailyLossLimit]
    end
    
    subgraph Analysis["Analysis Layer"]
        MS[MarketState]
        ATR[ATRCalculator]
        SF[SessionFilter]
        NF[NewsFilter]
    end
    
    subgraph Recovery["Recovery Layer"]
        AS[AdaptiveSizing]
    end
    
    subgraph Metrics["Metrics Layer"]
        PT[PerformanceTracker]
        EC[EquityCurve]
        AM[AlertManager]
    end
    
    subgraph Models["Data Models"]
        GL[GridLevel]
        TS[TradeState]
        PS[ProtectionState]
    end
    
    subgraph Utils["Utilities"]
        CM[Common]
        LG[Logger]
        CL[ConfigLoader]
    end
    
    EA --> Core
    EA --> Protection
    EA --> Analysis
    EA --> Recovery
    EA --> Metrics
    
    Core --> Models
    Protection --> Models
    All --> Utils
```

## Data Flow

```mermaid
sequenceDiagram
    participant MT5
    participant EA
    participant Protection
    participant Analysis
    participant Core
    participant Executor
    
    MT5->>EA: OnTick()
    EA->>Protection: CheckProtectionLayers()
    
    alt Hard Stop Triggered
        Protection-->>EA: STOP
        EA->>Executor: CloseAllPositions()
    else Emergency Stop
        Protection-->>EA: REDUCE_SIZE
    else OK
        Protection-->>EA: CONTINUE
    end
    
    EA->>Analysis: IsTradingAllowed()
    Analysis->>Analysis: CheckSession()
    Analysis->>Analysis: CheckNews()
    Analysis-->>EA: allowed/blocked
    
    alt Trading Allowed
        EA->>Core: ProcessTradingLogic()
        Core->>Core: UpdateGrid()
        Core->>Executor: OpenPosition()
    end
    
    EA->>MT5: Update Display
```

## Protection Priority Order

```
┌─────────────────────────────────────────────────────┐
│                   HARD STOP (20%)                   │
│             Closes all, locks EA                    │
├─────────────────────────────────────────────────────┤
│                 DAILY LIMIT (5%)                    │
│            Stops trading until reset                │
├─────────────────────────────────────────────────────┤
│               EMERGENCY STOP (10%)                  │
│          Reduces size, blocks new trades            │
├─────────────────────────────────────────────────────┤
│                SESSION FILTER                       │
│             Blocks outside hours                    │
├─────────────────────────────────────────────────────┤
│                  NEWS FILTER                        │
│            Pauses around events                     │
├─────────────────────────────────────────────────────┤
│                 SPREAD CHECK                        │
│            Blocks high spread                       │
├─────────────────────────────────────────────────────┤
│              NORMAL TRADING                         │
│           Grid logic executes                       │
└─────────────────────────────────────────────────────┘
```

## Module Responsibilities

### Core Layer

| Module | Responsibility |
|--------|----------------|
| `GridEngine` | Calculate grid levels, manage spacing |
| `PositionManager` | Track open positions, calculate exposure |
| `TradeExecutor` | Execute orders with retry logic |

### Protection Layer

| Module | Responsibility |
|--------|----------------|
| `RiskManager` | Calculate lot sizes, check risk limits |
| `DrawdownMonitor` | Track real-time drawdown |
| `EmergencyStop` | Level 1: Reduce exposure |
| `HardStop` | Level 2: Close all, lock EA |
| `DailyLossLimit` | Daily loss tracking and limits |

### Analysis Layer

| Module | Responsibility |
|--------|----------------|
| `MarketState` | Detect trending/ranging conditions |
| `ATRCalculator` | Calculate volatility-based spacing |
| `SessionFilter` | Time-based trading filter |
| `NewsFilter` | High-impact news pause |

### Recovery Layer

| Module | Responsibility |
|--------|----------------|
| `AdaptiveSizing` | Adjust lot size based on DD |

### Metrics Layer

| Module | Responsibility |
|--------|----------------|
| `PerformanceTracker` | Win rate, profit factor, etc. |
| `EquityCurve` | Equity history and analysis |
| `AlertManager` | Notifications and alerts |

## State Management

### EA States

```
INITIALIZING → IDLE ↔ TRADING
                 ↓       ↓
              PAUSED ← EMERGENCY → SHUTDOWN
```

### Trading Modes

```
NORMAL → REDUCED → CLOSE_ONLY → DISABLED
```

## Thread Safety

MQL5 is single-threaded, but the architecture is designed to:

1. Minimize expensive operations in `OnTick()`
2. Cache indicator values appropriately
3. Use efficient data structures

## Error Handling

Each module implements:

1. **Initialization validation**: Check prerequisites
2. **Runtime error catching**: Handle trade failures
3. **State recovery**: Resume after errors
4. **Logging**: All errors are logged

## Memory Management

- Fixed-size arrays where possible
- Ring buffers for equity history
- Cleanup in `OnDeinit()`

---

*Architecture designed for resilience and maintainability.*
