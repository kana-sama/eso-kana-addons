local K=KanaTrifecta
local profile=K.Profiles:Find(1301,DUNGEON_DIFFICULTY_VETERAN or 2)
profile.startRule=0
profile.ClassifyContext=K.Profiles.ClassifyFresh
profile.Observe=K.Profiles.ObserveEncounters
profile.additionalRequirements={'otherRequiredEnemies'}
profile.achievementIds={speedrun=3107,noDeath=3108,trifecta=3111,hardModes={3106,3153,3225},conqueror=3105}
profile.achievementCatalogIds={3102,3103,3104,3105,3106,3107,3108,3109,3110,3111,3121,3122,3123,3124,
    3125,3126,3127,3128,3153,3222,3225,3226,3229,3230,3231}
profile.journalAnchorAchievementId=3105
profile.journalCategoryIsDedicated=false -- Catalog fallback remains safe until category membership is checked.
profile.bosses={
    {key='maligalig',name={en='Maligalig',ru='Малигалиг'},aliases={'Maligalig','Малигалиг'},
        hasHardMode=true,requiresHardMode=true,terminalDeath=true},
    {key='sarydil',name={en='Sarydil',ru='Саридил'},aliases={'Sarydil','Саридил'},
        hasHardMode=true,requiresHardMode=true,terminalDeath=true},
    {key='varallion',name={en='Varallion',ru='Вараллион'},aliases={'Varallion','Вараллион'},
        hasHardMode=true,requiresHardMode=true,terminalDeath=true,
        healthModes={[6766879]='inactive',[13195414]='active'},
        healthSource='CrutchAlerts/bosshealthbar/DungeonThresholds.lua: Varallion'},
}
profile.conditionSupport={start='source',timer='source',deaths='source',kills='source',hardMode='partial',achievements='source'}
