#include <sourcemod>
#include <sdktools>
#include <dhooks>

Handle gH_GetPlayerSlot;
Handle gH_ExecuteStringCommand;

public void OnPluginStart()
{
    HookEvents();
}

void HookEvents()
{
    // From Peace-Maker's DHooks example: https://forums.alliedmods.net/showthread.php?p=2588686
    GameData gameData = LoadGameConfigFile("demofix.games");
    if(!gameData)
        SetFailState("Could not find demofix.games gamedata.");
    
    // Setup detour on IClient::ExecuteStringCommand.
    gH_ExecuteStringCommand = DHookCreateDetour(Address_Null, CallConv_THISCALL, ReturnType_Bool, ThisPointer_Address);
    if (!gH_ExecuteStringCommand)
        SetFailState("Failed to setup detour for ExecuteStringCommand");
    
    // Load the address of the function from gamedata file.
    if (!DHookSetFromConf(gH_ExecuteStringCommand, gameData, SDKConf_Signature, "ExecuteStringCommand"))
    {
        SetFailState("Failed to load ExecuteStringCommand signature from gamedata");
    }

    // Add all parameters.
    DHookAddParam(gH_ExecuteStringCommand, HookParamType_CharPtr);

    // And a post hook.
    if (!DHookEnableDetour(gH_ExecuteStringCommand, true, Detour_OnExecuteStringCommand_Post))
    {
        SetFailState("Failed to detour ExecuteStringCommand post.");
    }
        
    // Setup quick hack to get the client index of the IClient this pointer in the detour callback.
    StartPrepSDKCall(SDKCall_Raw);
    PrepSDKCall_SetFromConf(gameData, SDKConf_Virtual, "GetPlayerSlotOffs");
    PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain);
    gH_GetPlayerSlot = EndPrepSDKCall();
    delete gameData;
}


void FixRecord(int client)
{
    // For some reasons, demo playback speed is absolute trash without a round_start event.
    // So whenever the client starts recording a demo, we create the event and send it to them.
    Event e = CreateEvent("round_start", true);
    int timelimit = FindConVar("mp_timelimit").IntValue;
    e.SetInt("timelimit", timelimit);
    e.SetInt("fraglimit", 0);
    e.SetString("objective", "demofix");

    e.FireToClient(client);
    delete e;
}

public MRESReturn Detour_OnExecuteStringCommand_Post(Address pThis, Handle hReturn, Handle hParams)
{
    int client = SDKCall(gH_GetPlayerSlot, pThis) + 1;

    char sBuffer[512];
    DHookGetParamString(hParams, 1, sBuffer, sizeof(sBuffer));
    if (StrEqual(sBuffer, "demorestart"))
    {
        PrintToConsole(client, "Demo recording detected, applying fix...");
        FixRecord(client);
        PrintToConsole(client, "Fix applied!");
    }
} 

public void OnMapStart()
{
    // Set warmup time to 2^31-1, effectively forever
    // The reason we do this instead of setting a timer is to avoid clogging the demo and slightly increase performance.
    FindConVar("mp_warmuptime").SetInt(2147483647);
    // Enable warmup to allow demo recording
    GameRules_SetProp("m_bWarmupPeriod", 1);
    GameRules_SetPropFloat("m_fWarmupPeriodStart", GetGameTime() - 1.0);
    // m_fWarmupPeriodEnd is set in the past to hide the timer UI (?)
    GameRules_SetPropFloat("m_fWarmupPeriodEnd", GetGameTime() - 1.0);    
}