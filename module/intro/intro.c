#include "client.h"
#include "intro.h"

HINSTANCE hInst;

extern "C" BOOL WINAPI DllMain(HINSTANCE hModule, DWORD reason, LPVOID reserved)
{
   switch (reason)
   {
   case DLL_PROCESS_ATTACH:
      hInst = hModule;
      break;

   case DLL_PROCESS_DETACH:
      break;
   }
   return TRUE;
   (void) reserved;
}

extern "C" void WINAPI GetModuleInfo(ModuleInfo *info, ClientInfo *client_info)
{
   info->event_mask = 0;
   info->priority   = PRIORITY_IGNORE;
   info->module_id  = MODULE_ID;

   (void) client_info;
}
