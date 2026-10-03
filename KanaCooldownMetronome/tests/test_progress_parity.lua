-- Execute the real progress updater in both modes with identical event input.
local root = arg and arg[2] or '../CombatMetronome'
DariansUtilities={Ability={Tracker={}},Text={}}
CombatMetronome={}
local now=10000
function GetFrameTimeMilliseconds() return now end
function GetLatency() return 120 end
function DariansUtilities.Ability.Tracker:GCDCheck() return .9,900,1000 end
local function control()
 return {SetWidth=function(self,v) self.width=v end,SetHidden=function() end}
end
local function run(radial,elapsed,delay,heavy,channel,expand)
 now=10000+elapsed
 local cm=CombatMetronome
 local sv={radialCooldown=radial,width=300,height=30,maxLatency=150,expandDynamically=expand,dynamicExpansionMultiplyer=10,barAlign='Left',progressColor={1,.84,.24,.63},channelColor={.02,.62,1,.63},changeOnChanneled=channel,displayPingOnHeavy=true}
 cm.SV={Progressbar=sv}
 cm.Progressbar={soundTickPlayed=true,soundTockPlayed=true,bar={segments={{progress=0,color={1,0,0,.63}},{progress=0,color=sv.progressColor}},background=control(),backgroundTexture=control(),borderL=control(),borderR=control(),Update=function() end},timeLabel=control(),spellLabel=control(),spellIcon=control(),spellIconBorder=control()}
 cm.currentEvent={start=10000,adjust=25,ending=15000,ability={name='test',delay=delay,heavy=heavy,instant=false}}
 cm.gcd=1000
 cm.HideBar=function() end
 cm.OnCDStop=function() end
 cm:Update()
 local b=cm.Progressbar.bar
 return b.segments[1].progress,b.segments[2].progress,b.segments[2].color
end
dofile(root..'/CMProgressbar.lua')
for _,case in ipairs({{0,2500,true,true,true},{200,2500,true,true,true},{1900,2500,true,true,true},{0,1000,false,false,false},{800,1000,false,false,false},{900,1000,false,true,false}}) do
 local p,q,c=run(false,unpack(case))
 local rp,rq,rc=run(true,unpack(case))
 assert(p==rp,'radial ping differs from linear at '..case[1]..'ms')
 assert(q==rq,'radial progress differs from linear at '..case[1]..'ms')
 for i=1,4 do assert(c[i]==rc[i],'radial channel/progress color differs') end
end
print('PASS real updater parity: start, heavy/channel, dynamic expansion, ping, colors')
