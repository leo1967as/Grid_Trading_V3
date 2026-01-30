//+------------------------------------------------------------------+
//|                                               AlertManager.mqh   |
//|                             Grid Survival Protocol EA - Metrics  |
//|                                                                  |
//| Description: Alert and Notification Management                   |
//|              - MT5 alerts                                        |
//|              - Push notifications                                |
//|              - Email alerts                                      |
//|              - Webhook support                                   |
//+------------------------------------------------------------------+
#property copyright "Grid Survival Protocol"
#property link      ""
#property version   "1.00"

#include "../Utils/Common.mqh"
#include "../Utils/Logger.mqh"

//+------------------------------------------------------------------+
//| Alert Type Enum                                                  |
//+------------------------------------------------------------------+
enum ENUM_ALERT_TYPE
{
   ALERT_TYPE_INFO = 0,      // Informational
   ALERT_TYPE_WARNING,       // Warning
   ALERT_TYPE_ERROR,         // Error
   ALERT_TYPE_CRITICAL       // Critical - requires immediate attention
};

//+------------------------------------------------------------------+
//| Alert Class                                                      |
//+------------------------------------------------------------------+
class CAlertManager
{
private:
   bool              m_enabled;           // Alerts enabled
   bool              m_useMT5Alert;       // Use MT5 Alert()
   bool              m_usePushNotify;     // Use push notifications
   bool              m_useEmail;          // Use email
   bool              m_useWebhook;        // Use webhook
   
   string            m_webhookUrl;        // Webhook URL
   string            m_emailRecipient;    // Email recipient
   string            m_prefix;            // Alert prefix
   
   datetime          m_lastAlertTime;     // Last alert time
   int               m_minAlertInterval;  // Minimum interval between alerts (seconds)
   int               m_alertCount;        // Alert count today
   int               m_maxAlertsPerDay;   // Maximum alerts per day
   
   bool              m_isInitialized;
   
public:
   //--- Constructor
   CAlertManager()
   {
      m_enabled          = true;
      m_useMT5Alert      = true;
      m_usePushNotify    = false;
      m_useEmail         = false;
      m_useWebhook       = false;
      m_webhookUrl       = "";
      m_emailRecipient   = "";
      m_prefix           = "[GridEA]";
      m_lastAlertTime    = 0;
      m_minAlertInterval = 60;      // 1 minute minimum between alerts
      m_alertCount       = 0;
      m_maxAlertsPerDay  = 100;
      m_isInitialized    = false;
   }
   
   //--- Initialize
   bool Init(bool enabled = true, string prefix = "[GridEA]")
   {
      m_enabled = enabled;
      m_prefix  = prefix;
      m_alertCount = 0;
      
      m_isInitialized = true;
      Logger.Info(StringFormat("AlertManager initialized: Enabled=%s, Prefix=%s",
                               m_enabled ? "true" : "false", m_prefix));
      return true;
   }
   
   //--- Configure notification methods
   void Configure(bool mt5Alert = true, bool pushNotify = false, 
                  bool email = false, bool webhook = false)
   {
      m_useMT5Alert   = mt5Alert;
      m_usePushNotify = pushNotify;
      m_useEmail      = email;
      m_useWebhook    = webhook;
   }
   
   //--- Set webhook URL
   void SetWebhookUrl(string url)
   {
      m_webhookUrl = url;
      m_useWebhook = (url != "");
   }
   
   //--- Set email recipient
   void SetEmailRecipient(string email)
   {
      m_emailRecipient = email;
      m_useEmail = (email != "");
   }
   
   //--- Set minimum alert interval
   void SetMinInterval(int seconds)
   {
      m_minAlertInterval = seconds;
   }
   
   //--- Send alert
   bool SendAlert(ENUM_ALERT_TYPE type, string message)
   {
      if(!m_enabled || !m_isInitialized)
         return false;
      
      // Check throttling
      if(!CanSendAlert())
         return false;
      
      m_lastAlertTime = TimeCurrent();
      m_alertCount++;
      
      string typeStr = GetTypeString(type);
      string fullMessage = StringFormat("%s %s: %s", m_prefix, typeStr, message);
      
      // Log the alert
      Logger.Info(StringFormat("Alert sent: %s", fullMessage));
      
      // Send via each enabled method
      if(m_useMT5Alert)
         Alert(fullMessage);
      
      if(m_usePushNotify)
         SendNotification(fullMessage);
      
      if(m_useEmail && m_emailRecipient != "")
      {
         string subject = m_prefix + " " + typeStr;
         SendMail(subject, message);
      }
      
      if(m_useWebhook && m_webhookUrl != "")
         SendWebhook(type, message);
      
      return true;
   }
   
