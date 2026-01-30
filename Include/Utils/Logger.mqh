//+------------------------------------------------------------------+
//|                                                      Logger.mqh  |
//|                               Grid Survival Protocol EA - Utils  |
//|                                                                  |
//| Description: Logging and Debugging Utilities                     |
//|              - Multi-level logging (DEBUG, INFO, WARNING, ERROR) |
//|              - File logging support                              |
//|              - Comment display                                   |
//+------------------------------------------------------------------+
#property copyright "Grid Survival Protocol"
#property link      ""
#property version   "1.00"

//+------------------------------------------------------------------+
//| Log Levels                                                       |
//+------------------------------------------------------------------+
enum ENUM_LOG_LEVEL
{
   LOG_LEVEL_DEBUG = 0,     // Show all messages
   LOG_LEVEL_INFO,          // Info and above
   LOG_LEVEL_WARNING,       // Warning and above
   LOG_LEVEL_ERROR,         // Error and above
   LOG_LEVEL_CRITICAL,      // Critical only
   LOG_LEVEL_NONE           // No logging
};

//+------------------------------------------------------------------+
//| Logger Class                                                     |
//+------------------------------------------------------------------+
class CLogger
{
private:
   ENUM_LOG_LEVEL    m_logLevel;           // Current log level
   string            m_prefix;             // Log prefix
   bool              m_fileLogging;        // Enable file logging
   string            m_logFileName;        // Log file name
   int               m_fileHandle;         // File handle
   bool              m_showOnChart;        // Show on chart comment
   string            m_chartComment;       // Current chart comment
   int               m_maxCommentLines;    // Max lines in chart comment
   string            m_commentLines[];     // Comment lines array

public:
   //--- Constructor
   CLogger()
   {
      m_logLevel        = LOG_LEVEL_INFO;
      m_prefix          = "[GridSurvival] ";
      m_fileLogging     = false;
      m_logFileName     = "";
      m_fileHandle      = INVALID_HANDLE;
      m_showOnChart     = true;
      m_chartComment    = "";
      m_maxCommentLines = 10;
      ArrayResize(m_commentLines, 0);
   }
   
   //--- Destructor
   ~CLogger()
   {
      CloseLogFile();
   }
   
   //--- Initialize logger
   bool Init(ENUM_LOG_LEVEL level = LOG_LEVEL_INFO, 
             string prefix = "[GridSurvival] ",
             bool fileLogging = false,
             string fileName = "")
   {
      m_logLevel    = level;
      m_prefix      = prefix;
      m_fileLogging = fileLogging;
      
      if(m_fileLogging)
      {
         if(fileName == "")
         {
            MqlDateTime dt;
            TimeToStruct(TimeCurrent(), dt);
            m_logFileName = StringFormat("GridSurvival_%04d%02d%02d.log",
                                         dt.year, dt.mon, dt.day);
         }
         else
         {
            m_logFileName = fileName;
         }
         
         return OpenLogFile();
      }
      
      return true;
   }
   
   //--- Set log level
   void SetLogLevel(ENUM_LOG_LEVEL level)
   {
      m_logLevel = level;
   }
   
   //--- Set log level (alias)
   void SetLevel(ENUM_LOG_LEVEL level)
   {
      m_logLevel = level;
   }
   
   //--- Set prefix
   void SetPrefix(string prefix)
   {
      m_prefix = "[" + prefix + "] ";
   }
   
   //--- Enable/disable file logging
   void EnableFileLogging(bool enable, string fileName = "")
   {
      m_fileLogging = enable;
      if(enable && m_fileHandle == INVALID_HANDLE)
      {
         if(fileName == "")
         {
            MqlDateTime dt;
            TimeToStruct(TimeCurrent(), dt);
            m_logFileName = StringFormat("GridSurvival_%04d%02d%02d.log",
                                         dt.year, dt.mon, dt.day);
         }
         else
         {
            m_logFileName = fileName;
         }
         OpenLogFile();
      }
      else if(!enable && m_fileHandle != INVALID_HANDLE)
      {
         CloseLogFile();
      }
   }
   
   //--- Get log level
   ENUM_LOG_LEVEL GetLogLevel() const
   {
      return m_logLevel;
   }
   
   //--- Enable/disable chart comment
   void SetShowOnChart(bool show)
   {
      m_showOnChart = show;
   }
   
   //--- Set max comment lines
   void SetMaxCommentLines(int maxLines)
   {
      m_maxCommentLines = maxLines;
   }
   
   //--- Debug level log
   void Debug(string message)
   {
      Log(LOG_LEVEL_DEBUG, message);
   }
   
   //--- Info level log
   void Info(string message)
   {
      Log(LOG_LEVEL_INFO, message);
   }
   
   //--- Warning level log
   void Warning(string message)
   {
      Log(LOG_LEVEL_WARNING, message);
   }
   
   //--- Error level log
   void Error(string message)
   {
      Log(LOG_LEVEL_ERROR, message);
   }
   
