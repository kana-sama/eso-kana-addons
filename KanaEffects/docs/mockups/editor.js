'use strict';
// Design prototype only. Synthetic catalog and frozen fixtures; no ESO API connection.
const $ = s => document.querySelector(s);
const esc = s => String(s).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const clone = o => JSON.parse(JSON.stringify(o));
const UI = 0.80432397;
let screenW = 2560, screenH = 1440, scale = 1, editing = false, selected = null, load = 0;
let draft, committed, pickerPurpose, pickerTab = 'named', pickerLevel = 'pair', noticeTimer, inspectedWidget;
const familyNames = [
 ['resolve','Решимость','Resolve','◇',185],['courage','Храбрость','Courage','✧',38],
 ['brutality','Жестокость','Brutality','ϟ',18],['savagery','Свирепость','Savagery','⋔',30],
 ['force','Сила','Force','✦',280],['heroism','Героизм','Heroism','♜',48],
 ['protection','Защита','Protection','⬡',206],['vitality','Жизненная сила','Vitality','❧',100],
 ['mending','Исцеление','Mending','✚',151],['evasion','Уклонение','Evasion','≋',202],
 ['expedition','Скорость','Expedition','»',135],['endurance','Выносливость','Endurance','⋀',100],
 ['intellect','Интеллект','Intellect','◈',227],['fortitude','Стойкость','Fortitude','♡',355],
 ['brittle','Хрупкость','Brittle','❄',195],['breach','Разлом','Breach','⋈',28],
 ['vulnerability','Уязвимость','Vulnerability','◎',285],['maim','Увечье','Maim','×',5],
 ['defile','Осквернение','Defile','♧',86],['cowardice','Трусость','Cowardice','▽',290],
 ['aegis','Эгида','Aegis','⛨',205],['slayer','Убийца','Slayer','⚔',24],
 ['berserk','Берсерк','Berserk','⚡',36],['lifesteal','Похищение жизни','Lifesteal','♢',350]
];
const families = familyNames.map((a,i)=>({id:a[0],name:a[1],en:a[2],glyph:a[3],hue:a[4],index:i,kind:(i>=14&&i<=19)?'debuff':'buff'}));
const specials = [
 {id:'food',name:'Еда: трёхстатная',glyph:'♨',hue:32,category:'food',duration:7200,remaining:3360},
 {id:'xp',name:'Свиток опыта',glyph:'✧',hue:50,category:'xp',duration:3600,remaining:1380},
 {id:'boon',name:'Благословение',glyph:'☀',hue:42,category:'service',duration:0,remaining:Infinity},
 {id:'armor',name:'Доспехи',glyph:'◇',hue:195,category:'skill',duration:24,remaining:14},
 {id:'proc',name:'Прок комплекта',glyph:'⋔',hue:312,category:'set',duration:10,remaining:7},
 {id:'shield',name:'Щит навыка',glyph:'⬡',hue:195,category:'skill',duration:6,remaining:4},
 {id:'enchant',name:'Зачарование оружия',glyph:'ϟ',hue:48,category:'enchant',duration:8,remaining:6},
 {id:'poison',name:'Яд',glyph:'♧',hue:105,category:'skill',duration:12,remaining:9,kind:'debuff'},
 {id:'curse',name:'Долгое проклятие',glyph:'▽',hue:280,category:'skill',duration:120,remaining:43,kind:'debuff'},
 {id:'toggle',name:'Активная аура',glyph:'◉',hue:175,category:'skill',duration:0,remaining:Infinity,toggle:true},
 {id:'unknown',name:'Неизвестная длительность',glyph:'?',hue:180,category:'unknown',duration:null,remaining:null},
 {id:'expired',name:'Недавний эффект босса',glyph:'⋈',hue:18,category:'skill',duration:20,remaining:0,kind:'debuff'}
].map((e,i)=>({...e,abilityId:910001+i,kind:e.kind||'buff'}));
const durationNames = {short:'Короткие',long:'Долгие',permanent:'Постоянные',toggle:'Переключаемые',unknown:'Неизвестные'};
const categoryNames = {food:'Еда / напитки',xp:'Опыт',service:'Служебные',skill:'Навыки',set:'Комплекты',enchant:'Зачарования'};
const sourceName = s => s==='player'?'Игрок':s==='target'?'Текущая цель':'Босс';
const initialSets = [
 {id:'support',name:'Еда и долгие',kind:'buff',named:'exclude',durations:['long','permanent','toggle'],categories:['food','xp','service'],exclude:[]},
 {id:'combat',name:'Боевые',kind:'any',named:'any',durations:Object.keys(durationNames),categories:[],exclude:['support']},
 {id:'named',name:'Именованные',kind:'any',named:'only',durations:Object.keys(durationNames),categories:[],exclude:[]},
 {id:'all',name:'Все эффекты',kind:'any',named:'any',durations:Object.keys(durationNames),categories:[],exclude:[]}
];
function newWidget(type,id,name) {
 return {id,name,type,source:'player',style:'over',icon:48,timer:15,font:16,rowWidth:280,gap:6,ax:0,ay:0,x:700,y:700,
 cols:6,rows:3,axis:'columns',limit:6,absent:'ghost',slots:{},include:['combat'],exclude:[],named:'any',merge:true};
}
function initialConfig(){
 const table=newWidget('table','named-widget','Именованные · игрок');
 table.x=1250;table.y=1250;table.cols=6;table.rows=3;
 families.slice(0,14).concat(families.slice(20,24)).forEach((f,i)=>table.slots[`${Math.floor(i/6)},${i%6}`]=`f:${f.id}:pair`);
 const combat=newWidget('grid','combat-widget','Боевые · игрок');
 Object.assign(combat,{x:1250,y:1490,style:'under',icon:44,limit:8,named:'exclude'});
 const support=newWidget('grid','support-widget','Еда и долгие');
 Object.assign(support,{x:120,y:1280,style:'list',icon:36,font:16,timer:16,limit:1,include:['support']});
 const target=newWidget('grid','target-widget','Эффекты цели');
 Object.assign(target,{x:1589,y:338,ax:.5,source:'target',style:'under',icon:40,limit:8,include:['all']});
 return {widgets:[table,combat,support,target],sets:clone(initialSets),hidden:[],threshold:60};
}
committed=initialConfig(); draft=clone(committed);
const config=()=>editing?draft:committed;
const activeWidget=()=>config().widgets.find(w=>w.id===selected);
function toast(t){$('#toast').textContent=t;$('#toast').classList.add('show');clearTimeout(noticeTimer);noticeTimer=setTimeout(()=>$('#toast').classList.remove('show'),4500);}
function observe(){
 const records=[];
 for(const source of ['player','target']) {
  families.forEach((f,i)=>{
   const visible=source==='player'?(i<14||i>19):(i>=14&&i<=19);
   if(!visible||(!load&&i%5===3)) return;
   for(const level of ['minor','major']){
    if(!load&&((level==='minor'&&i%3===0)||(level==='major'&&i%4===2)))continue;
    records.push({key:`${source}-${f.id}-${level}`,source,family:f.id,level,name:`${level==='minor'?'Minor':'Major'} ${f.name}`,en:f.en,
     abilityId:900000+i*2+(level==='minor'?1:2),glyph:f.glyph,hue:f.hue,kind:f.kind,category:'named',duration:i===0?0:30,remaining:i===0?Infinity:12+(i*3)%18});
   }
  });
  specials.filter(e=>e.id!=='expired'&&(source==='player'||['poison','curse','proc'].includes(e.id))).forEach(e=>records.push({...e,key:`${source}-${e.id}`,source}));
 }
 if(load){while(records.length<load){let i=records.length;records.push({key:`stress-${i}`,source:i%4===0?'target':'player',abilityId:920000+i,name:`Тестовый эффект ${i+1}`,glyph:['✧','◇','⋔','ϟ'][i%4],hue:(i*47)%360,kind:i%6===0?'debuff':'buff',category:'skill',duration:i%5===0?120:20,remaining:4+i%19});}}
 return records;
}
let observations=observe();
const life=e=>e.duration===null?'unknown':e.toggle?'toggle':e.duration===0?'permanent':e.duration>=config().threshold?'long':'short';
function matchesSet(e,id,visited=new Set()){
 if(visited.has(id))return false;
 const s=config().sets.find(s=>s.id===id);if(!s)return false;
 const path=new Set(visited);path.add(id);
 return (s.kind==='any'||s.kind===e.kind)&&(s.named==='any'||(s.named==='only')===!!e.family)
  &&(s.durations.includes(life(e))||s.categories.includes(e.category))&&!s.exclude.some(other=>matchesSet(e,other,path));
}
function matches(e,key){
 const [type,id,level]=key.split(':');
 return type==='f'? e.family===id&&(level==='pair'||e.level===level):type==='c'?e.category===id:String(e.abilityId)===id;
}
function selectorInfo(key){
 const [t,id,level]=key.split(':');
 if(t==='f'){const f=families.find(f=>f.id===id);return {...f,name:f.name,level,pair:level==='pair',label:`${f.name} · ${level==='pair'?'Minor + Major':level==='minor'?'Minor':'Major'}`};}
 if(t==='c'){const e=specials.find(e=>e.category===id);return {...e,name:id==='food'?'Любая еда':categoryNames[id]||id,label:id==='food'?'Любая еда':categoryNames[id]||id,categorySelector:true};}
 const e=observations.find(e=>String(e.abilityId)===id)||specials.find(e=>String(e.abilityId)===id);
 return {...e,name:e?.name||`ID ${id}`,label:e?.name||`ID ${id}`,glyph:e?.glyph||'?',hue:e?.hue||180};
}
function gridRecords(w){return observations.filter(e=>e.source===w.source&&w.include.some(id=>matchesSet(e,id))&&!w.exclude.some(id=>matchesSet(e,id))&&(w.named==='any'||(w.named==='only')===!!e.family)&&!config().hidden.some(k=>matches(e,k)));}
function entries(w){
 if(w.type==='table'){
  const arr=[];for(let r=0;r<w.rows;r++)for(let c=0;c<w.cols;c++){
   const key=w.slots[`${r},${c}`];arr.push({key,slot:`${r},${c}`,row:r,col:c,meta:key?selectorInfo(key):null,matches:key?observations.filter(e=>e.source===w.source&&matches(e,key)):[]});
  }return arr;
 }
 const result=[],lookup=new Map();
 gridRecords(w).forEach(e=>{
  const key=e.family&&w.merge?`f:${e.family}:pair`:`a:${e.abilityId}`;
  if(lookup.has(key)){lookup.get(key).matches.push(e);return;}
  const entry={key,meta:selectorInfo(key),matches:[e]};lookup.set(key,entry);result.push(entry);
 });return result;
}
function metric(w){
 const timerWidth=Math.ceil(w.timer*3.1+8);
 const cw=w.style==='list'?Math.max(w.rowWidth,w.icon+timerWidth+70):w.style==='right'?w.icon+8+timerWidth:Math.max(w.icon,timerWidth);
 const ch=w.style==='under'?w.icon+Math.ceil(w.timer*2.44)+5:Math.max(w.icon,Math.ceil(w.timer*2.44));
 return {cw,ch};
}
function geometry(w,items=entries(w)){
 const {cw,ch}=metric(w);let cols=w.cols,rows=w.rows;
 if(w.type==='grid'){if(w.axis==='columns'){cols=Math.min(w.limit,Math.max(items.length,1));rows=Math.max(1,Math.ceil(items.length/w.limit));}else{rows=Math.min(w.limit,Math.max(items.length,1));cols=Math.max(1,Math.ceil(items.length/w.limit));}}
 const width=cols*cw+(cols-1)*w.gap,height=rows*ch+(rows-1)*w.gap;
 return {cw,ch,cols,rows,width,height,left:w.x-w.ax*width,top:w.y-w.ay*height};
}
const fmt=t=>t===null?'?':t===Infinity?'∞':t>=3600?`${Math.floor(t/3600)}ч`:t>=60?`${Math.floor(t/60)}м`:String(Math.ceil(t));
function remaining(es,category=false){if(es.some(e=>e.remaining===null))return '?';if(!es.length)return '—';const finite=es.map(e=>e.remaining).filter(v=>Number.isFinite(v));return fmt(category&&finite.length?Math.min(...finite):Math.max(...es.map(e=>e.remaining)));}
function cellHTML(entry,w){
 if(!entry.meta)return '<span>+</span>';
 const m=entry.meta, rows=[];
 if(m.pair){for(const lv of ['minor','major']){const found=entry.matches.filter(e=>e.level===lv);rows.push(`<span class="timer-line ${lv} ${found.length?'':'missing'}" aria-label="${lv==='minor'?'Minor':'Major'}"><span>${remaining(found)}</span></span>`);}}
 else{rows.push(`<span class="timer-line ${m.level||''}"${m.level?` aria-label="${m.level==='minor'?'Minor':'Major'}"`:''}><span>${remaining(entry.matches,m.categorySelector)}</span></span>`);}
 const count=m.categorySelector&&entry.matches.length>1?` <sup>×${entry.matches.length}</sup>`:'';
 return `<div class="effect-content"><span class="effect-icon" style="--hue:${m.hue};width:${w.icon}px;height:${w.icon}px;font-size:${w.icon*.65}px">${m.glyph}</span>${w.style==='list'?`<span class="effect-name" style="font-size:${w.font}px">${esc(m.name)}${count}</span>`:''}<span class="timer-stack" style="font-size:${w.timer}px;${['list','right'].includes(w.style)?`width:${Math.ceil(w.timer*3.1+8)}px`:''}">${rows.join('')}</span></div>`;
}
function cellDOM(entry,w,g,i){
 const cell=document.createElement('div');cell.className=`effect-cell style-${w.style} ${entry.meta?.kind==='debuff'?'debuff':''} ${entry.matches.length?'':'ghost'} ${!entry.key?'empty':''} ${editing&&w.type==='table'?'edit-slot':''}`;
 const col=w.type==='table'?entry.col:w.axis==='columns'?i%w.limit:Math.floor(i/w.limit);
 const row=w.type==='table'?entry.row:w.axis==='columns'?Math.floor(i/w.limit):i%w.limit;
 const x=(w.type==='grid'&&w.ax===1?g.cols-1-col:col)*(g.cw+w.gap),y=(w.type==='grid'&&w.ay===1?g.rows-1-row:row)*(g.ch+w.gap);
 Object.assign(cell.style,{left:`${x}px`,top:`${y}px`,width:`${g.cw}px`,height:`${g.ch}px`});
 cell.dataset.widget=w.id;if(entry.slot)cell.dataset.slot=entry.slot;cell.dataset.effect=entry.key||'';
 cell.setAttribute('aria-label',`${w.name}: ${entry.meta?.label||'Пустой слот'}${entry.slot?' ['+entry.slot+']':''}`);
 if(entry.meta)cell.title=`${entry.meta.label}\n${sourceName(w.source)} · ${entry.matches.length?'активен':'неактивен'}${config().hidden.includes(entry.key)?' · скрыт в гридах':''}${w.type==='grid'?'\nНабор: '+w.include.map(id=>config().sets.find(s=>s.id===id)?.name).join(', '):''}`;
 if(!entry.matches.length&&w.absent==='hidden'&&!editing)cell.style.visibility='hidden';
 cell.innerHTML=cellHTML(entry,w);
 if(editing){cell.addEventListener('pointerdown',e=>{if(e.button!==0)return;if(w.type==='table')startSlotDrag(e,w,entry,cell);else{selected=w.id;render();}});}
 return cell;
}
function renderWidgets(){
 $('#widgets').replaceChildren();
 for(const w of config().widgets){
  const items=entries(w),g=geometry(w,items),node=document.createElement('section');
  node.className=`widget ${editing?'editing':''} ${editing&&selected===w.id?'selected':''}`;node.dataset.widget=w.id;node.setAttribute('aria-label',w.name);
  Object.assign(node.style,{left:g.left+'px',top:g.top+'px',width:g.width+'px',height:g.height+'px'});
  items.forEach((e,i)=>node.append(cellDOM(e,w,g,i)));
  if(editing){
   const caption=document.createElement('div');caption.className='widget-caption';caption.innerHTML=`⠿ ${esc(w.name)} <span>${w.type==='table'?`${w.cols} × ${w.rows}`:items.length+' эффектов'}</span>`;caption.setAttribute('aria-label','Переместить '+w.name);
   caption.onpointerdown=e=>startWidgetDrag(e,w,node);node.append(caption);
   node.addEventListener('click',e=>{if(e.target===node){selected=w.id;render();}});
   if(w.id===selected){
    for(let y=0;y<3;y++)for(let x=0;x<3;x++){
     const dot=document.createElement('button');dot.className=`anchor-dot ${w.ax===x/2&&w.ay===y/2?'active':''}`;dot.style.left=(x*50)+'%';dot.style.top=(y*50)+'%';dot.title=`Якорь ${['левый','центр','правый'][x]} ${['верхний','середина','нижний'][y]}`;dot.setAttribute('aria-label',dot.title);dot.onclick=e=>{e.stopPropagation();setAnchor(w,x/2,y/2);};node.append(dot);
    }
    if(w.type==='table'){const resize=document.createElement('div');resize.className='resize-handle';resize.title='Изменить размер таблицы';resize.setAttribute('aria-label',resize.title);resize.onpointerdown=e=>startResize(e,w,node);node.append(resize);}
   }
  }
  $('#widgets').append(node);
 }
}
function render(){renderWidgets();renderInspector();$('#hidden-count').textContent=config().hidden.length;$('#status').textContent=editing?`Черновик · ${config().widgets.length} виджета · рамки не меняют раскладку`:`Просмотр · ${config().widgets.length} виджета · ${observations.length} демонстрационных наблюдений`;}
function opt(value,label,cur){return `<option value="${value}" ${value===cur?'selected':''}>${label}</option>`;}
function selectHTML(id,choices,current){return `<select id="${id}">${choices.map(([v,l])=>opt(v,l,current)).join('')}</select>`;}
function numberHTML(id,value,min,max){return `<input id="${id}" type="number" value="${Math.round(value)}" min="${min}" max="${max}" step="1">`;}
function renderInspector(){
 const w=activeWidget(),panel=$('#inspector');panel.hidden=!editing||!w;if(panel.hidden)return;
 const g=geometry(w),savedScroll=inspectedWidget===w.id?panel.scrollTop:0;
 inspectedWidget=w.id;
 const excluded=config().sets.filter(s=>!w.include.includes(s.id));
 const hiddenSlots=Object.keys(w.slots).filter(k=>{const [r,c]=k.split(',').map(Number);return r>=w.rows||c>=w.cols;}).length;
 panel.innerHTML=`<div class="inspector-head"><small>${w.type==='table'?'ФИКСИРОВАННАЯ ТАБЛИЦА':'АВТОМАТИЧЕСКИЙ ГРИД'}</small><button id="close-inspector" aria-label="Закрыть настройки виджета">×</button></div>
 <label>Имя <input id="w-name" type="text" value="${esc(w.name)}"></label>
 <label>Чьи эффекты ${selectHTML('w-source',[['player','Игрок'],['target','Текущая цель']],w.source)}</label>
 <div class="inspector-section"><p class="section-title">${w.type==='table'?'Слоты':'Состав'}</p>
 ${w.type==='table'?`<div class="two"><label>Колонки ${numberHTML('w-cols',w.cols,1,24)}</label><label>Строки ${numberHTML('w-rows',w.rows,1,24)}</label></div><label>Неактивные ${selectHTML('w-absent',[['ghost','Полупрозрачно'],['hidden','Скрыть']],w.absent)}</label><p class="hint">Клик по слоту — выбор. Перетащи иконку для обмена. Угол рамки меняет размер.</p>${hiddenSlots?`<p class="occupied-note">За границей: ${hiddenSlots}. Расширение вернёт назначения.</p>`:''}`:
 `<label>Включить набор ${selectHTML('w-set',config().sets.map(s=>[s.id,s.name]),w.include[0])}</label><label>Именованные ${selectHTML('w-named',[['any','Включать'],['exclude','Исключить'],['only','Только они']],w.named)}</label><label><span>Объединять Minor + Major</span><input id="w-merge" type="checkbox" ${w.merge?'checked':''}></label><p class="section-title">Исключить наборы</p>${excluded.map(s=>`<label>${esc(s.name)}<input type="checkbox" data-exclude="${s.id}" ${w.exclude.includes(s.id)?'checked':''}></label>`).join('')}<button id="edit-sets">Настроить наборы…</button><p class="hint">${setExplanation(w)}</p><div class="overlap-note">${overlapText(w)}</div>`}</div>
 <div class="inspector-section"><p class="section-title">Рисование</p><label>Стиль ${selectHTML('w-style',[['over','Таймер поверх'],['under','Таймер снизу'],['right','Таймер справа'],['list','Название справа']],w.style)}</label><div class="two"><label>Иконка ${numberHTML('w-icon',w.icon,28,96)}</label><label>Таймер ${numberHTML('w-timer',w.timer,11,28)}</label></div><div class="two"><label>Имя ${numberHTML('w-font',w.font,11,28)}</label><label>Зазор ${numberHTML('w-gap',w.gap,0,24)}</label></div>${w.style==='list'?`<label>Ширина ячейки ${numberHTML('w-width',w.rowWidth,160,500)}</label>`:''}
 <p class="hint">Образец в UI-единицах, без уменьшения обзора</p><div class="preview-detail" id="cell-preview"></div>
 ${w.type==='grid'?`<label>Фиксировать ${selectHTML('w-axis',[['columns','Число колонок'],['rows','Число строк']],w.axis)}</label><label>Количество ${numberHTML('w-limit',w.limit,1,30)}</label><p class="hint">Другая сторона растёт от якоря.</p>`:''}</div>
 <div class="inspector-section"><p class="section-title">Якорь и координаты</p><div class="anchor-row"><div class="anchors">${[0,.5,1].flatMap(y=>[0,.5,1].map(x=>`<button data-anchor="${x},${y}" class="${w.ax===x&&w.ay===y?'active':''}" aria-label="Точка якоря ${x},${y}">•</button>`)).join('')}</div><div class="coordinates"><label>X ${numberHTML('w-x',w.x,-4000,8000)}</label><label>Y ${numberHTML('w-y',w.y,-4000,8000)}</label></div></div><p class="hint">Координаты выбранной точки относительно экрана. Смена точки сохраняет прямоугольник.</p><div class="two"><button id="center-x">Центр по горизонтали</button><button id="center-y">Центр по вертикали</button></div><p class="hint">${Math.round(g.width*UI)} × ${Math.round(g.height*UI)} px при UI ≈ 0.804. Привязка к штатным панелям — на этапе ESO.</p></div>
 <div class="foot-actions"><button id="duplicate">Дублировать</button><button id="delete-widget" class="danger">Удалить виджет</button></div>`;
 const preview=entries(w).find(e=>e.meta)||{key:'f:resolve:pair',meta:selectorInfo('f:resolve:pair'),matches:observations.filter(e=>e.source==='player'&&e.family==='resolve')};
 const el=cellDOM(preview,{...w,type:'grid'},g,0);el.style.left='0';el.style.top='0';el.style.position='relative';el.classList.remove('ghost');$('#cell-preview').append(el);
 const bind=(id,prop,cast=v=>v)=>{const input=$(id);if(input)input.onchange=()=>{const value=cast(input.type==='checkbox'?input.checked:input.value);if(typeof value==='number'&&!Number.isFinite(value)){render();return;}w[prop]=value;render();};};
 bind('#w-name','name');bind('#w-source','source');bind('#w-cols','cols',v=>clamp(v,1,24));bind('#w-rows','rows',v=>clamp(v,1,24));bind('#w-absent','absent');
 bind('#w-style','style');bind('#w-icon','icon',v=>clamp(v,28,96));bind('#w-timer','timer',v=>clamp(v,11,28));bind('#w-font','font',v=>clamp(v,11,28));bind('#w-gap','gap',v=>clamp(v,0,24));bind('#w-width','rowWidth',v=>clamp(v,160,500));
 bind('#w-axis','axis');bind('#w-limit','limit',v=>clamp(v,1,30));bind('#w-x','x',Number);bind('#w-y','y',Number);bind('#w-named','named');bind('#w-merge','merge');
 if($('#w-set'))$('#w-set').onchange=()=>{w.include=[$('#w-set').value];w.exclude=w.exclude.filter(x=>!w.include.includes(x));render();};
 panel.querySelectorAll('[data-exclude]').forEach(n=>n.onchange=()=>{const id=n.dataset.exclude;w.exclude=n.checked?[...w.exclude,id]:w.exclude.filter(x=>x!==id);render();});
 panel.querySelectorAll('[data-anchor]').forEach(b=>b.onclick=()=>setAnchor(w,...b.dataset.anchor.split(',').map(Number)));
 $('#close-inspector').onclick=()=>{selected=null;render();};
 $('#center-x').onclick=()=>{const a=geometry(w);w.x=(screenW/UI-a.width)/2+w.ax*a.width;render();};
 $('#center-y').onclick=()=>{const a=geometry(w);w.y=(screenH/UI-a.height)/2+w.ay*a.height;render();};
 $('#duplicate').onclick=()=>{const c=clone(w);c.id='widget-'+Date.now();c.name+=' · копия';c.x+=80;c.y+=80;draft.widgets.push(c);selected=c.id;render();};
 $('#delete-widget').onclick=()=>{draft.widgets=draft.widgets.filter(x=>x.id!==w.id);selected=null;render();toast('Виджет удалён в черновике. Отмена вернёт его.');};
 if($('#edit-sets'))$('#edit-sets').onclick=openSets;
 panel.scrollTop=savedScroll;
}
function setExplanation(w){const s=config().sets.find(s=>s.id===w.include[0]);const excl=[...(s?.exclude||[]),...w.exclude].map(id=>config().sets.find(s=>s.id===id)?.name);return `Правило: ${esc(s?.name||'')} ${excl.length?'минус «'+esc(excl.join('», «'))+'».':'· без исключений.'} Скрытый список применяется после него.`;}
function overlapText(w){const keys=new Set(gridRecords(w).map(e=>e.key));let overlaps=[];for(const other of config().widgets){if(other.type!=='grid'||other.id===w.id)continue;const n=gridRecords(other).filter(e=>keys.has(e.key)).length;if(n)overlaps.push(`${esc(other.name)}: ${n}`);}return overlaps.length?'Пересечения наблюдений: '+overlaps.join('; '):'С другими гридами пересечений сейчас нет.';}
function clamp(v,a,b){return Math.max(a,Math.min(b,Math.round(Number(v))));}
function setAnchor(w,x,y){const g=geometry(w);w.ax=x;w.ay=y;w.x=g.left+x*g.width;w.y=g.top+y*g.height;render();}
function trackPointer(e,onMove,onEnd){e.preventDefault();const move=ev=>onMove(ev);const end=ev=>{document.removeEventListener('pointermove',move);document.removeEventListener('pointerup',end);document.removeEventListener('pointercancel',end);onEnd(ev);};document.addEventListener('pointermove',move);document.addEventListener('pointerup',end);document.addEventListener('pointercancel',end);}
function startWidgetDrag(e,w,node){if(e.button!==0)return;selected=w.id;const start={x:e.clientX,y:e.clientY,wx:w.x,wy:w.y},g=geometry(w);trackPointer(e,ev=>{w.x=start.wx+(ev.clientX-start.x)/scale;w.y=start.wy+(ev.clientY-start.y)/scale;node.style.left=(w.x-w.ax*g.width)+'px';node.style.top=(w.y-w.ay*g.height)+'px';},()=>render());}
function startResize(e,w,node){const start={x:e.clientX,y:e.clientY},g=geometry(w);const original={cols:w.cols,rows:w.rows};trackPointer(e,ev=>{w.cols=clamp(original.cols+(ev.clientX-start.x)/scale/(g.cw+w.gap),1,24);w.rows=clamp(original.rows+(ev.clientY-start.y)/scale/(g.ch+w.gap),1,24);const next=geometry(w);w.x=g.left+w.ax*next.width;w.y=g.top+w.ay*next.height;renderWidgets();},()=>render());}
function startSlotDrag(e,w,entry,cell){
 const sx=e.clientX,sy=e.clientY;let moved=false,ghost=null,target=null;
 trackPointer(e,ev=>{
  if(!moved&&Math.hypot(ev.clientX-sx,ev.clientY-sy)<5)return;
  if(!entry.key)return;moved=true;
  if(!ghost){ghost=document.createElement('div');ghost.className='drag-ghost';ghost.textContent=entry.meta.label;document.body.append(ghost);}
  ghost.style.left=ev.clientX+12+'px';ghost.style.top=ev.clientY+12+'px';
  target?.classList.remove('drop-target');target=document.elementFromPoint(ev.clientX,ev.clientY)?.closest('.edit-slot');target?.classList.add('drop-target');
 },ev=>{
  ghost?.remove();target?.classList.remove('drop-target');selected=w.id;
  if(moved&&target){const other=config().widgets.find(w=>w.id===target.dataset.widget);const slot=target.dataset.slot;if(other&&slot&&(other.id!==w.id||slot!==entry.slot)){const dest=other.slots[slot];other.slots[slot]=entry.key;if(!ev.altKey){if(dest)w.slots[entry.slot]=dest;else delete w.slots[entry.slot];}toast(ev.altKey?'Назначение скопировано.':'Назначения переставлены.');}}
  render();if(!moved)openPicker({type:'slot',widget:w.id,slot:entry.slot});
 });
}
function updateViewport(){
 const vp=$('#viewport'),zoom=$('#zoom').value;
 const fit=Math.min(vp.clientWidth/screenW,vp.clientHeight/screenH);
 scale=UI*(zoom==='fit'?fit:1);
 const scene=$('#scene');scene.style.width=screenW/UI+'px';scene.style.height=screenH/UI+'px';scene.style.transform=`scale(${scale})`;
 scene.style.left=zoom==='fit'?Math.max(0,(vp.clientWidth-screenW*fit)/2)+'px':'0';scene.style.top=zoom==='fit'?Math.max(0,(vp.clientHeight-screenH*fit)/2)+'px':'0';
}
function enter(){draft=clone(committed);editing=true;selected=draft.widgets[0]?.id;$('#toolbar').hidden=false;$('#edit').hidden=true;render();}
function leave(save){if(save)committed=clone(draft);editing=false;selected=null;load=0;observations=observe();$('#toolbar').hidden=true;$('#edit').hidden=false;$('#test').textContent='Тест: обычный бой';render();toast(save?'Настройки сохранены для текущего макета.':'Все изменения сессии отменены.');}
$('#edit').onclick=enter;$('#save').onclick=()=>leave(true);$('#cancel').onclick=()=>leave(false);
$('#test').onclick=()=>{load=load===0?100:load===100?250:0;observations=observe();$('#test').textContent=load?'Тест: '+load+' эффектов':'Тест: обычный бой';render();toast(load?'Синтетические данные. Не попадают в историю.':'Обычный бой.');};
$('#toolbar .handle').onpointerdown=e=>{const panel=$('#toolbar'),x=panel.offsetLeft,y=panel.offsetTop,sx=e.clientX,sy=e.clientY;trackPointer(e,ev=>{panel.style.left=Math.max(0,Math.min($('#viewport').clientWidth-panel.offsetWidth,x+ev.clientX-sx))+'px';panel.style.top=Math.max(0,Math.min($('#viewport').clientHeight-panel.offsetHeight,y+ev.clientY-sy))+'px';},()=>{});};
$('#resolution').onchange=()=>{const oldW=screenW,oldH=screenH;screenW=Number($('#resolution').value);screenH=screenW*9/16;for(const c of [draft,committed])for(const w of c.widgets){w.x*=screenW/oldW;w.y*=screenH/oldH;}updateViewport();render();};
$('#zoom').onchange=updateViewport;window.addEventListener('resize',updateViewport);
$('#add').onclick=()=>$('#add-dialog').showModal();
$$('[data-create]').forEach(b=>b.onclick=()=>{const w=newWidget(b.dataset.create,'widget-'+Date.now(),b.dataset.create==='table'?'Новая таблица':'Новый грид');w.x=screenW/UI/2-180;w.y=screenH/UI/2-50;draft.widgets.push(w);selected=w.id;$('#add-dialog').close();render();});
function $$(s){return [...document.querySelectorAll(s)];}
$$('[data-close]').forEach(b=>b.onclick=()=>$('#'+b.dataset.close).close());
function openPicker(purpose){pickerPurpose=purpose;pickerTab='named';pickerLevel='pair';$('#search').value='';$('#picker-title').textContent=purpose.type==='hide'?'Скрыть во всех гридах':'Выбрать эффект для слота';$('#clear-slot').hidden=purpose.type!=='slot';renderPicker();$('#picker').showModal();$('#search').focus();}
function renderPicker(){
 $('#picker-tabs').innerHTML=[['named','Именованные'],['common','Категории и частые'],['active','Активные'],['recent','Недавние']].map(([id,label])=>`<button data-tab="${id}" class="${pickerTab===id?'active':''}">${label}</button>`).join('');
 $$('#picker-tabs button').forEach(b=>b.onclick=()=>{pickerTab=b.dataset.tab;renderPicker();});
 $('#level-switch').innerHTML=pickerTab==='named'?[['pair','Minor + Major'],['minor','Только Minor'],['major','Только Major']].map(([id,l])=>`<button data-level="${id}" class="${id===pickerLevel?'active':''}">${l}</button>`).join(''):'';
 $$('#level-switch button').forEach(b=>b.onclick=()=>{pickerLevel=b.dataset.level;renderPicker();});
 const q=$('#search').value.trim().toLowerCase();let candidates=[];
 if(q){
  candidates=[...families.map(f=>({key:`f:${f.id}:${pickerLevel}`,meta:selectorInfo(`f:${f.id}:${pickerLevel}`),detail:'Именованное семейство',search:f.name+' '+f.en})),...observations.map(e=>({key:`a:${e.abilityId}`,meta:selectorInfo(`a:${e.abilityId}`),detail:`ID макета ${e.abilityId}`,search:e.name+' '+e.en+' '+e.abilityId})),...specials.map(e=>({key:`a:${e.abilityId}`,meta:selectorInfo(`a:${e.abilityId}`),detail:`ID макета ${e.abilityId}`,search:e.name+' '+e.abilityId}))].filter(c=>c.search.toLowerCase().includes(q));
 }else if(pickerTab==='named')candidates=families.map(f=>({key:`f:${f.id}:${pickerLevel}`,meta:selectorInfo(`f:${f.id}:${pickerLevel}`),detail:f.en+(f.index>=18&&f.index<=19?' · PvP / редко':'')}));
 else if(pickerTab==='common')candidates=[...['food','xp','service'].map(c=>({key:`c:${c}`,meta:selectorInfo(`c:${c}`),detail:'Все эффекты категории'})),...specials.filter(e=>e.duration===0).map(e=>({key:`a:${e.abilityId}`,meta:selectorInfo(`a:${e.abilityId}`),detail:'Конкретный постоянный эффект'}))];
 else if(pickerTab==='active')candidates=observations.map(e=>({key:`a:${e.abilityId}`,meta:selectorInfo(`a:${e.abilityId}`),detail:`${sourceName(e.source)} · ${fmt(e.remaining)}`}));
 else candidates=[...specials].reverse().map(e=>({key:`a:${e.abilityId}`,meta:selectorInfo(`a:${e.abilityId}`),detail:`${e.id==='expired'?'Босс · 2 мин назад':'Игрок · недавно'} · ${e.abilityId}`}));
 candidates=[...new Map(candidates.map(c=>[c.key,c])).values()];
 $('#picker-note').textContent=pickerTab==='named'?'Демонстрационная таблица семейств; версия каталога ESO будет проверяться отдельно.':pickerTab==='common'?'«Любая еда» продолжает работать после смены блюда.':pickerTab==='recent'?'Пример истории наблюдений. Источник сохраняется вместе с ID.':'Наблюдения сгруппированы по ID. В игре здесь будут реальные эффекты.';
 $('#picker-results').innerHTML=candidates.length?candidates.map(c=>`<button class="pick-effect" data-pick="${c.key}"><span class="mini-icon" style="--hue:${c.meta.hue}">${c.meta.glyph}</span><span><b>${esc(c.meta.label||c.meta.name)}</b><small>${esc(c.detail)}</small></span></button>`).join(''):`<p class="empty-message">Нет в каталоге макета. В ESO точный ID будет проверяться адресным запросом к API.</p>`;
 $$('#picker-results button').forEach(b=>b.onclick=()=>{const key=b.dataset.pick;if(pickerPurpose.type==='hide'){if(!draft.hidden.includes(key))draft.hidden.push(key);renderHidden();}else{const w=draft.widgets.find(w=>w.id===pickerPurpose.widget);w.slots[pickerPurpose.slot]=key;}$('#picker').close();render();});
}
$('#search').oninput=renderPicker;
$('#clear-slot').onclick=()=>{const w=draft.widgets.find(w=>w.id===pickerPurpose.widget);delete w.slots[pickerPurpose.slot];$('#picker').close();render();};
function openHidden(){renderHidden();$('#hidden-dialog').showModal();}
function renderHidden(){
 $('#hidden-content').innerHTML=draft.hidden.length?draft.hidden.map(k=>`<div class="hidden-row"><span>${esc(selectorInfo(k).label)}<small>${k.startsWith('f:')?'Именованный':k.startsWith('c:')?'Категория':'Конкретный'}</small></span><button data-restore="${k}">Восстановить</button></div>`).join(''):'<p class="hint">Пока ничего не скрыто.</p>';
 $$('[data-restore]').forEach(b=>b.onclick=()=>{draft.hidden=draft.hidden.filter(k=>k!==b.dataset.restore);renderHidden();render();});
}
$('#hidden-list').onclick=openHidden;$('#add-hidden').onclick=()=>openPicker({type:'hide'});$('#restore-all').onclick=()=>{draft.hidden=[];renderHidden();render();};
function openSets(){renderSets();$('#set-dialog').showModal();}
function renderSets(){
 $('#set-content').innerHTML=`<div style="grid-column:1/-1"><label>Долгие от <input id="threshold" type="number" min="1" max="86400" value="${draft.threshold}" style="width:80px"> сек полной длительности</label><p class="hint">59 секунд остатка у часового бафа не меняют его группу.</p></div>`+draft.sets.map(s=>`<section class="set-card" data-set="${s.id}"><input aria-label="Имя набора ${s.id}" type="text" data-set-name value="${esc(s.name)}"><label>Тип ${selectHTML('kind-'+s.id,[['any','Бафы и дебафы'],['buff','Бафы'],['debuff','Дебафы']],s.kind)}</label><label>Именованные ${selectHTML('named-'+s.id,[['any','Любые'],['exclude','Исключить'],['only','Только они']],s.named)}</label><p class="hint">Любой из сроков или категорий:</p><div class="flags">${Object.entries(durationNames).map(([k,n])=>`<label><input type="checkbox" data-life="${k}" ${s.durations.includes(k)?'checked':''}>${n}</label>`).join('')}</div><div class="flags">${Object.entries(categoryNames).map(([k,n])=>`<label><input type="checkbox" data-category="${k}" ${s.categories.includes(k)?'checked':''}>${n}</label>`).join('')}</div><p class="hint">Исключить другой набор:</p>${selectHTML('exclude-'+s.id,[['','Без исключения'],...draft.sets.filter(a=>a.id!==s.id).map(a=>[a.id,a.name])],s.exclude[0]||'')}<div class="set-equation">${observations.filter(e=>matchesSet(e,s.id)).length} совпадений ${s.exclude.length?'· минус '+esc(draft.sets.find(a=>a.id===s.exclude[0])?.name||''):''}</div></section>`).join('');
 $('#threshold').onchange=()=>{draft.threshold=clamp($('#threshold').value,1,86400);renderSets();render();};
 $$('.set-card').forEach(card=>{
  const s=draft.sets.find(s=>s.id===card.dataset.set);
  card.querySelector('[data-set-name]').onchange=e=>{s.name=e.target.value;renderSets();render();};
  $('#kind-'+s.id).onchange=e=>{s.kind=e.target.value;renderSets();render();};$('#named-'+s.id).onchange=e=>{s.named=e.target.value;renderSets();render();};
  for(const [attr,prop]of[['data-life','durations'],['data-category','categories']])card.querySelectorAll('['+attr+']').forEach(n=>n.onchange=()=>{const v=n.getAttribute(attr);s[prop]=n.checked?[...s[prop],v]:s[prop].filter(x=>x!==v);renderSets();render();});
  $('#exclude-'+s.id).onchange=e=>{const other=e.target.value;const depends=(id,seen=new Set())=>{if(id===s.id)return true;if(seen.has(id))return false;seen.add(id);return draft.sets.find(a=>a.id===id)?.exclude.some(x=>depends(x,seen));};if(other&&depends(other)){toast('Это создаёт цикл исключений. Выбери другой набор.');renderSets();return;}s.exclude=other?[other]:[];renderSets();render();};
 });
}
$('#sets').onclick=openSets;$('#add-set').onclick=()=>{draft.sets.push({id:'set-'+Date.now(),name:'Мой набор',kind:'any',named:'any',durations:['short'],categories:[],exclude:[]});renderSets();render();};
updateViewport();render();enter();
