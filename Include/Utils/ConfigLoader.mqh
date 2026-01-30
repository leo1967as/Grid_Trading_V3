//+------------------------------------------------------------------+
//|                                               ConfigLoader.mqh   |
//|                               Grid Survival Protocol EA - Utils  |
//|                                                                  |
//| Description: Configuration Loading Utilities                     |
//|              - Load/Save preset files                            |
//|              - State persistence                                 |
//+------------------------------------------------------------------+
#property copyright "Grid Survival Protocol"
#property link      ""
#property version   "1.00"

#include "Common.mqh"

//+------------------------------------------------------------------+
//| Config Loader Class                                              |
//+------------------------------------------------------------------+
class CConfigLoader
{
private:
   string   m_presetsPath;     // Path to presets folder
   string   m_stateFileName;   // State file name
   
public:
   //--- Constructor
   CConfigLoader()
   {
      m_presetsPath   = "Presets\\";
      m_stateFileName = "grid_state.bin";
   }
   
   //--- Set presets path
   void SetPresetsPath(string path)
   {
      m_presetsPath = path;
   }
   
   //--- Set state file name
   void SetStateFileName(string fileName)
   {
      m_stateFileName = fileName;
   }
   
   //--- Check if preset file exists
   bool PresetExists(string presetName)
   {
      string fullPath = m_presetsPath + presetName + ".set";
      return FileIsExist(fullPath, FILE_COMMON);
   }
   
   //--- Get list of available presets
   int GetPresetList(string &presets[])
   {
      string filter = m_presetsPath + "*.set";
      string fileName;
      long searchHandle = FileFindFirst(filter, fileName, FILE_COMMON);
      
      if(searchHandle == INVALID_HANDLE)
      {
         ArrayResize(presets, 0);
         return 0;
      }
      
      ArrayResize(presets, 0);
      int count = 0;
      
      do
      {
         ArrayResize(presets, count + 1);
         // Remove .set extension
         presets[count] = StringSubstr(fileName, 0, StringLen(fileName) - 4);
         count++;
      }
      while(FileFindNext(searchHandle, fileName));
      
      FileFindClose(searchHandle);
      return count;
   }
   
   //--- Save state to binary file
   bool SaveState(double equity, double highWaterMark, double dailyPL, 
                  int emergencyCount, int hardStopCount, datetime lastResetTime)
   {
      int handle = FileOpen(m_stateFileName, 
                            FILE_WRITE | FILE_BIN | FILE_COMMON);
      
      if(handle == INVALID_HANDLE)
      {
         LOG_ERROR("Failed to open state file for writing");
         return false;
      }
      
      // Write version
      int version = 1;
      FileWriteInteger(handle, version);
      
      // Write timestamp
      FileWriteLong(handle, (long)TimeCurrent());
      
      // Write state data
      FileWriteDouble(handle, equity);
      FileWriteDouble(handle, highWaterMark);
      FileWriteDouble(handle, dailyPL);
      FileWriteInteger(handle, emergencyCount);
      FileWriteInteger(handle, hardStopCount);
      FileWriteLong(handle, (long)lastResetTime);
      
      FileClose(handle);
      
      LOG_INFO("State saved successfully");
      return true;
   }
   
   //--- Load state from binary file
   bool LoadState(double &equity, double &highWaterMark, double &dailyPL,
                  int &emergencyCount, int &hardStopCount, datetime &lastResetTime)
   {
      if(!FileIsExist(m_stateFileName, FILE_COMMON))
      {
         LOG_INFO("No saved state file found");
         return false;
      }
      
      int handle = FileOpen(m_stateFileName, 
                            FILE_READ | FILE_BIN | FILE_COMMON);
      
      if(handle == INVALID_HANDLE)
      {
         LOG_ERROR("Failed to open state file for reading");
         return false;
      }
      
      // Read and check version
      int version = FileReadInteger(handle);
      if(version != 1)
      {
         LOG_WARNING("State file version mismatch");
         FileClose(handle);
         return false;
      }
      
      // Read timestamp and check if too old (older than 1 day)
      datetime savedTime = (datetime)FileReadLong(handle);
      if(TimeCurrent() - savedTime > SECONDS_PER_DAY)
      {
         LOG_WARNING("State file is older than 1 day, ignoring");
         FileClose(handle);
         return false;
      }
      
      // Read state data
      equity         = FileReadDouble(handle);
      highWaterMark  = FileReadDouble(handle);
      dailyPL        = FileReadDouble(handle);
      emergencyCount = FileReadInteger(handle);
      hardStopCount  = FileReadInteger(handle);
      lastResetTime  = (datetime)FileReadLong(handle);
      
      FileClose(handle);
      
      LOG_INFO("State loaded successfully");
      return true;
   }
   
   //--- Delete state file
   bool ClearState()
   {
      if(FileIsExist(m_stateFileName, FILE_COMMON))
      {
         if(FileDelete(m_stateFileName, FILE_COMMON))
         {
            LOG_INFO("State file deleted");
            return true;
         }
         else
         {
            LOG_ERROR("Failed to delete state file");
            return false;
         }
      }
      return true;
   }
   
   //--- Export current settings to preset file
   bool ExportPreset(string presetName, string &settings[], string &values[])
   {
      if(ArraySize(settings) != ArraySize(values))
      {
         LOG_ERROR("Settings and values arrays must have same size");
         return false;
      }
      
      string fullPath = m_presetsPath + presetName + ".set";
      int handle = FileOpen(fullPath, 
                            FILE_WRITE | FILE_TXT | FILE_COMMON | FILE_ANSI);
      
      if(handle == INVALID_HANDLE)
      {
         LOG_ERROR("Failed to create preset file: " + fullPath);
         return false;
      }
      
      // Write header
      FileWriteString(handle, "; Grid Survival Protocol EA Preset\n");
      FileWriteString(handle, "; Created: " + TimeToString(TimeCurrent()) + "\n");
      FileWriteString(handle, "; Name: " + presetName + "\n");
      FileWriteString(handle, "\n");
      
      // Write settings
      for(int i = 0; i < ArraySize(settings); i++)
      {
         FileWriteString(handle, settings[i] + "=" + values[i] + "\n");
      }
      
      FileClose(handle);
      
      LOG_INFO("Preset exported: " + presetName);
      return true;
   }
};

//+------------------------------------------------------------------+
//| Global Config Loader Instance                                    |
//+------------------------------------------------------------------+
CConfigLoader ConfigLoader;
//+------------------------------------------------------------------+
