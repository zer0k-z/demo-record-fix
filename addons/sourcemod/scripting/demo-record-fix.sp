#include <sourcemod>
#include <sdktools>
#include <dhooks>

#include <autoexecconfig>

ConVar gCV_EnableDemofix;
Handle gH_DemofixTimer;
bool gB_MapRunning;
bool gB_LateLoad;

public Plugin myinfo = {
	name = "Demo Record Fix",
	author = "zer0.k",
	description = "Allows POV demo recording and fixes demo corruption",
	version = "2.0"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	gB_LateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	AddCommandListener(Command_Demorestart, "demorestart");
	gCV_EnableDemofix = AutoExecConfig_CreateConVar("demofix_enable", "1", "Whether demo record fix is enabled. (0 = Disabled, 1 = Update warmup period once, 2 = Regularly reset warmup period)", _, true, 0.0, true, 2.0);
	gCV_EnableDemofix.AddChangeHook(OnDemofixConVarChanged);
	// If the map is tweaking the warmup value, we need to rerun the fix again.
	FindConVar("mp_warmuptime").AddChangeHook(OnDemofixConVarChanged);
	// We assume that the map is already loaded on late load.
	if (gB_LateLoad)
	{
		gB_MapRunning = true;
	}
	HookEvent("round_start", OnRoundStart, EventHookMode_PostNoCopy);
}

public void OnMapStart()
{
	gB_MapRunning = true;
}

public void OnMapEnd()
{
	gB_MapRunning = false;
}

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast) // round_start post no copy hook
{
	DoDemoFix();
}

public Action Command_Demorestart(int client, const char[] command, int argc)
{
	FixRecord(client);
}

public void OnDemofixConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	DoDemoFix();
}

static void DoDemoFix()
{
	if (gH_DemofixTimer != null)
	{
		delete gH_DemofixTimer;
	}
	// Setting the cvar value to 1 can avoid clogging the demo file and slightly increase performance.
	switch (gCV_EnableDemofix.IntValue)
	{
		case 0:
		{
			if (!gB_MapRunning)
			{
				return;
			}

			GameRules_SetProp("m_bWarmupPeriod", 0);
		}
		case 1:
		{
			// Set warmup time to 2^31-1, effectively forever
			if (FindConVar("mp_warmuptime").IntValue != 2147483647)
			{
				FindConVar("mp_warmuptime").SetInt(2147483647);
			}
			EnableDemoRecord();
		}
		case 2:
		{
			gH_DemofixTimer = CreateTimer(1.0, Timer_EnableDemoRecord, _, TIMER_REPEAT);
		}
	}
}

public Action Timer_EnableDemoRecord(Handle timer)
{
	EnableDemoRecord();
	return Plugin_Continue;
}

static void EnableDemoRecord()
{
	// Enable warmup to allow demo recording
	// m_fWarmupPeriodEnd is set in the past to hide the timer UI
	if (!gB_MapRunning)
	{
		return;
	}
	GameRules_SetProp("m_bWarmupPeriod", 1);
	GameRules_SetPropFloat("m_fWarmupPeriodStart", GetGameTime() - 1.0);
	GameRules_SetPropFloat("m_fWarmupPeriodEnd", GetGameTime() - 1.0);
}

static void FixRecord(int client)
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