   //--- Send info alert
   void Info(string message)
   {
      SendAlert(ALERT_TYPE_INFO, message);
   }
   
   //--- Send warning alert
   void Warning(string message)
   {
      SendAlert(ALERT_TYPE_WARNING, message);
   }
   
   //--- Send error alert
   void Error(string message)
   {
      SendAlert(ALERT_TYPE_ERROR, message);
   }
   
   //--- Send critical alert (always sends immediately)
   void Critical(string message)
   {
      // Critical alerts bypass throttling
      m_lastAlertTime = 0;  // Temporarily bypass
      SendAlert(ALERT_TYPE_CRITICAL, message);
   }
   
   //--- Alert for drawdown threshold
   void DrawdownAlert(double drawdown, double threshold)
   {
      Warning(StringFormat("Drawdown %.2f%% approaching threshold %.2f%%",
                           drawdown, threshold));
   }
   
   //--- Alert for protection layer trigger
   void ProtectionAlert(string layer, string action)
   {
      Critical(StringFormat("Protection Layer [%s] triggered: %s", layer, action));
   }
   
   //--- Alert for trade event
   void TradeAlert(string action, string symbol, double lots, double price)
   {
      Info(StringFormat("Trade: %s %s %.2f @ %.5f", action, symbol, lots, price));
   }
   
   //--- Enable/disable alerts
   void SetEnabled(bool enabled)
   {
      m_enabled = enabled;
   }
   
   //--- Check if enabled
   bool IsEnabled() const
   {
      return m_enabled;
   }
   
   //--- Get alert count today
   int GetAlertCount() const
   {
      return m_alertCount;
   }
   
   //--- Reset daily counter
   void ResetDailyCount()
   {
      m_alertCount = 0;
   }
   
   //--- Get status summary
   string GetStatusSummary() const
   {
      return StringFormat("Alerts: Enabled=%s | Count=%d/%d | Methods: MT5=%s Push=%s Email=%s Hook=%s",
                          m_enabled ? "Y" : "N", 
                          m_alertCount, m_maxAlertsPerDay,
                          m_useMT5Alert ? "Y" : "N",
                          m_usePushNotify ? "Y" : "N",
                          m_useEmail ? "Y" : "N",
                          m_useWebhook ? "Y" : "N");
   }
   
   //--- Check if initialized
   bool IsInitialized() const
   {
      return m_isInitialized;
   }
   
private:
   //--- Check if can send alert (throttling)
   bool CanSendAlert()
   {
      // Check daily limit
      if(m_alertCount >= m_maxAlertsPerDay)
         return false;
      
      // Check interval
      if(TimeCurrent() - m_lastAlertTime < m_minAlertInterval)
         return false;
      
      return true;
   }
   
   //--- Get type string
   string GetTypeString(ENUM_ALERT_TYPE type)
   {
      switch(type)
      {
         case ALERT_TYPE_INFO:     return "INFO";
         case ALERT_TYPE_WARNING:  return "WARNING";
         case ALERT_TYPE_ERROR:    return "ERROR";
         case ALERT_TYPE_CRITICAL: return "CRITICAL";
         default:                  return "UNKNOWN";
      }
   }
   
   //--- Send webhook request
   bool SendWebhook(ENUM_ALERT_TYPE type, string message)
   {
      // Note: MQL5 WebRequest requires URL to be added to allowed list
      // This is a placeholder for webhook functionality
      
      // Format JSON payload
      string json = StringFormat(
         "{\"type\":\"%s\",\"message\":\"%s\",\"time\":\"%s\"}",
         GetTypeString(type), message, TimeToString(TimeCurrent())
      );
      
      // In real implementation, use WebRequest
      // For now, just log
      Logger.Debug(StringFormat("Webhook payload: %s", json));
      
      return true;
   }
};
//+------------------------------------------------------------------+
