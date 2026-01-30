# Parameter Reference

## Input Parameters

### Basic Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `InpMagicNumber` | long | 777777 | Unique identifier for EA's orders |
| `InpBaseLotSize` | double | 0.01 | Base lot size for trades |
| `InpMaxGridLevels` | int | 10 | Maximum number of grid levels |

### ATR & Grid Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `InpATRTimeframe` | ENUM_TIMEFRAMES | H1 | Timeframe for ATR calculation |
| `InpATRPeriod` | int | 14 | ATR indicator period |
| `InpATRMultiplier` | double | 1.5 | Multiplier for grid spacing (spacing = ATR × multiplier) |
| `InpGridMultiplier` | double | 1.0 | Lot size multiplier per level (1.0 = same, 1.5 = martingale) |

### Protection Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `InpEmergencyStopDD` | double | 10.0 | Drawdown % to trigger emergency stop (reduce size) |
| `InpHardStopDD` | double | 20.0 | Drawdown % to trigger hard stop (close all) |
| `InpDailyLossLimit` | double | 5.0 | Maximum daily loss % before stopping |

> [!IMPORTANT]
> The Hard Stop threshold should always be higher than Emergency Stop. Recommended: Hard Stop = Emergency Stop × 2

### Risk Management

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `InpRiskPerTrade` | double | 1.0 | Risk per trade as % of equity |
| `InpMaxTotalRisk` | double | 10.0 | Maximum total risk exposure % |
| `InpMaxSpread` | double | 30.0 | Maximum spread in points to allow trading |

### Session Filter

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `InpUseSessionFilter` | bool | true | Enable/disable session filter |
| `InpSessionStart` | int | 2 | Trading start hour (server time, 0-23) |
| `InpSessionEnd` | int | 22 | Trading end hour (server time, 0-23) |
| `InpAvoidFriday` | bool | true | Stop trading on Friday evening |
| `InpFridayCutoff` | int | 20 | Hour to stop on Friday |

### News Filter

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `InpUseNewsFilter` | bool | true | Enable/disable news filter |
| `InpStopBeforeNews` | int | 30 | Minutes to stop before news |
| `InpResumeAfterNews` | int | 15 | Minutes to wait after news |

> [!NOTE]
> News events must be added manually via the `AddNewsEvent()` function or loaded from external source.

### Sizing Mode

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `InpSizingMode` | ENUM_SIZING_MODE | ADAPTIVE | Lot sizing mode |
| `InpDDReductionStart` | double | 5.0 | DD% to start reducing lot size |
| `InpDDReductionFull` | double | 15.0 | DD% for minimum lot size |

#### Sizing Modes

| Mode | Description |
|------|-------------|
| `SIZING_MODE_FIXED` | Always use base lot size |
| `SIZING_MODE_PERCENT` | Calculate based on risk % |
| `SIZING_MODE_ADAPTIVE` | Reduce lot as DD increases |

### Alerts

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `InpEnableAlerts` | bool | true | Enable alert notifications |
| `InpUsePushNotify` | bool | false | Send push notifications to mobile |

### Debug

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `InpLogLevel` | ENUM_LOG_LEVEL | INFO | Minimum log level to display |
| `InpEnableFileLog` | bool | false | Write logs to file |

#### Log Levels

| Level | Description |
|-------|-------------|
| `LOG_LEVEL_DEBUG` | Detailed debugging info |
| `LOG_LEVEL_INFO` | Normal operational messages |
| `LOG_LEVEL_WARNING` | Warning conditions |
| `LOG_LEVEL_ERROR` | Error conditions |
| `LOG_LEVEL_CRITICAL` | Critical failures |

---

## Recommended Settings by Risk Profile

### Conservative

| Parameter | Value |
|-----------|-------|
| Base Lot Size | 0.01 |
| Max Grid Levels | 5 |
| Emergency Stop DD | 8% |
| Hard Stop DD | 15% |
| Daily Limit | 3% |
| Grid Multiplier | 1.0 |

### Balanced (Default)

| Parameter | Value |
|-----------|-------|
| Base Lot Size | 0.01 |
| Max Grid Levels | 8 |
| Emergency Stop DD | 10% |
| Hard Stop DD | 20% |
| Daily Limit | 5% |
| Grid Multiplier | 1.0 |

### Aggressive

| Parameter | Value |
|-----------|-------|
| Base Lot Size | 0.02 |
| Max Grid Levels | 10 |
| Emergency Stop DD | 15% |
| Hard Stop DD | 30% |
| Daily Limit | 8% |
| Grid Multiplier | 1.2 |

---

## Symbol-Specific Settings

### Major Pairs (EURUSD, GBPUSD, etc.)

| Parameter | Value |
|-----------|-------|
| ATR Period | 14 |
| ATR Multiplier | 1.5 |
| Max Spread | 20 |

### Minor Pairs (EURJPY, GBPAUD, etc.)

| Parameter | Value |
|-----------|-------|
| ATR Period | 14 |
| ATR Multiplier | 2.0 |
| Max Spread | 40 |

### Exotic Pairs

| Parameter | Value |
|-----------|-------|
| ATR Period | 20 |
| ATR Multiplier | 2.5 |
| Max Spread | 80 |

---

## FAQ

**Q: Why is my EA not opening trades?**

Check:

1. Session filter (are you in trading hours?)
2. News filter (is there upcoming news?)
3. Spread (is it too wide?)
4. Protection (is Emergency/Hard Stop triggered?)

**Q: Why did the EA close all my positions?**

The Hard Stop was triggered. Check your drawdown exceeded the `InpHardStopDD` threshold.

**Q: How do I resume after Hard Stop?**

The Hard Stop requires manual intervention. Restart the EA to reset.

**Q: What's the difference between Emergency and Hard Stop?**

- **Emergency Stop**: Reduces position size and stops new trades, but keeps existing positions open
- **Hard Stop**: Closes ALL positions immediately and locks the EA
