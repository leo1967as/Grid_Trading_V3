//+------------------------------------------------------------------+
//|                                                  TrendFilter.mqh |
//|                                  Copyright 2026, Grid Survival   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Grid Survival"
#property link      ""
#property strict

#include "..\Utils\Logger.mqh"

//+------------------------------------------------------------------+
//| Trend Filter Class - Prevents entry during extreme trends        |
//+------------------------------------------------------------------+
class CTrendFilter
{
private:
   string      m_symbol;
   int         m_adxHandle;
   int         m_threshold;
   bool        m_isInitialized;

public:
   CTrendFilter() : m_adxHandle(INVALID_HANDLE), m_threshold(30), m_isInitialized(false) {}
   
   ~CTrendFilter() 
   {
      if(m_adxHandle != INVALID_HANDLE)
         IndicatorRelease(m_adxHandle);
   }

   //--- Initialize indicator
   bool Init(string symbol, ENUM_TIMEFRAMES tf, int adxPeriod, int threshold)
   {
      m_symbol = symbol;
      m_threshold = threshold;
      m_adxHandle = iADX(m_symbol, tf, adxPeriod);
      
      if(m_adxHandle == INVALID_HANDLE)
      {
         Logger.Error("TrendFilter: Failed to create ADX handle");
         return false;
      }
      
      m_isInitialized = true;
      Logger.Info(StringFormat("TrendFilter initialized: Threshold=%d", m_threshold));
      return true;
   }

   //--- Check if trend is too strong based on ADX
   bool IsTrendTooStrong()
   {
      if(!m_isInitialized || m_adxHandle == INVALID_HANDLE) 
         return false;

      double adxValues[1];
      if(CopyBuffer(m_adxHandle, 0, 0, 1, adxValues) <= 0)
      {
         Logger.Debug("TrendFilter: Failed to copy ADX buffer");
         return false;
      }

      return (adxValues[0] > m_threshold);
   }

   //--- Get current ADX value for debugging/display
   double GetCurrentADX()
   {
      if(!m_isInitialized || m_adxHandle == INVALID_HANDLE) 
         return 0;
         
      double adxValues[1];
      if(CopyBuffer(m_adxHandle, 0, 0, 1, adxValues) > 0)
         return adxValues[0];
         
      return 0;
   }
};
