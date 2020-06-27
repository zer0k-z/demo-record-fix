#include <sdktools>

public void OnPluginStart()
{
    CreateTimer(1.0, Timer_DemoFix, _, TIMER_REPEAT);
}

Action Timer_DemoFix(Handle timer)
{
    GameRules_SetProp("m_bWarmupPeriod", 1);
    GameRules_SetPropFloat("m_fWarmupPeriodStart", GetGameTime() - 1.0);
    GameRules_SetPropFloat("m_fWarmupPeriodEnd", GetGameTime() - 1.0);
    return Plugin_Continue;
}
