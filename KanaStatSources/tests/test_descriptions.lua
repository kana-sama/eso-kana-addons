local T=dofile('KanaStatSources/tests/support.lua');local K=T.load({'Core','Stats','Rules','Descriptions'})
return {
 prefix=function() local c,tail=K.Descriptions.Parse('Adds 1096 Maximum Magicka. When you deal damage, gain 300 for 10 seconds.','en','set');T.eq(c[1].amount,1096);T.eq(c[1].stats[1],'maxMagicka');T.eq(tail~='',true) end,
 locales=function() for _,text in ipairs({'|cffffffМаксимальная магия +1 096|r','Максимальная магия +1 096','Adds 1,096 Maximum Magicka'}) do local c=K.Descriptions.Parse(text,text:find('Adds') and 'en' or 'ru','set');T.eq(c[1].amount,1096) end;local c=K.Descriptions.Parse('Увеличивает максимальное здоровье на 7,5%.','ru','skill');T.eq(c[1].amount,7.5);T.eq(c[1].operation,'percent') end,
 conditional=function() for _,text in ipairs({'When you deal damage, adds 1206 Maximum Health for 10 seconds.','Adds 129 Weapon and Spell Damage for 10 seconds.','10% chance to gain 1206 Maximum Health.','(2 items) When you attack, gain 1096 Maximum Magicka.'}) do local c,tail=K.Descriptions.Parse(text,'en','set');T.eq(#c,0);T.eq(tail~='',true) end end,
 combined=function() local c=K.Descriptions.Parse('(2 items) Adds 657 Critical Chance.','en','set');T.eq(c[1].operation,'flat');T.eq(#c[1].stats,2);c=K.Descriptions.Parse('Increases your Weapon and Spell Critical rating by 7%.','en','trait');T.eq(c[1].operation,'criticalChance') end,
 food=function() local c=K.Descriptions.Parse('Increase Max Health by 5395 and Max Magicka by 4936 for 2 hours.','en','effect');T.eq(#c,2);T.eq(c[2].amount,4936) end,
 decrease=function() local c=K.Descriptions.Parse('Reduces your Physical and Spell Resistance by 5948.','en','effect');T.eq(c[1].amount,-5948) end,
 foreign_locale=function() local c=K.Descriptions.Parse('Augmente santé de 1000','fr','skill');T.eq(#c,0) end,
}