   //--- Critical level log
   void Critical(string message)
   {
      Log(LOG_LEVEL_CRITICAL, message);
   }
   
   //--- Log with format
   void InfoF(string format, string arg1 = "", string arg2 = "", string arg3 = "")
   {
      string msg = format;
      StringReplace(msg, "%1", arg1);
      StringReplace(msg, "%2", arg2);
      StringReplace(msg, "%3", arg3);
      Info(msg);
   }
   
   //--- Log trade event
   void LogTrade(string action, string symbol, double lot, double price, string comment = "")
   {
      string msg = StringFormat("TRADE: %s %s %.2f @ %.5f %s", 
                                action, symbol, lot, price, comment);
      Info(msg);
   }
   
   //--- Log protection event
   void LogProtection(string layer, string action, double value)
   {
      string msg = StringFormat("PROTECTION [%s]: %s (Value: %.2f%%)", 
                                layer, action, value);
      Warning(msg);
   }
   
   //--- Update chart comment
   void UpdateChartComment(string status, string details = "")
   {
      if(!m_showOnChart)
         return;
      
      m_chartComment = StringFormat("=== %s ===\n", m_prefix);
      m_chartComment += StringFormat("Status: %s\n", status);
      
      if(details != "")
         m_chartComment += details;
      
      Comment(m_chartComment);
   }
   
   //--- Add line to rolling comment
   void AddToComment(string line)
   {
      if(!m_showOnChart)
         return;
      
      // Add new line
      int size = ArraySize(m_commentLines);
      ArrayResize(m_commentLines, size + 1);
      m_commentLines[size] = TimeToString(TimeCurrent(), TIME_SECONDS) + " " + line;
      
      // Remove old lines if exceeding max
      while(ArraySize(m_commentLines) > m_maxCommentLines)
      {
         for(int i = 0; i < ArraySize(m_commentLines) - 1; i++)
            m_commentLines[i] = m_commentLines[i + 1];
         ArrayResize(m_commentLines, ArraySize(m_commentLines) - 1);
      }
      
      // Build comment string
      m_chartComment = StringFormat("=== %s ===\n", m_prefix);
      for(int i = 0; i < ArraySize(m_commentLines); i++)
         m_chartComment += m_commentLines[i] + "\n";
      
      Comment(m_chartComment);
   }
   
   //--- Clear chart comment
   void ClearComment()
   {
      ArrayResize(m_commentLines, 0);
      m_chartComment = "";
      Comment("");
   }

private:
   //--- Core log function
   void Log(ENUM_LOG_LEVEL level, string message)
   {
      // Check if we should log at this level
      if(level < m_logLevel)
         return;
      
      // Get level string
      string levelStr = GetLevelString(level);
      
      // Format message
      string fullMessage = StringFormat("%s[%s] %s", 
                                        m_prefix, levelStr, message);
      
      // Print to Experts tab
      Print(fullMessage);
      
      // Write to file if enabled
      if(m_fileLogging && m_fileHandle != INVALID_HANDLE)
      {
         string timestamp = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
         FileWriteString(m_fileHandle, timestamp + " " + fullMessage + "\n");
         FileFlush(m_fileHandle);
      }
      
      // Add to chart comment for warnings and above
      if(level >= LOG_LEVEL_WARNING && m_showOnChart)
      {
         AddToComment(StringFormat("[%s] %s", levelStr, message));
      }
   }
   
   //--- Get level string
   string GetLevelString(ENUM_LOG_LEVEL level)
   {
      switch(level)
      {
         case LOG_LEVEL_DEBUG:    return "DEBUG";
         case LOG_LEVEL_INFO:     return "INFO";
         case LOG_LEVEL_WARNING:  return "WARNING";
         case LOG_LEVEL_ERROR:    return "ERROR";
         case LOG_LEVEL_CRITICAL: return "CRITICAL";
         default:                 return "UNKNOWN";
      }
   }
   
   //--- Open log file
   bool OpenLogFile()
   {
      m_fileHandle = FileOpen(m_logFileName, 
                              FILE_WRITE | FILE_TXT | FILE_SHARE_READ | FILE_ANSI);
      
      if(m_fileHandle == INVALID_HANDLE)
      {
         Print("Failed to open log file: ", m_logFileName);
         return false;
      }
      
      // Write header
      string header = StringFormat("=== Grid Survival Protocol Log - %s ===\n",
                                   TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS));
      FileWriteString(m_fileHandle, header);
      FileFlush(m_fileHandle);
      
      return true;
   }
   
   //--- Close log file
   void CloseLogFile()
   {
      if(m_fileHandle != INVALID_HANDLE)
      {
         FileClose(m_fileHandle);
         m_fileHandle = INVALID_HANDLE;
      }
   }
};

//+------------------------------------------------------------------+
//| Global Logger Instance                                           |
//+------------------------------------------------------------------+
CLogger Logger;
//+------------------------------------------------------------------+
