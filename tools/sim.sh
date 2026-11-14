#!/usr/bin/env bash
# Headless check of the tracker's decay rates. Runs the real simulation code from
# sw_survival_tracker.html in macOS's built-in JavaScriptCore (no install needed),
# with a stub DOM, and prints time-to-tier for every need plus a smoke test of the
# UI code paths. Run it after changing any constant:
#
#   ./tools/sim.sh                 # checks sw_survival_tracker.html
#   ./tools/sim.sh index.html      # or any other copy
set -euo pipefail
cd "$(dirname "$0")/.."
SRC="${1:-sw_survival_tracker.html}"
JSC=/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/Helpers/jsc
OUT="$(mktemp -t survival-sim).js"
trap 'rm -f "$OUT"' EXIT
{
cat <<'STUB'
/* ---- stub browser: just enough DOM for render()/buildRules() to run ---- */
const __els = {};
const __el = () => new Proxy({style:{}, dataset:{}, classList:{add(){},remove(){}}}, {
  get(t,k){ if(k in t) return t[k]; if(typeof k==='string' && /^(appendChild|addEventListener|focus|click|closest|querySelector)$/.test(k)) return ()=>__el(); return ''; },
  set(t,k,v){ t[k]=v; return true; }
});
var document = { getElementById:id=>(__els[id] ??= __el()), createElement:()=>__el(), addEventListener(){}, activeElement:null };
var window = { addEventListener(){} }, location = { hash:'', href:'', pathname:'', search:'' }, history = { replaceState(){} };
var navigator = {}, localStorage = { getItem:()=>null, setItem(){} };
var Image = function(){ Object.defineProperty(this,'src',{ set(){ this.onerror && this.onerror(); } }); };
var setInterval = ()=>0, setTimeout = ()=>0, clearTimeout = ()=>0, alert = ()=>{}, prompt = ()=>null, confirm = ()=>true;
STUB
# the item catalog (the page loads it from items.js before its own script), then
# the tracker's script, minus its init() call
[ -f items.js ] && cat items.js
[ -f items-custom.js ] && cat items-custom.js
[ -f rules.js ] && cat rules.js
[ -f lore.js ] && cat lore.js
[ -f species.js ] && cat species.js
[ -f adversaries.js ] && cat adversaries.js
[ -f maps.js ] && cat maps.js
echo 'if(typeof MAPS==="undefined") var MAPS = [];'
sed -n '/^<script>$/,/^<\/script>$/p' "$SRC" | sed '1d;$d' | sed 's/^init();$//'
cat <<'TEST'
/* ---------------- measurements ---------------- */
const fresh = () => { S = freshState(); };
function tierTimes(id, key, act='light', env='temperate', hold={}){
  fresh(); S.env = env;
  const cs = st(id), tiers = NEEDS[key].tiers, hit = {};
  cs.activity = act;
  for(let h=1; h<=5000; h++){
    // pin every other need (and strain/wounds) so collapse, sleep-deprivation strain or
    // death can't confound the one measured; the sleep rows keep fatigue live so the
    // Exhausted→sleep coupling shows ("no rest breaks")
    for(const k of NEED_KEYS) if(k!==key && !(key==='sleep' && k==='rest')) cs[k]=0;
    cs.strain = 0; cs.wounds = 0;
    Object.assign(cs, hold);
    tick(cs, 1);
    for(const t of tiers) if(t.min>0 && hit[t.name]===undefined && cs[key] >= t.min) hit[t.name]=h;
    if(cs[key] >= 100) break;
  }
  return hit;
}
const span = h => h<48 ? `${h}h` : `${(h/24).toFixed(1)}d`;
const row = (label, hit) => print(label.padEnd(42) + Object.entries(hit).map(([n,h])=>`${n} ${span(h)}`).join(' · '));

print('=== ORGANIC NEEDS — time to reach each tier, no actions taken ===');
row('Cal thirst · light · temperate',     tierTimes('cal','water'));
row('Cal thirst · resting · temperate',   tierTimes('cal','water','resting'));
row('Cal thirst · light · hot',           tierTimes('cal','water','light','hot'));
row('Cal thirst · light · scorching',     tierTimes('cal','water','light','scorching'));
row('Cal thirst · strenuous · scorching', tierTimes('cal','water','strenuous','scorching'));
row('Cal thirst · light · frozen',        tierTimes('cal','water','light','frozen'));
row('Tann thirst · light · scorching',    tierTimes('tann','water','light','scorching'));
row('Cal hunger · light · temperate',     tierTimes('cal','hunger','light','temperate',{water:0}));
row('Cal hunger · resting · temperate',   tierTimes('cal','hunger','resting','temperate',{water:0}));
row('Bode hunger · light · temperate',    tierTimes('bode','hunger','light','temperate',{water:0}));
row('Pike hunger · light · temperate',    tierTimes('pike','hunger','light','temperate',{water:0}));
row('Kata hunger · light · temperate',    tierTimes('kata','hunger','light','temperate',{water:0}));
row('Cal hunger · light · frozen',        tierTimes('cal','hunger','light','frozen',{water:0}));
row('Cal hygiene · light · temperate',    tierTimes('cal','hygiene'));
row('Cal sleep · light (no rest breaks)', tierTimes('cal','sleep'));
row('Cal sleep · resting',                tierTimes('cal','sleep','resting'));
row('Cal sleep · sedentary (fatigue low)',tierTimes('cal','sleep','sedentary'));
row('Cal fatigue · light',                tierTimes('cal','rest'));
row('Cal fatigue · strenuous',            tierTimes('cal','rest','strenuous'));

print('\n=== WOUND CLOCKS (Cal, wt 12, other needs pinned at 0) ===');
(function(){ fresh(); const cs=st('cal'); cs.hunger=76; let h=0; while(cs.wounds<=cs.wt && h<2000){ cs.water=0; cs.sleep=0; cs.strain=0; tick(cs,1); h++; } print(`  starvation: wounds exceed threshold ${span(h)} after Emaciated — hunger meter then at ${Math.round(cs.hunger)} (Collapse = 100)`); })();
(function(){ fresh(); const cs=st('cal'); cs.water=76; let h=0; while(cs.wounds<=cs.wt && h<2000){ cs.sleep=0; cs.strain=0; tick(cs,1); h++; } print(`  dehydration: wounds exceed threshold ${span(h)} after Desiccated — thirst meter then at ${Math.round(cs.water)}`); })();

print('\n=== STRAIN THRESHOLD (needs shrink the pool; nothing ticks strain) ===');
(function(){ fresh(); const cs=st('cal'); cs.rest=60; cs.hunger=30; cs.sleep=60; cs.conds.push({id:'sick',lvl:2}); for(let h=0;h<6;h++){ cs.rest=60; tick(cs,1); } print(`  Weary + Famished + Sleep-Deprived + Sick 2: strain ${cs.strain} after 6 h walking, threshold ${cs.st} → ${effStrainThresh(cs,cfg('cal'))} (${strainMods(cs,cfg('cal')).map(([n,m])=>n+' '+m).join(', ')})`); })();
print('\n=== DRINKING ===');
for(const id of ['cal','bode','pike','kata']){ const c=cfg(id); print(`  ${c.name.padEnd(11)} ${String(c.waterOz).padStart(3)} oz/day · a ${OZ_PER_CANTEEN} oz canteen = −${ozToPts(c,OZ_PER_CANTEEN).toFixed(1)} thirst · a day of walking = ${(24*NEEDS.water.tiers[0].rate*(c.mods.waterRate||1)).toFixed(0)} pts = ${(24*NEEDS.water.tiers[0].rate*(c.mods.waterRate||1)/ozToPts(c,1)).toFixed(0)} oz`); }
(function(){ fresh(); const cs=st('cal'); cs.water=60; drink('cal',OZ_PER_CANTEEN); print(`  Dehydrated Cal gulps a full canteen: −${(60-cs.water).toFixed(1)} pts, ${cs.canteen} oz left in the canteen`); })();

print('\n=== DROIDS, EQUIPMENT, SHIP ===');
(function(){ fresh(); const cs=st('bd1'); let h=0; while(cs.charge<100&&h<2000){ tick(cs,1); h++; } print(`  BD-1 pack drained after ${h} h light duty (spec ${cfg('bd1').packHrs})`); })();
(function(){ fresh(); const cs=st('alpha'); let h=0; while(cs.maint<100&&h<9000){ cs.charge=0; tick(cs,1); h++; } print(`  Alpha wear 0→100 after ${span(h)} unmaintained light temperate duty`); })();
(function(){ fresh(); const cs=st('cal'); const it=cs.inv.find(i=>i.type==='Weapon'); it.eq=1; let h=0; while((it.wear||0)<100&&h<50000){ tick(cs,1); h++; } print(`  weapon ambient wear 0→100: ${span(h)} temperate · +${WEAR_PER_USE}/use ⇒ ${Math.ceil(100/WEAR_PER_USE)} hard uses`); })();
print(`  ship: ${SHIP.fuelCap} t ⇒ cruising ${(SHIP.fuelCap/SHIP_ACTS.cruising.tph/24).toFixed(0)} d · hyperspace ${(SHIP.fuelCap/SHIP_ACTS.hyperspace.tph).toFixed(0)} h · one condition pip per ${SHIP_MAINT_WEEK/24} d powered`);

print('\n=== SMOKE TEST — UI code paths ===');
(function(){
  fresh(); buildRules(); render();
  startStatus('cal','meal'); startStatus('merrin','med30'); startStatus('kata','sleep',10); startStatus('bode','wash');
  advance(0.25); advance(0.5); advance(1); advance(12);
  drink('cal',OZ_PER_CANTEEN); eatSnack('pike'); useStim('gibbs'); wipeDown('tann'); cleanClothes('cal'); setForce('cal',3); setAttr('cal','br',3);
  swapPack('bd1'); rechargeAll('bd1'); tuneUp('alpha'); overhaul('alpha');
  addCond('cal','sick'); condLvl('cal','sick',1); addCond('bd1','ion'); partySetAct('travel'); partyAddCond('chilled'); rmCond('cal','sick');
  setEnv('scorching'); document.getElementById('cdLabel').value='Travel to Koboh'; document.getElementById('cdTime').value='3'; counterAdd(); S.counters.push({id:'t2',label:'Ritual',hrs:parseDur('1d 12h'),total:36});
  setShipAct('cruising'); energyAdj('shields',-1); energyAdj('engines',1); setSensorRange('Long'); fireTorp(); shipBurn(); repairSys('engines',-1);
  invAdd('cal','Weapon','Test club'); invSet('cal', st('cal').inv.length-1, 'eq', true); useItem('cal', st('cal').inv.length-1); addCargo('cargo');
  showTab('items'); itemsSet('q','blaster pistol'); const hits = itemsFiltered().length; itemsSet('g','Gear'); itemsSet('c','Survival'); itemsSet('g',''); itemsSet('q','');
  hbAdd(); const hb = S.homebrew[0]; hbSet(hb.id,'n','Test Gadget'); hbSet(hb.id,'p','125'); hbSet(hb.id,'r',true); hbSet(hb.id,'e','abc'); hbSet(hb.id,'d','does a thing');
  giveItem('c0','cal'); giveItem('h'+hb.id,'bode'); itemsSet('q','test gadget'); const hbHit = itemsFiltered().length; itemsSet('q',''); hbDel(hb.id);
  advance(48); render();
  const items = document.getElementById('itemsBody').innerHTML, itemsBad = (items.match(/undefined|NaN|\[object/g)||[]).length;
  print(`  items: ${CATALOG.length} in catalog, ${hits} match "blaster pistol", homebrew round-trip ${hbHit===1?'ok':'FAILED'}, ${itemsBad} broken interpolations in the tab`);
  if(itemsBad || hbHit!==1 || !CATALOG.length) throw new Error('items tab smoke test failed');
  // countdowns: parse, tick with the clock, announce once, old travel timer converts
  if(parseDur('90m')!==1.5 || parseDur('2d')!==48 || parseDur('1d 12h')!==36 || parseDur('6')!==6 || parseDur('soon')!==0) throw new Error('parseDur wrong');
  const koboh = S.counters.find(c=>c.label==='Travel to Koboh'), rit = S.counters.find(c=>c.id==='t2');
  if(!koboh || koboh.hrs!==0 || rit.hrs!==0 || S.log.filter(l=>/Travel to Koboh<\/b> — countdown complete/.test(l.m)).length>1) throw new Error('countdowns did not run down: '+JSON.stringify(S.counters));
  S.counters.push({id:'t3',label:'Storm',hrs:5,total:5}); advance(2); if(S.counters.find(c=>c.id==='t3').hrs!==3) throw new Error('countdown tick wrong'); counterDel('t3'); counterDel('t2');
  const tOld = migrate({chars:[], ship:S.ship, log:[], travelDest:'Jedha', travelEta:4}); if(tOld.counters.length!==1 || tOld.counters[0].label!=='Travel to Jedha' || tOld.counters[0].hrs!==4 || tOld.travelDest!==undefined) throw new Error('old travel timer not converted');
  if(migrate(JSON.parse(JSON.stringify(syncSubset({...S, counters:[]})))).counters.length!==0) throw new Error('empty counters not restored');
  if(/undefined|NaN/.test(document.getElementById('counters').innerHTML)) throw new Error('counter chips broken');
  // sync: removing the LAST countdown must not be undone by the next room update (pruned keys vanish from the wire)
  const base0 = {hour:1, counters:[{id:'a',label:'Caf',hrs:2,total:2}], chars:[], ship:{}}, local0 = {hour:1, chars:[], ship:{}}, remote0 = {hour:2, counters:[{id:'a',label:'Caf',hrs:2,total:2}], chars:[], ship:{}};
  const m0 = threeWayMerge(base0, local0, remote0); if(m0.counters || m0.hour!==2) throw new Error('a removed last countdown came back in the merge');
  if(!threeWayMerge({hour:1,chars:[],ship:{}}, {hour:1,chars:[],ship:{}}, remote0).counters) throw new Error('merge dropped a countdown someone else added');
  // bags: the renamed pack type raises the threshold while carried
  const sv0 = S; fresh(); const pb0 = st('pike'), bag = pb0.inv.find(x=>x.type==='Bag'); if(!bag || packBonus(pb0)!==2 || effThresh(pb0)!==pb0.encThresh+2) throw new Error('bag capacity wrong');
  invSet('pike', pb0.inv.indexOf(bag), 'carry', false); if(packBonus(pb0)!==0) throw new Error('stowed bag still adds capacity'); invSet('pike', pb0.inv.indexOf(bag), 'carry', true);
  invAdd('pike','Gear','Backpack'); if(pb0.inv[pb0.inv.length-1].type!=='Bag') throw new Error('catalog backpack should land as a Bag');
  const pbB = packBonus(pb0); invAdd('pike','Gear','canvas backpack'); if(pb0.inv[pb0.inv.length-1].type!=='Bag' || packBonus(pb0)!==pbB+4) throw new Error('Canvas Backpack should add 4 to the threshold');
  if(migrate({chars:[{...JSON.parse(JSON.stringify(st('kata'))), inv:[{name:'Satchel',type:'Gear (pack)',qty:1,wt:3}]}], ship:S.ship, log:[]}).chars.find(x=>x.id==='kata').inv.find(x=>x.name==='Satchel').type!=='Bag') throw new Error('Gear (pack) not renamed to Bag');
  S = sv0;
  // dice: face counts, a known tally, the pool builder, a feed round-trip and the destiny pool
  const sizes = {b:6,k:6,a:8,d:8,p:12,c:12,F:12};
  for(const t in sizes) if(DICE[t].faces.length!==sizes[t]) throw new Error('die '+t+' has the wrong number of faces');
  const tl = tally(parseRoll('p:x p:sa a:aa d:ft d:tt c:y F:ll F:n zz:top a:bogus'));
  if(tl.netS!==0 || tl.netA!==0 || tl.x!==1 || tl.y!==1 || tl.l!==2 || tl.n!==1) throw new Error('dice tally wrong: '+JSON.stringify(tl));
  showTab('dice'); DICE_UI.who='cal'; DICE_UI.ch=6; DICE_UI.rk=5; poolSkill(); poolDiff(3); poolUpgrade('d','c'); poolAdj('b',1); poolAdj('F',2);
  const pl = DICE_UI.pool; if(pl.p!==5 || pl.a!==1 || pl.d!==2 || pl.c!==1) throw new Error('pool builder wrong: '+JSON.stringify(pl));
  DICE_UI.label='<b>Lightsaber</b>'; rollPool(); poolClear(); rollPool();
  destinyRoll(); destinyAdj('light',2); destinyAdj('dark',1); const dl=S.destiny.light, dd=S.destiny.dark; destinyUse('light'); destinyUse('dark'); destinyUse('dark');
  if(S.destiny.light!==dl+1 || S.destiny.dark!==dd-1 || dl+dd<4) throw new Error('destiny flips wrong');
  let big = 0; for(let i=0;i<20000;i++) big += tally(parseRoll(rollDice({p:1}))).s;   // proficiency die: 9 success symbols on 12 faces
  const feed = document.getElementById('diceFeed').innerHTML + document.getElementById('dicePool').innerHTML + document.getElementById('destinyChip').innerHTML;
  const diceBad = (feed.match(/undefined|NaN|\[object|<b>Lightsaber/g)||[]).length;
  print(`  dice: ${ROLLS.length} feed entries (1 roll, 1 pool roll, 3 flips), proficiency die averages ${(big/20000).toFixed(3)} successes (expect 0.750), destiny ${S.destiny.light} Light / ${S.destiny.dark} Dark, ${diceBad} broken interpolations`);
  if(diceBad || ROLLS.length!==5 || Math.abs(big/20000-9/12)>0.03) throw new Error('dice smoke test failed');
  // character sheet: skill pools, sparse storage, custom skills, wire round-trip, load into the dice tab
  showTab('sheet'); sheetPick('cal'); setAttr('cal','ag',6);
  sheetSkill('cal','lightsaber','ch','ag'); sheetSkill('cal','lightsaber','r',5); sheetSkill('cal','lightsaber','c',true);
  sheetSkill('cal','stealth','r',2); sheetSkill('cal','stealth','r',0);
  sheetSet('cal','career','<i>Warrior</i>'); sheetSet('cal','fr',3); setForce('cal',9); if(st('cal').force!==3) throw new Error('Force commit not capped at rating'); sheetSet('cal','fr',2); if(st('cal').force!==2) throw new Error('lowering rating did not release'); sheetSet('cal','fr',3); setForce('cal',1); setForce('bd1',1); sheetSet('cal','credits','1683550'); sheetSet('cal','soakMod',1);
  sheetAddSkill('cal'); const cu = st('cal').sheet.cust[0]; sheetCust('cal',cu.id,'n','Cybernetics'); sheetSkill('cal','x_'+cu.id,'r',1);
  const ls = skillState(st('cal'), SKILLS.find(x=>x.k==='lightsaber'));
  if(ls.p!==5 || ls.a!==1 || st('cal').sheet.sk.stealth) throw new Error('skill pool / sparse storage wrong');
  rollSkill('cal','lightsaber'); if(DICE_UI.pool.p!==5 || DICE_UI.pool.a!==1 || DICE_UI.pool.d!==2 || DICE_UI.who!=='cal') throw new Error('rollSkill wrong');
  rollForce('cal'); if(DICE_UI.pool.F!==2 || DICE_UI.pool.p!==0) throw new Error('rollForce wrong');
  const old = JSON.parse(JSON.stringify(syncSubset(S))); const oc = old.chars.find(x=>x.id==='bode'); delete oc.sheet; oc.force = 4;
  if(migrate(old).chars.find(x=>x.id==='bode').sheet.fr!==4) throw new Error('old save with 4 committed lost its commit');
  // equipped gear: catalog stats ride along, kit rows borrow them by name, soak/defense derive, attacks carry the weapon
  const cal = st('cal'), ci = k => 'c'+CATALOG.findIndex(x=>x.n===k);
  const saber = cal.inv.findIndex(x=>x.name==='Basic Lightsaber'), kitArmor = cal.inv.find(x=>x.type==='Armor');
  giveItem(ci('Vibroknife'),'cal'); const knife = cal.inv.length-1; if(cal.inv[knife].sk!=='melee' || !cal.inv[knife].brn || weaponState(cal,cal.inv[knife]).total!==1+cal.attr.br) throw new Error('catalog weapon stats wrong');
  const pistolRow = st('bode').inv.find(x=>x.name==='Blaster Pistol'), pw = weaponState(st('bode'), pistolRow);
  if(pw.sk!=='ranged_light' || pw.dam!==6 || pw.crit!==3 || pw.rng!=='Medium') throw new Error('kit weapon did not borrow catalog stats: '+JSON.stringify(pw));
  const soak0 = combatStats(cal).soak; invAdd('cal','Armor','beskar plating'); const ar = cal.inv.length-1; if(cal.inv[ar].ref!=='Beskar Plating' || cal.inv[ar].eq) throw new Error('custom armor not linked'); invSet('cal',ar,'eq',1);
  invSet('cal',knife,'q','Pierce 2, Defensive 1'); invSet('cal',knife,'eq',1);
  const cb1 = combatStats(cal); if(cb1.soak!==soak0+3 || cb1.defR!==2 || cb1.defM!==3) throw new Error('derived soak/defense wrong: '+JSON.stringify(cb1));
  invSet('cal',ar,'eq',0); if(combatStats(cal).soak!==soak0) throw new Error('stowed armor still counted');
  invSet('cal',saber,'dam',7); invSet('cal',saber,'crit',2); invSet('cal',saber,'q','Breach 1, <u>Sunder</u>'); rollAttack('cal',saber);
  if(!DICE_UI.weapon || DICE_UI.weapon.dam!==7 || DICE_UI.pool.p!==5 || DICE_UI.label!=='Lightsaber') throw new Error('rollAttack wrong: '+JSON.stringify(DICE_UI));
  const nBefore = ROLLS.length; rollPool(); const atk = ROLLS[ROLLS.length-1]; if(ROLLS.length!==nBefore+1 || !atk.w || atk.w.n!=='Lightsaber') throw new Error('attack roll lost its weapon');
  const card = weaponCardHtml({n:'<b>X</b>',dam:7,crit:2,q:'q'}, parseRoll('p:sa p:x a:a d:f'));
  if(!/7 \+ 1 = <b>8<\/b>/.test(card) || !/critical available/.test(card) || /<b>X/.test(card.replace('<div class="wcard"><b>','')) ) throw new Error('weapon card wrong: '+card);
  const wearB = cal.inv[saber].wear||0; rollAttack('cal',saber); rollPool(); if(Math.abs((cal.inv[saber].wear||0)-(wearB+WEAR_PER_ATTACK))>1e-9) throw new Error('attack did not wear the weapon');
  if(ROLLS[ROLLS.length-1].w.src || ROLLS[ROLLS.length-1].w.note!==undefined) throw new Error('weapon source leaked into the feed');
  cal.inv[saber].wear = 85; rollAttack('cal',saber); if(DICE_UI.pool.k!==2 || DICE_UI.pool.c!==1 || DICE_UI.pool.d!==1) throw new Error('failing weapon penalties not applied: '+JSON.stringify(DICE_UI.pool));
  cal.inv[saber].wear = 100; poolClear(); rollAttack('cal',saber); if(DICE_UI.weapon) throw new Error('broken weapon could attack'); cal.inv[saber].wear = 0;
  rollSkill('cal','stealth'); if(DICE_UI.weapon) throw new Error('weapon stuck to a skill roll');
  // inventory overhaul: kits link to the database, aliases survive, food buttons eat whole items of their type
  const sb = cal.inv[saber]; if(sb.ref!=='Basic Lightsaber' || sb.alias!=='Lightsaber' || invLabel(sb)!=='Lightsaber') throw new Error('kit lightsaber not linked with alias: '+JSON.stringify(sb));
  const unl = S.chars.flatMap(x=>x.inv.filter(it=>!it.auto && it.name!=='Test club' && it.name!=='Test Gadget' && !dbOf(it)).map(it=>x.id+':'+it.name)); if(unl.length) throw new Error('kit items with no database match: '+unl.join(', '));
  const keepS = S; fresh(); const pk = st('pike'); let r0 = stockOf(pk,'Ration'), s0 = stockOf(pk,'Snack'), t0 = stockOf(pk,'Stim');
  if(r0!==6 || s0!==4 || t0!==5 || stockOf(pk,'Meal')!==0) throw new Error('starting stock wrong');
  pk.hunger = 40; startStatus('pike','ration'); if(stockOf(pk,'Ration')!==5 || !pk.status) throw new Error('ration not eaten from inventory');
  cancelStatus('pike'); if(stockOf(pk,'Ration')!==6) throw new Error('untouched ration not returned');
  startStatus('pike','ration'); advance(0.25); if(stockOf(pk,'Ration')!==5) throw new Error('eaten ration came back');
  startStatus('pike','meal'); if(pk.status) throw new Error('ate a meal with no Meal items');
  invAdd('pike','Gear','meal'); if(pk.inv[pk.inv.length-1].type!=='Meal') throw new Error('Meal entry did not land as type Meal'); startStatus('pike','meal'); if(!pk.status || stockOf(pk,'Meal')!==0) throw new Error('meal not eaten'); advance(0.5);
  eatSnack('pike'); useStim('pike'); if(stockOf(pk,'Snack')!==3 || stockOf(pk,'Stim')!==4) throw new Error('snack/stim not taken from inventory');
  invAdd('pike','Gear','Mystery widget'); const mw = pk.inv.length-1; if(dbOf(pk.inv[mw])) throw new Error('unknown item linked'); invSet('pike',mw,'alias','Gizmo'); invCreateEntry('pike',mw);
  if(!dbOf(pk.inv[mw]) || S.homebrew.length!==1 || invLabel(pk.inv[mw])!=='Gizmo') throw new Error('create-entry did not link');
  invSet('pike',mw,'db','datapad'); if(pk.inv[mw].ref!=='Datapad' || pk.inv[mw].wt!==1) throw new Error('re-pointing an item did not import stats');
  // carry / equip: stowed items leave the card, the weight and the stock; equipping needs carrying; Gear (worn) became the Eq tick
  invSet('pike',mw,'eq',1); if(isEquipped(pk.inv[mw])) throw new Error('gear should not be equippable');
  const dp = pk.inv[mw], wBefore = invWeight(pk); invAdd('pike','Weapon','Vibroknife'); const vk = pk.inv.length-1; invSet('pike',vk,'eq',1); if(!isEquipped(pk.inv[vk])) throw new Error('equip failed'); invSet('pike',vk,'carry',false); if(pk.inv[vk].eq) throw new Error('stowing did not unequip'); delInv('pike',vk);
  invSet('pike',mw,'carry',false); if(isCarried(dp) || dp.eq || Math.abs(invWeight(pk)-(wBefore-1))>1e-9) throw new Error('stowing did not unequip / unweigh');
  invSet('pike',mw,'eq',1); if(dp.eq) throw new Error('equipped a stowed item');
  const rr = stockRows(pk,'Ration')[0], rN = stockOf(pk,'Ration'); invSet('pike',pk.inv.indexOf(rr),'carry',false); if(stockOf(pk,'Ration')!==0) throw new Error('stowed rations still edible'); invSet('pike',pk.inv.indexOf(rr),'carry',true); if(stockOf(pk,'Ration')!==rN) throw new Error('carry toggle lost rations');
  render(); if(/Datapad/.test(invSection(pk)) || /stowed|edit on sheet/.test(invSection(pk)) || !/Multitool/.test(invSection(pk))) throw new Error('card inventory should list carried items only');
  const wornOld = migrate({chars:[{...JSON.parse(JSON.stringify(st('kata'))), inv:[{name:'Goggles',type:'Gear (worn)',qty:1,wt:0.2,wear:30}]}], ship:S.ship, log:[], homebrew:[]}).chars.find(x=>x.id==='kata').inv.find(x=>x.name==='Goggles');
  if(wornOld.type!=='Gear' || isEquipped(wornOld) || wornOld.wear!==30) throw new Error('Gear (worn) not converted to an equipped item');
  const wi = st('cal').inv.findIndex(isWeapon), wv = st('cal').inv[wi]; invSet('cal',wi,'carry',true); invSet('cal',wi,'eq',1); wv.wear = 42; invSet('cal',wi,'eq',0); tick(st('cal'),24); invSet('cal',wi,'carry',false); invSet('cal',wi,'carry',true); invSet('cal',wi,'eq',1);
  if(wv.wear!==42) throw new Error('wear changed across unequip / stow / re-equip: '+wv.wear);
  invAdd('cal','Armor','Laminate Armour'); const lam = st('cal').inv[st('cal').inv.length-1], li = st('cal').inv.length-1, so = combatStats(st('cal')).soak;
  invSet('cal',li,'eq',1); if(combatStats(st('cal')).soak!==so+2) throw new Error('fresh armor soak wrong'); tick(st('cal'),240); if(!(lam.wear>0)) throw new Error('equipped armor gathered no wear');
  lam.wear = 65; if(combatStats(st('cal')).soak!==so+1 || armorState(lam).tier.name!=='Faulty') throw new Error('Faulty armor should lose 1 soak'); lam.wear = 100; if(combatStats(st('cal')).soak!==so) throw new Error('Broken armor still protects');
  lam.def = 2; lam.wear = 45; if(armorState(lam).def!==1 || armorState(lam).soak!==2) throw new Error('Scuffed armor should lose 1 defense only'); useItem('cal',li); delInv('cal',li);
  const hook = st('cal').inv.find(x=>x.name==='Grappling Hook'); hook.eq = 1; hook.wear = 0; tick(st('cal'),240); if(!isTool(hook) || !isEquipped(hook) || !(hook.wear>0)) throw new Error('an equipped tool should gather wear');
  const pad = st('cal').inv.find(x=>x.name==='Datapad'); pad.eq = 1; pad.wear = 0; tick(st('cal'),240); if(isEquipped(pad) || pad.wear!==0) throw new Error('plain gear gathered wear');
  invAdd('cal','Gear','wig'); invAdd('cal','Armor','combat-rated eva suit'); const eva = st('cal').inv[st('cal').inv.length-1], wig = st('cal').inv[st('cal').inv.length-2];
  if(wig.ref!=='Wig' || eva.ref!=='Combat-Rated EVA Suit' || eva.type!=='Armor' || armorState(eva).soak!==2) throw new Error('new custom items not linked');
  if(!/Field rations/.test(invSection(st('cal')).split('Consumables')[1].split('Gear')[0])) throw new Error('rations should sit under Consumables on the card');
  const cardInv = invSection(st('cal')); if((cardInv.match(/<details/g)||[]).length!==6 || !/class="inv invall"/.test(cardInv) || !/🎒 Inventory/.test(cardInv) || !/repairs by/.test(cardInv) || !/Consumables/.test(cardInv) || !/Tools/.test(cardInv) || !/Weapons/.test(cardInv) || !/Armor/.test(cardInv) || /undefined|NaN/.test(cardInv)) throw new Error('card should have an Inventory dropdown holding five more');
  const crate = gearHtml(st('cal')); if(!/Personal Item Storage Crate/.test(crate) || (crate.match(/<details/g)||[]).length!==6 || !/Consumables/.test(crate) || /undefined|NaN/.test(crate)) throw new Error('sheet inventory should be a crate with three dropdowns');
  sheetOpen('armor',false); if(/<details class="sfold" open[^>]*'armor'/.test(gearHtml(st('cal'))) || !/<details class="sfold" open[^>]*'weapons'/.test(gearHtml(st('cal')))) throw new Error('dropdown open state not remembered'); sheetOpen('armor',true);
  const ordC = [...invSection(st('cal')).split('🎒 Gear')[1].matchAll(/<td><span class="[a-z]*" title="[^"]*">([^<]+)</g)].map(m=>m[1]); if(ordC.length<3 || ordC.join('|')!==[...ordC].sort((a,b)=>a.localeCompare(b,undefined,{sensitivity:'base',numeric:true})).join('|')) throw new Error('card gear not alphabetical: '+ordC.join(', '));
  const invBefore = JSON.stringify(st('cal').inv.map(x=>x.name)); render(); if(JSON.stringify(st('cal').inv.map(x=>x.name))!==invBefore) throw new Error('sorting changed the stored order');
  const svC = S; fresh(); const kc = st('gibbs'); if(crateWeight(kc)!==0) throw new Error('nothing stowed should weigh nothing');
  const rifle = kc.inv.findIndex(x=>x.name==='Blaster Rifle'); invSet('gibbs',rifle,'carry',false); if(crateWeight(kc)!==2) throw new Error('stowed rifle should count its enc');
  invAdd('gibbs','Armor','Laminate Armour'); const la = kc.inv.length-1; if(crateWeight(kc)!==2) throw new Error('carried armor should not count'); invSet('gibbs',la,'carry',false); if(crateWeight(kc)!==6) throw new Error('stowed armor should count in full: '+crateWeight(kc));
  invAdd('gibbs','Gear','Canvas Backpack'); invSet('gibbs',kc.inv.length-1,'carry',false); if(crateWeight(kc)!==7) throw new Error('stowed bag should count 1');
  invSet('gibbs',la,'qty',8); const ch = gearHtml(kc); if(crateWeight(kc)!==35 || !/over capacity/.test(ch) || /undefined|NaN/.test(ch)) throw new Error('over-capacity warning missing');
  S = svC;
  // timed repairs + Mechanics check: the job runs on the mechanic's clock, then a roll decides the wear
  const svR = S; fresh(); const rc = st('gibbs'), ri = rc.inv.findIndex(isWeapon), rw = rc.inv[ri]; rw.eq = 1; rw.wear = 50;
  const T = str => tally(parseRoll(str));
  tuneItem('gibbs',ri); if(rw.wear!==50 || !rc.status || rc.status.kind!=='tuneup') throw new Error('tune-up should not be instant');
  cancelStatus('gibbs'); advance(1); if(Math.round(rw.wear)!==50 || rc.repair) throw new Error('a cancelled tune-up still counted');
  rw.wear = 50; tuneItem('gibbs',ri); advance(0.25); if(rc.status || !rc.repair || Math.round(rw.wear)!==50) throw new Error('finished tune-up should wait for the roll');
  if(!/roll Mechanics/.test(statusBadge(rc)) || /undefined|NaN/.test(statusBadge(rc))) throw new Error('pending-roll badge missing');
  rollRepair('gibbs'); if(!DICE_UI.repair || DICE_UI.who!=='gibbs' || DICE_UI.pool.d!==1 || DICE_UI.pool.k!==1 /* Gibbs carries no tools */) throw new Error('repair pool wrong: '+JSON.stringify(DICE_UI.pool));
  const w0 = rw.wear, txt = applyRepair('gibbs', T('a:ss a:s d:f')); if(Math.abs(rw.wear-(w0-GEAR_TUNEUP-REPAIR_EXTRA_PER_SUCCESS))>0.01 || rc.repair || !/Success/.test(txt)) throw new Error('tune-up success wrong: '+rw.wear+' '+txt);
  rw.wear = 50; tuneItem('gibbs',ri); advance(0.25); applyRepair('gibbs', T('a: d:f c:y')); if(Math.abs(rw.wear-(50+REPAIR_DESPAIR_WEAR))>0.2) throw new Error('failed tune-up with Despair should add wear: '+rw.wear);
  rw.wear = 80; overhaulItem('gibbs',ri); advance(0.5); if(!rc.status) throw new Error('overhaul finished early'); advance(0.5); if(rc.status || !rc.repair) throw new Error('overhaul should be waiting for the roll after 1 hr');
  rollRepair('gibbs'); if(DICE_UI.pool.d!==4) throw new Error('overhaul of a Failing item should be Daunting'); poolClear();
  const w1 = rw.wear; applyRepair('gibbs', T('a: d:f')); if(Math.abs(rw.wear-w1/2)>0.01) throw new Error('failed overhaul should clear half');
  rw.wear = 80; overhaulItem('gibbs',ri); advance(1); applyRepair('gibbs', T('p:x d:')); if(rw.wear!==0) throw new Error('overhaul success should clear wear');
  // another character does the work: the job and the roll sit on the mechanic
  setMech('gibbs','tann'); rw.wear = 40; tuneItem('gibbs',ri); const tn = st('tann'); if(rc.status || !tn.status || tn.status.item.owner!=='gibbs') throw new Error('job should be on the mechanic');
  advance(0.25); if(!tn.repair || rc.repair) throw new Error('pending roll should be on the mechanic'); rollRepair('tann'); if(DICE_UI.who!=='tann' || DICE_UI.pool.k!==0 /* Tann has a tool kit */) throw new Error('mechanic should roll');
  const fN = ROLLS.length; rollPool(); if(tn.repair || ROLLS.length!==fN+1 || !ROLLS[ROLLS.length-1].rep || DICE_UI.repair) throw new Error('rolling the pool should apply the repair');
  if(!S.log.some(l=>/tune-up of Gibbs/.test(l.m))) throw new Error('repair outcome not logged');
  rw.wear = 30; tuneItem('gibbs',ri); const backR = migrate(JSON.parse(JSON.stringify(syncSubset(S)))); if(!backR.chars.find(x=>x.id==='tann').status.item || backR.chars.find(x=>x.id==='gibbs').mech!=='tann') throw new Error('repair status / mechanic lost on the wire');
  cancelStatus('tann'); setMech('gibbs','');
  // droids: 30 min / 2 hr on the bench, then the roll
  tuneUp('bd1'); const dv = {innerHTML:'',className:''}; droidCard(st('bd1'), cfg('bd1'), dv); if(!/Tune-up — 30 min left/.test(dv.innerHTML)) throw new Error('droid card should show the repair badge'); cancelStatus('bd1');
  const dr = st('alpha'); dr.maint = 60; dr.conds.push({id:'corroded',lvl:1}); tuneUp('alpha'); if(dr.maint!==60 || !dr.status || activeAct(dr)!=='resting') throw new Error('droid tune-up should be a timed bench job');
  advance(0.25); if(!dr.status) throw new Error('droid tune-up finished early'); advance(0.25); if(dr.status || !dr.repair) throw new Error('droid tune-up should wait for the roll after 30 min');
  setMech('alpha','tann'); rollRepair('alpha'); if(DICE_UI.who!=='tann') throw new Error("the droid's mechanic should roll"); poolClear();
  const mt0 = dr.maint; applyRepair('alpha', T('a:s d:')); if(Math.abs(dr.maint-(mt0-TUNEUP))>0.01 || dr.conds.some(x=>x.id==='corroded')) throw new Error('droid tune-up success wrong: '+dr.maint);
  dr.maint = 90; overhaul('alpha'); advance(1.75); if(!dr.status) throw new Error('droid overhaul finished early'); advance(0.25); applyRepair('alpha', T('a:s d:')); if(dr.maint!==0) throw new Error('droid overhaul success should clear wear');
  const ar2 = st('gibbs'); invAdd('gibbs','Armor','Laminate Armour'); const ai2 = ar2.inv.length-1; invSet('gibbs',ai2,'eq',1); ar2.inv[ai2].wear = 70; overhaulItem('gibbs',ai2); advance(1); applyRepair('gibbs', T('a:s d:')); if(ar2.inv[ai2].wear!==0) throw new Error('armor overhaul should clear wear on a success');
  repairDrop('gibbs');
  S = svR;
  if(INV_TYPES.includes('Gear (worn)')) throw new Error('Gear (worn) type still offered');
  render(); const invHtml = document.getElementById('sheetBody').innerHTML + document.getElementById('cards').innerHTML;
  if(/undefined|NaN|\[object/.test(invHtml)) throw new Error('broken interpolation in the inventory views');
  // an old save (counters + auto rows) converts once; an un-refreshed browser re-sending the counters is ignored
  const legacy = JSON.parse(JSON.stringify(syncSubset(S))); const lg = legacy.chars.find(x=>x.id==='gibbs');
  delete lg.invV; lg.inv = [{name:'Blaster rifle',type:'Weapon',qty:1,wt:2},{name:'Jerky',type:'Food',qty:2,wt:0.1},{auto:'rations',name:'Field rations',type:'Food',qty:3.5,wt:0.2},{auto:'snacks',name:'Snacks',type:'Food',qty:7,wt:0.05},{auto:'stims',name:'Stimpacks',type:'Medical',qty:2,wt:0.05}];
  lg.rationsStock = 3.5; lg.snacks = 7; lg.stims = 2;
  const g2 = migrate(legacy).chars.find(x=>x.id==='gibbs');
  if(stockOf(g2,'Ration')!==6 /* 4 rounded + 2 jerky */ || stockOf(g2,'Snack')!==7 || stockOf(g2,'Stim')!==2 || g2.inv.some(it=>LEGACY_AUTO.includes(it.auto)) || g2.rationsStock!==undefined || g2.inv[0].ref!=='Blaster Rifle' || g2.inv[0].wt!==2) throw new Error('legacy inventory conversion wrong: '+JSON.stringify(g2.inv));
  const echo = JSON.parse(JSON.stringify(g2)); echo.rationsStock = 6; echo.inv.push({auto:'rations',name:'Field rations',type:'Food',qty:6,wt:0.2});
  const sub = syncSubset({chars:[echo]}).chars[0]; if(sub.rationsStock!==undefined || sub.inv.some(it=>it.auto==='rations')) throw new Error('legacy echo not stripped from the wire');
  const g3 = migrate({chars:[echo], ship:keepS.ship, log:[], homebrew:[]}).chars.find(x=>x.id==='gibbs'); if(stockOf(g3,'Ration')!==6) throw new Error('legacy echo converted twice');
  print(`  inventory: every kit item links to the database (${CUSTOM_ITEMS.length} custom entries), food and stims come out of inventory rows, old saves convert once`);
  S = keepS;
  const oldS = JSON.parse(JSON.stringify(syncSubset(S))); const og = oldS.chars.find(x=>x.id==='gibbs'); og.sheet.soak = 5; og.sheet.defR = 1; delete og.sheet.soakMod; delete og.sheet.defRMod;
  const ng = migrate(oldS).chars.find(x=>x.id==='gibbs'); if(combatStats(ng).soak!==5 || combatStats(ng).defR!==1 || ng.sheet.soak!==undefined) throw new Error('old typed soak/defense not carried over');
  document.getElementById('diceFeed').innerHTML.includes('<u>Sunder') && (()=>{ throw new Error('weapon qualities not escaped in the feed'); })();
  delInv('cal',ar); delInv('cal',knife);
  const shBack = migrate(JSON.parse(JSON.stringify(syncSubset(S)))).chars.find(x=>x.id==='cal').sheet;
  const bdBack = migrate(JSON.parse(JSON.stringify(syncSubset(S)))).chars.find(x=>x.id==='bd1').sheet;
  if(!same(prune(JSON.parse(JSON.stringify(shBack))), prune(JSON.parse(JSON.stringify(st('cal').sheet)))) || !bdBack.sk || !Array.isArray(bdBack.cust)) throw new Error('sheet wire round-trip wrong');
  render(); const shHtml = document.getElementById('sheetBody').innerHTML + document.getElementById('sheetChips').innerHTML;
  const shBad = (shHtml.match(/undefined|NaN|\[object|<i>Warrior/g)||[]).length;
  print(`  sheet: ${SKILLS.length} skills + ${st('cal').sheet.cust.length} custom, Cal Lightsaber (Ag 6, rank 5) → ${ls.p} Proficiency + ${ls.a} Ability, ${shBad} broken interpolations`);
  if(shBad) throw new Error('sheet smoke test failed');
  sheetDelSkill('cal',cu.id);
  // trees: add a specialization, buy along the paths, refund without stranding, Force power prerequisites, wire round-trip
  (()=>{
    const keep = JSON.stringify(S), cal = st('cal'), sh = cal.sheet;
    if(RULES_DB.trees.length<150 || !TREE_BY['healer'] || !TREE_BY['fp-move'] || !RULES_DB.talents['Grit']) throw new Error('rules.js did not load');
    for(const t of RULES_DB.trees){
      if(!t.nodes.some(n=>n.root)) throw new Error('tree with no starting box: '+t.id);
      for(const n of t.nodes){ if(n.x<0 || n.x+n.w>4 || n.y<0 || n.y>=t.rows) throw new Error('box off the grid: '+t.id+' '+n.id); for(const x of n.to) if(!t.by[x] || !t.by[x].to.includes(n.id)) throw new Error('one-way path: '+t.id+' '+n.id); }
      const seen = new Set(t.nodes.filter(n=>n.root).map(n=>n.id)), q = [...seen]; while(q.length) for(const x of t.by[q.pop()].to) if(!seen.has(x)){ seen.add(x); q.push(x); }
      if(seen.size!==t.nodes.length) throw new Error('unreachable box in '+t.id);
      const cells = new Set(); for(const n of t.nodes) for(let i=0;i<n.w;i++){ const c = n.y+':'+(n.x+i); if(cells.has(c)) throw new Error('overlapping boxes in '+t.id+' at '+c); cells.add(c); }
    }
    sh.tr = {}; sh.xp = 100; sh.career = 'Consular'; sh.specs = ''; sh.fr = 1;
    const H = TREE_BY['healer'];
    if(treeBuy('cal','healer','r1c1')) throw new Error('bought a talent without the specialization');
    if(specCost(cal,H)!==0 || !specAdd('cal','healer') || sh.xp!==100 || sh.specs!=='Healer') throw new Error('first specialization should be free');
    if(specCost(cal,TREE_BY['arbiter-consular'])!==20 || specCost(cal,TREE_BY['ataru-striker'])!==30 || specCost(cal,RULES_DB.trees.find(t=>t.career==='Universal'))!==20) throw new Error('specialization cost wrong');
    if(treeBuy('cal','healer','r2c1')) throw new Error('bought a row-2 talent with nothing above it');
    if(!treeBuy('cal','healer','r1c1') || !treeBuy('cal','healer','r2c1') || !treeBuy('cal','healer','r2c2') || sh.xp!==75) throw new Error('buying along a path failed');
    if(treeRefund('cal','healer','r1c1')) throw new Error('refund stranded r2c1');
    if(!treeBuy('cal','healer','r1c2') || !treeRefund('cal','healer','r1c1') || sh.xp!==75) throw new Error('refund with another route failed');
    const ph = talentRanks(cal).find(r=>r.n==='Physician'); if(!ph || ph.rank!==2) throw new Error('ranks not added up');
    sh.xp = 5; if(treeBuy('cal','healer','r3c1')) throw new Error('bought with too little XP'); sh.xp = 100;
    sh.fr = 0; if(treeBuy('cal','fp-move','basic')) throw new Error('bought a Force power with Force rating 0'); sh.fr = 1;
    if(treeBuy('cal','fp-move','r1c1') || !treeBuy('cal','fp-move','basic') || !treeBuy('cal','fp-move','r1c1') || sh.xp!==85) throw new Error('Force power purchase order wrong');
    if(treeRefund('cal','fp-move','basic') || !treeRefund('cal','fp-move','r1c1') || !treeRefund('cal','fp-move','basic') || sh.tr['fp-move'] || sh.xp!==100) throw new Error('Force power refund wrong');
    specAdd('cal','arbiter-consular'); if(sh.xp!==80 || xpSpentOnTrees(cal)!==45) throw new Error('second specialization should cost 20');
    const back = migrate(JSON.parse(JSON.stringify(syncSubset(S)))).chars.find(x=>x.id==='cal').sheet.tr;
    if(!back['arbiter-consular'] || !back.healer.r2c1 || back.healer.r1c1) throw new Error('trees lost on the wire');
    SHEET_UI.id = 'cal'; render(); const shT = document.getElementById('sheetBody').innerHTML;
    if(!/Talents &amp; Force Powers/.test(shT) || !/Physician/.test(shT) || !/rank 2/.test(shT)) throw new Error('sheet talents section missing');
    treesFor('cal','healer'); const tv = document.getElementById('treeView').innerHTML + document.getElementById('treeList').innerHTML;
    let tBad = (tv.match(/undefined|NaN|\[object/g)||[]).length;
    for(const t of RULES_DB.trees) tBad += (treeHtml(t, cal).match(/undefined|NaN|\[object/g)||[]).length + (treeHtml(t, null).match(/undefined|NaN|\[object/g)||[]).length;
    if(tBad || !/tnode own/.test(tv)) throw new Error('trees tab smoke test failed');
    // Grit / Toughened / Dedication / Force Rating change the sheet when bought and change it back on refund
    { const st0 = cal.st, wt0 = cal.wt, fr0 = sh.fr, ag0 = cal.attr.ag, br0 = cal.attr.br, xp0 = (sh.xp = 500), tr0 = JSON.stringify(sh.tr);
      const A = 'arbiter-consular';   // r1c3 Grit → r2c3 Toughened → r3c3 → r4c3 → r5c3 Dedication → r5c2 → r5c1 Force Rating
      for(const nid of ['r1c3','r2c3','r3c3','r4c3']) if(!treeBuy('cal',A,nid)) throw new Error('could not buy '+nid);
      if(cal.st!==st0+1 || cal.wt!==wt0+2) throw new Error('Grit / Toughened not applied');
      if(treeBuy('cal',A,'r5c3') || sh.tr[A].r5c3) throw new Error('Dedication bought with no characteristic chosen');
      if(treeBuy('cal',A,'r5c3','nonsense')) throw new Error('Dedication accepted a bad characteristic');
      cal.attr.ag = 6; if(treeBuy('cal',A,'r5c3','agility')) throw new Error('Dedication raised a characteristic past 6'); cal.attr.ag = ag0;
      if(!treeBuy('cal',A,'r5c3','Brawn') || cal.attr.br!==br0+1 || cal.encThresh!==cal.attr.br+5 || sh.tr[A].r5c3!=='br') throw new Error('Dedication not applied');
      if(!treeBuy('cal',A,'r5c2') || !treeBuy('cal',A,'r5c1') || sh.fr!==fr0+1) throw new Error('Force Rating not applied');
      const wire = migrate(JSON.parse(JSON.stringify(syncSubset(S)))).chars.find(x=>x.id==='cal'); if(wire.sheet.tr[A].r5c3!=='br' || wire.sheet.tr[A].r1c3!==2 || wire.st!==st0+1) throw new Error('applied talents lost on the wire');
      sh.tr[A].r1c3 = 1;   // a Grit bought before auto-apply existed: refunding it must not take a point away
      for(const nid of ['r5c1','r5c2','r5c3','r4c3','r3c3','r2c3','r1c3']) if(!treeRefund('cal',A,nid)) throw new Error('could not refund '+nid);
      if(cal.st!==st0+1 || cal.wt!==wt0 || sh.fr!==fr0 || cal.attr.br!==br0 || sh.xp!==xp0) throw new Error('refund did not undo exactly what was applied');
      cal.st = st0; treeBuy('cal',A,'r1c3'); treeBuy('cal',A,'r2c3'); specRemove('cal',A); if(cal.st!==st0 || cal.wt!==wt0) throw new Error('removing a specialization did not undo its talents');
      specAdd('cal',A,true); sh.tr = JSON.parse(tr0); sh.xp = 80; sh.specs = 'Healer, Arbiter'; }
    { const ps = TREE_BY['padawan-survivor-universal'], fr0 = sh.fr; if(ps.grantFr!==1 || ps.skills.join()!=='Deception,Stealth,Streetwise,Vigilance' || !ps.hbSkills || TREE_BY['force-sensitive-exile-universal'].skills.length) throw new Error('Padawan Survivor should grant Force rating 1 and its house-rule skills'); sh.fr = 0; const dc0 = (sh.sk.deception||{}).c; specAdd('cal',ps.id,true); if(!sh.sk.deception.c || !sh.sk.streetwise.c) throw new Error('house-rule career skills not ticked'); if(!dc0) skCareer(sh,'deception',false); skCareer(sh,'streetwise',false); if(sh.fr!==1 || !/Grants Force rating 1/.test(treeHtml(ps, cal))) throw new Error('Force rating not granted'); specRemove('cal',ps.id); sh.fr = fr0; }
    { const bg = 'bodyguard-hired-gun', sm0 = sh.soakMod, x0 = sh.xp; sh.xp = 500; specAdd('cal',bg,true); for(const n of ['r1c2','r2c2','r2c1','r3c1','r4c1']) treeBuy('cal',bg,n); if(sh.soakMod!==sm0+1) throw new Error('Enduring should add 1 soak'); treeRefund('cal',bg,'r4c1'); if(sh.soakMod!==sm0) throw new Error('refunding Enduring should take the soak back'); specRemove('cal',bg); for(const n of TREE_BY[bg].skills){ const k = skillKeyByName(n); if(k && sh.sk[k] && !sh.sk[k].r) delete sh.sk[k]; } sh.xp = x0; sh.specs = sh.specs.replace(/,? ?Bodyguard/,''); }
    specRemove('cal','healer'); if(sh.xp!==105 || sh.tr.healer || /Healer/.test(sh.specs)) throw new Error('removing a specialization should refund it');
    print(`  trees: ${RULES_DB.trees.length} trees and ${Object.keys(RULES_DB.talents).length} talents load, every box is reachable and on the grid, buy / refund / specialization costs check out`);
    S = migrate(JSON.parse(keep)); showTab('tracker');
  })();
  // morality / conflict / obligation / duty, career skills from a specialization, buying skill ranks
  (()=>{
    const keep = JSON.stringify(S), cal = st('cal'), sh = cal.sheet, n0 = ROLLS.length;
    sh.mor = 50; sh.conf = 4; sh.dark = 0;
    if(conflictResolve('cal', false, 7)!==3 || sh.mor!==53 || sh.conf!==0) throw new Error('conflict resolution wrong');
    sh.conf = 9; conflictResolve('cal', true, 1); if(sh.mor!==37 || moralBand(sh).name!=='Light side Force user') throw new Error('doubled conflict wrong');
    sheetSet('cal','mor',25); if(!sh.dark) throw new Error('did not fall below 30'); sheetSet('cal','mor',50); if(!sh.dark || !/stays dark/.test(moralBand(sh).fx)) throw new Error('dark side should stick until 70');
    sheetSet('cal','mor',85); if(sh.dark || !/strain threshold \+1/.test(moralBand(sh).fx)) throw new Error('paragon band wrong');
    sheetAdj('cal','conf',-1); if(sh.conf!==0) throw new Error('conflict went negative');
    if(RULES_DB.morality.length!==12) throw new Error('Morality table did not load');
    sh.morS = ''; sh.morW = ''; moralPick('cal','s','Compassion'); if(sh.morW!=='Hatred') throw new Error('paired weakness not set');
    moralPick('cal','w','Fear'); moralPick('cal','s','Bravery'); if(sh.morW!=='Anger') throw new Error('paired weakness should follow the strength');
    sh.morW = 'Homebrew flaw'; moralPick('cal','s','Love'); if(sh.morW!=='Homebrew flaw') throw new Error('a typed weakness should be kept');
    if(moralRoll('cal', 50).s!=='Curiosity' || sh.morW!=='Obsession' || !moralRoll('cal', 99) || /undefined|NaN/.test(moralPickHtml(cal))) throw new Error('Morality roll wrong');
    for(const x of S.chars){ x.sheet.obl = []; x.sheet.duty = []; }
    tallyAdd('cal','obl'); tallySet('cal','obl',sh.obl[0].id,'n','Bounty'); tallySet('cal','obl',sh.obl[0].id,'v',20);
    const bo = st('bode'); tallyAdd('bode','obl'); tallySet('bode','obl',bo.sheet.obl[0].id,'v',15); tallyAdd('bode','duty');
    const order = S.chars.map(x=>x.id), first = order.indexOf('cal') < order.indexOf('bode') ? 'cal' : 'bode';
    tallyType('bode','duty',bo.sheet.duty[0].id,'Sabotage'); tallySet('bode','duty',bo.sheet.duty[0].id,'v',5); if(bo.sheet.duty[0].n!=='Sabotage' || !/Destroy or cripple/.test(tallyHtml(bo,'duty')) || !/Bounty/.test(tallyHtml(cal,'obl')) || /undefined|NaN/.test(tallyHtml(bo,'duty'))) throw new Error('obligation / duty type picker wrong');
    if(partyTally('obl').total!==35 || partyTally('duty').total!==5) throw new Error('party totals wrong');
    if(tallyRoll('obl', 36).hit || tallyRoll('obl', 1).hit.who!==first || !tallyRoll('obl', 22).dbl || tallyRoll('obl', 35).hit.who===first) throw new Error('obligation table wrong');
    const mw = migrate(JSON.parse(JSON.stringify(syncSubset(S)))).chars.find(x=>x.id==='cal').sheet;
    if(mw.mor!==85 || mw.obl.length!==1 || mw.obl[0].n!=='Bounty' || !Array.isArray(mw.duty)) throw new Error('morality / obligation lost on the wire');
    sh.tr = {}; sh.sk = {}; sh.xp = 100; sh.specs = ''; specAdd('cal','healer');
    if(!sh.sk.medicine || !sh.sk.medicine.c || !sh.sk.xenology.c || !sh.sk.education.c || !sh.sk.discipline.c) throw new Error('specialization career skills not ticked');
    const noKey = [...new Set(RULES_DB.trees.filter(t=>t.k==='spec').flatMap(t=>t.skills).filter(n=>!skillKeyByName(n) && !/choice|any/i.test(n)))]; if(noKey.length) throw new Error('career skills with no sheet skill: '+noKey.join(', '));
    if(!skillBuy('cal','medicine') || sh.xp!==95 || !skillBuy('cal','medicine') || sh.xp!==85 || !skillBuy('cal','stealth') || sh.xp!==75 || sh.sk.stealth.r!==1) throw new Error('skill purchase cost wrong');
    sh.xp = 4; if(skillBuy('cal','medicine')) throw new Error('bought a skill rank without the XP');
    SHEET_UI.id = 'cal'; render(); const h = document.getElementById('sheetBody').innerHTML;
    if(!/Morality, Obligation/.test(h) || !/Bounty/.test(h) || /undefined|NaN|\[object/.test(moralityHtml(cal))) throw new Error('morality section broken');
    print(`  morality: conflict resolves, the dark side sticks until 70, obligation / duty table rolls (${ROLLS.length-n0} feed entries), specializations tick career skills, skill ranks cost XP`);
    S = migrate(JSON.parse(keep));
  })();
  // guided character creation: species, career, specialization, free ranks, characteristics
  (()=>{
    const keep = JSON.stringify(S), cal = st('cal'), sh = cal.sheet;
    if(RULES_DB.species.length<10 || RULES_DB.careers.length<20) throw new Error('species / careers did not load');
    ccStart('cal'); ccBlank('cal'); if(!sh.cc || sh.species || Object.keys(sh.tr).length) throw new Error('blank sheet failed');
    ccBonus('cal','xp'); ccSetSpecies('cal','Cerean');
    if(cal.attr.int!==3 || cal.attr.ag!==1 || cal.wt!==12 || cal.st!==15 || sh.xp!==100 || sh.xpTotal!==100 || (sh.sk.vigilance||{}).r!==1) throw new Error('Cerean not applied');
    ccBonus('cal','mor71'); if(sh.xp!==90 || sh.mor!==71) throw new Error('changing the Morality option did not move the XP back');
    ccSetSpecies('cal',"Twi'lek"); if(sh.sk.vigilance || cal.attr.pr!==3 || cal.st!==13 || sh.xp!==100) throw new Error('switching species left the old one behind');
    if(!ccPick('cal','fp','charm') || ccPick('cal','fp','deception') || sh.sk.charm.r!==1) throw new Error('either/or species rank wrong');
    ccSetCareer('cal','Consular'); if(sh.career!=='Consular' || !sh.sk.cool.c || sh.fr!==1) throw new Error('career not applied');
    if(!ccPick('cal','fc','cool') || !ccPick('cal','fc','discipline') || !ccPick('cal','fc','lore') || ccPick('cal','fc','leadership')) throw new Error('career free ranks should stop at 3');
    ccSetCareer('cal','Guardian'); if(sh.sk.lore || sh.sk.cool.r || !sh.sk.cool.c || !sh.sk.brawl.c) throw new Error('switching career left ranks or ticks behind');
    ccSetCareer('cal','Consular'); ccPick('cal','fc','discipline');
    ccSetSpec('cal','sage'); ccSetSpec('cal','healer'); if(sh.tr.sage || !sh.tr.healer || sh.specs!=='Healer' || !sh.sk.medicine.c || sh.xp!==100) throw new Error('first specialization should be free and replaceable');
    if(!ccPick('cal','fs','discipline') || ccPick('cal','fs','discipline')===false || sh.sk.discipline.r!==1) throw new Error('toggle free specialization rank');
    ccPick('cal','fs','discipline'); if(sh.sk.discipline.r!==2 || ccPick('cal','fc','discipline')===false) throw new Error('rank 2 from two free picks');
    ccSetSpecies('cal','Human'); if(sh.sk.charm || ccPickLimit(cal,'fp')!==2 || !ccPick('cal','fp','stealth') || !ccPick('cal','fp','mechanics') || ccPick('cal','fp','charm')) throw new Error('Human non-career ranks wrong');
    const xp0 = sh.xp, wt0 = cal.wt;
    if(!ccAttr('cal','br',1) || cal.attr.br!==3 || sh.xp!==xp0-30 || cal.wt!==wt0+1 || !ccAttr('cal','br',-1) || sh.xp!==xp0 || cal.wt!==wt0 || ccAttr('cal','br',-1)) throw new Error('characteristic purchase wrong');
    { const sq = RULES_DB.species.find(x=>x.n==='Squib'); if(!sq || !sq.hb || sq.sil!==0 || sq.attr.cun!==3) throw new Error('Squib did not import'); const sk0 = JSON.stringify(sh.sk), a0 = {...cal.attr}, w0 = cal.wt, s0 = cal.st, x0 = sh.xp, xt0 = sh.xpTotal;
      ccSetSpecies('cal','Squib'); if(sh.sil!==0 || cal.wt!==10 || cal.st!==13 || (sh.sk.negotiation||{}).r!==1) throw new Error('Squib not applied');
      ccSetSpecies('cal','Human'); if(sh.sil!==1 || (sh.sk.negotiation||{}).r) throw new Error('leaving Squib left traits behind'); ccPick('cal','fp','stealth'); ccPick('cal','fp','mechanics'); }
    { if(RULES_DB.careers.length!==20 || RULES_DB.careers.find(x=>x.n==='Jedi').fr!==1 || RULES_DB.careers.find(x=>x.n==='Jedi').free!==3 || RULES_DB.trees.filter(t=>t.k==='spec' && t.career==='Clone Soldier').length!==6 || TREE_BY['fp-bind'].fr!==2) throw new Error('careers or Bind prerequisite wrong'); const sk1 = JSON.stringify(sh.sk), car1 = sh.cc.car, fr1 = sh.fr, spec1 = sh.cc.spec;
      ccSetCareer('cal','Smuggler'); if(sh.fr!==0 || !sh.sk.streetwise.c || ccPickLimit(cal,'fc')!==4 || sh.sk.cool && sh.sk.cool.c && !TREE_BY[spec1].skills.includes('Cool')) throw new Error('Edge career not applied');
      for(const k of ['coordination','deception','perception','streetwise']) if(!ccPick('cal','fc',k)) throw new Error('four free career ranks expected'); if(ccPick('cal','fc','skulduggery')) throw new Error('fifth free rank allowed');
      if(!RULES_DB.trees.some(t=>t.k==='spec' && t.career==='Smuggler')) throw new Error('no Smuggler trees'); ccSetCareer('cal',car1); if(sh.fr!==1) throw new Error('Force rating not restored'); sh.fr = fr1; }
    { const dr = RULES_DB.species.find(x=>x.n==='Droid'); if(!dr || dr.hb || !dr.droid || dr.careerFree!==6 || dr.specFree!==3 || dr.soak!==1 || dr.xp!==175) throw new Error('Droid species did not import');
      const kb = JSON.stringify(S); ccStart('bd1'); const bd = st('bd1'), bs = bd.sheet; ccSetSpecies('bd1','Droid'); ccSetCareer('bd1','Explorer');
      if(bd.attr.int!==1 || bd.wt!==11 || bs.xp!==175 || bs.soakMod!==1 || ccPickLimit(bd,'fc')!==6 || ccPickLimit(bd,'fs')!==3 || !/Droid/.test(creationHtml(bd)) && false) throw new Error('Droid species not applied');
      ccStep('bd1',4); const sp4 = creationHtml(bd); if(/Twi'lek|Human</.test(sp4) || !/>Droid</.test(sp4)) throw new Error('a droid should be offered only the Droid species');
      ccStep('cal',4); if(/>Droid</.test(creationHtml(st('cal')))) throw new Error('an organic was offered the Droid species');
      ccOther('bd1','species','Probe'); if(bs.soakMod!==0) throw new Error('leaving Droid should take its soak away'); const i = S.chars.findIndex(x=>x.id==='bd1'); S.chars[i] = JSON.parse(kb).chars[i]; normSheet(S.chars[i], cfg('bd1')); }
    ccBonus('cal','cr'); ccCredits('cal'); if(sh.credits!==3000) throw new Error('starting credits wrong');
    const w = migrate(JSON.parse(JSON.stringify(syncSubset(S)))).chars.find(x=>x.id==='cal').sheet; if(!w.cc || w.cc.sp!=='Human' || !w.cc.fp.stealth || typeof w.cc.fc!=='object') throw new Error('creation progress lost on the wire');
    let bad = 0; SHEET_UI.id = 'cal'; for(let i=1;i<=CC_STEPS.length;i++){ ccStep('cal',i); bad += (creationHtml(cal).match(/undefined|NaN|\[object/g)||[]).length; }
    sheetBio('cal','age','23'); sheetBio('cal','hair','Red'); sheetFS('cal',0); render();
    const hd = document.getElementById('sheetBody').innerHTML;
    if(isFS(cal) || /med15/.test(hd) || !/>23</.test(hd) || !/>Red</.test(hd) || /onchange="sheetSet\('cal','species'/.test(hd)) throw new Error('bio / read-only header wrong');
    startStatus('cal','med15'); if(cal.status) throw new Error('a non-Force-sensitive character meditated'); sheetFS('cal',1); if(!isFS(cal)) throw new Error('Force sensitive toggle');
    ccOther('cal','career','Smuggler'); if(sh.career!=='Smuggler' || sh.cc.car || sh.sk.cool && sh.sk.cool.r) throw new Error('other career wrong');
    const wb = migrate(JSON.parse(JSON.stringify(syncSubset(S)))).chars.find(x=>x.id==='cal').sheet; if(wb.bio.age!=='23' || wb.fs!==1 || typeof wb.bio.eyes!=='string') throw new Error('bio lost on the wire');
    const cc0 = cfg('cal'); if(cc0.build!=='Athletic' || cc0.waterOz!==65 || cc0.mods.hungerRate!==1.1 || cfg('bd1').packHrs!==40 || cfg('tann').mods.hungerRate!==undefined) throw new Error('roster builds not applied');
    sheetBio('cal','build','Heavy'); if(sh.bio.build!=='Athletic') throw new Error('an organic took a droid build');
    sheetBio('cal','build','Small'); if(cc0.waterOz!==40 || cc0.mods.hungerRate!==1.25 || sh.bio.build!=='Small') throw new Error('build did not change the needs');
    const wbb = migrate(JSON.parse(JSON.stringify(syncSubset(S)))).chars.find(x=>x.id==='cal').sheet; if(wbb.bio.build!=='Small' || cc0.waterOz!==40) throw new Error('build lost on the wire');
    const old = JSON.parse(JSON.stringify(syncSubset(S))); old.chars.find(x=>x.id==='cal').sheet.bio.build = 'Slender/Muscular'; migrate(old); if(cc0.build!=='Athletic' || cc0.waterOz!==65) throw new Error('an old free-text build should fall back to the roster default');
    sheetBio('bd1','build','Heavy'); if(cfg('bd1').packHrs!==20) throw new Error('droid build'); sheetBio('bd1','build','Compact');
    print('  daily needs by build: '+Object.keys(BUILDS).map(b=>{ const c = CHARS.find(x=>!!x.droid===!!BUILDS[b].droid), was = c.build; setBuild(c,b); const t = b+' '+needsText(c); setBuild(c,was); return t; }).join(' · '));
    if(!(dailyNeeds(cfg('tann')).rations>0) || dailyNeeds(cfg('bd1')).pack!==40 || /undefined|NaN/.test(needsText(cfg('cal')))) throw new Error('daily needs wrong');
    const keepB = S; S = freshState();
    for(const b of buildsFor(cfg('tann'))){ const c = cfg('tann'), t = st('tann'), was = c.build; setBuild(c, b); t.hunger = 0; t.status = null; t.water = 0; t.inv = [];
      for(let h=0; h<6; h++){ t.water = 0; t.sleep = 0; t.rest = 0; tick(t,1); } const day = t.hunger*4, per = foodPts(c,'ration');
      if(Math.abs(day - per*BUILDS[b].rations) > 0.6) throw new Error(`${b}: a fed day of light activity is ${day.toFixed(1)} hunger but ${BUILDS[b].rations} rations give back ${(per*BUILDS[b].rations).toFixed(1)}`);
      setBuild(c, was); t.hunger = 0; }
    S = keepB; migrate(JSON.parse(JSON.stringify(syncSubset(S))));   // put the roster's builds back to this state's
    if(Math.abs(foodPts(cfg('tann'),'snack')*3 - foodPts(cfg('tann'),'ration')) > 1e-9 || foodPts(cfg('tann'),'meal') <= foodPts(cfg('tann'),'ration')) throw new Error('snack / meal sizes wrong');
    { const t = st('tann'), keepInv = t.inv; t.status = null; t.water = 0; t.hunger = 60; t.inv = [stockRow('Ration', 2), stockRow('Snack', 1)];
      startStatus('tann','ration'); if(Math.abs(-t.status.deltas.hunger - foodPts(cfg('tann'),'ration')*REFEED.frac) > 1e-9) throw new Error('refeeding should absorb only part of a ration');
      t.status = null; t.hunger = 60; eatSnack('tann'); if(Math.abs(60 - t.hunger - foodPts(cfg('tann'),'snack')*REFEED.frac) > 1e-9) throw new Error('refeeding should slow a snack too');
      t.status = null; t.hunger = 0; t.inv = keepInv; }
    if(dailyNeeds(cfg('kata')).water!==44 || invTypeFor(CATALOG.find(x=>x.n==='Field Ration Pack'))!=='Ration' || invTypeFor(CATALOG.find(x=>x.n==='Imperial Army Field Rations'))==='Ration') throw new Error('daily water or ration item typing wrong');
    { const f = freshState().chars, n = id => stockOf(f.find(x=>x.id===id),'Ration'); if(n('pike')!==6 || n('tann')!==9 || n('cal')!==11 || n('bode')!==12) throw new Error('starting rations should be three days by build: '+[n('pike'),n('tann'),n('cal'),n('bode')]); migrate(JSON.parse(JSON.stringify(syncSubset(S)))); }
    sheetSil('cal',0); if(sh.sil!==0 || st('pike').sheet.sil!==0 || st('bode').sheet.sil!==1) throw new Error('silhouette wrong'); sheetSil('cal',1);
    sheetName('cal',"  Cal <b>O'Kestis  "); if(cfg('cal').name!=='Cal bO’Kestis' || sh.name!=='Cal bO’Kestis') throw new Error('name not cleaned: '+cfg('cal').name);
    sheetName('cal','Prauf'); render(); if(!/Prauf/.test(document.getElementById('sheetChips').innerHTML) || !/Character Creator/.test(creationHtml(cal))) throw new Error('rename not shown');
    migrate(JSON.parse(JSON.stringify(syncSubset(S)))); if(cfg('cal').name!=='Prauf') throw new Error('name lost on the wire');
    sheetName('cal',''); if(cfg('cal').name!=='Cal Kestis') throw new Error('clearing the name should restore the default');
    { const b = JSON.parse(JSON.stringify(buildExport('cal'))), bo = st('bode'), inv0 = JSON.stringify(bo.inv), cr0 = (bo.sheet.credits = 777), nm0 = cfg('bode').name;
      if(b.sheet.credits!==undefined || b.sheet.cc || b.kind!=='st-build') throw new Error('build export should leave out credits and progress');
      if(buildApply('bode', {kind:'nope'})==='' || buildApply('bd1', b)==='') throw new Error('bad builds should be refused');
      if(buildApply('bode', b)!=='' || JSON.stringify(bo.inv)!==inv0 || bo.sheet.credits!==777 || bo.attr.ag!==cal.attr.ag || bo.wt!==cal.wt || JSON.stringify(bo.sheet.tr)!==JSON.stringify(sh.tr) || bo.sheet.species!==sh.species) throw new Error('build import wrong');
      S = migrate(JSON.parse(keep)); }
    const cal2 = st('cal'); ccStart('cal');
    ccEnd('cal'); if(cal2.sheet.cc || creationHtml(cal2)!=='' || bad) throw new Error('creation walkthrough render broken');
    print(`  creation: ${RULES_DB.species.length} species and ${RULES_DB.careers.length} careers; species, career, specialization, free ranks and characteristic purchases apply and undo cleanly`);
    S = migrate(JSON.parse(keep));
  })();
  // core rules quick reference: every section renders, the GM checklist ticks, the Morality trigger picks the closest character
  (()=>{
    const secs = coreSections(), html = secs.map(x=>x[3]).join('');
    const cBad = (html.match(/undefined|NaN|\[object/g)||[]).length;
    if(secs.length<12 || cBad || !/die sm d12 t-p/.test(html) || !/Bleeding Out/.test(html)) throw new Error('core rules broken: '+cBad);
    showTab('core'); gmCheck('destiny', true); if(!/class="done"/.test(coreSections()[0][3])) throw new Error('GM checklist tick not shown'); gmReset();
    for(const x of S.chars) x.sheet.mor = 50; st('bode').sheet.mor = 88; if(moralTrigger(90)!=='bode') throw new Error('Morality trigger wrong'); st('bode').sheet.mor = 50;
    print(`  core rules: ${secs.length} sections, ${Math.round(html.length/1000)}k of reference, 0 broken interpolations`); showTab('tracker');
  })();
  // command console: Alpha's authorized users, orders by priority and urgency, macros, override, modules
  (()=>{
    const keep = JSON.stringify(S), al = st('alpha'), m = cmdOf(al);
    if(!m || cmdOf(st('bd1')) || cmdOf(st('cal')) || cmdHtml(st('cal'))!=='' || cmdCardLine(st('bd1'))!=='') throw new Error('only Alpha should have a console');
    if(cmdUserName(m.users[0])!==cfg('bode').name || !m.users[1].pr || m.users.length!==7 || m.mods.length!==6 || m.macros[0].st.length!==3) throw new Error('console defaults wrong');
    const [bode, kata, cal] = m.users;
    cmdOrder('alpha','Hold position',2,1,cal.id); cmdOrder('alpha','Move Principal to Cover','','',bode.id); cmdOrder('alpha','Scan the corridor',1,2,kata.id); cmdOrder('alpha','Carry Kata',1,1,kata.id);
    const ord = cmdSorted(m).map(o=>o.t).join('|'); if(ord!=='Move Principal to Cover|Carry Kata|Scan the corridor|Hold position') throw new Error('order sorting wrong: '+ord);
    if(cmdOrder('alpha','Stand down',9,9,cal.id,true)) throw new Error('override used with none set'); cmdUserFlag('alpha',cal.id,'ov',true);
    if(!cmdOrder('alpha','Stand down',9,9,cal.id,true) || cmdSorted(m)[0].t!=='Stand down' || !/OVERRIDE/.test(cmdCardLine(al))) throw new Error('override should jump the queue');
    cmdOrderSet('alpha', m.orders.find(o=>o.t==='Stand down').id, 'done'); cmdOrderSet('alpha', m.orders.find(o=>o.t==='Hold position').id, 'ignored');
    if(cmdSorted(m)[0].t!=='Move Principal to Cover' || cmdSorted(m).filter(o=>o.s==='active').length!==3) throw new Error('finished orders should drop below active ones');
    cmdMacroRun('alpha', m.macros[0].id, kata.id); if(m.orders.filter(o=>o.mc==='Secure').length!==3) throw new Error('macro did not expand');
    cmdUserMove('alpha', kata.id, -1); if(cmdUserName(m.users[0])!==cfg('kata').name) throw new Error('user priority move wrong'); cmdUserMove('alpha', kata.id, 1);
    cmdModAdd('alpha','Starship Piloting'); cmdUserAdd('alpha','Greez'); cmdClearDone('alpha');
    const w = migrate(JSON.parse(JSON.stringify(syncSubset(S)))).chars.find(x=>x.id==='alpha').sheet.cmd;
    if(w.orders.length!==6 || w.users.length!==8 || w.users[7].n!=='Greez' || w.mods.length!==7 || w.macros[0].st.length!==3 || !w.users[2].ov) throw new Error('console lost on the wire');
    al.sheet.cmd.orders = []; al.sheet.cmd.macros = []; const w2 = migrate(JSON.parse(JSON.stringify(syncSubset(S)))).chars.find(x=>x.id==='alpha').sheet.cmd; if(w2.macros.length || w2.orders.length || w2.users.length!==8) throw new Error('an emptied console list came back');
    SHEET_UI.id = 'alpha'; render(); const h = cmdHtml(al); if(/undefined|NaN|\[object/.test(h) || !/Command Console/.test(document.getElementById('sheetBody').innerHTML)) throw new Error('console render broken');
    print(`  command console: ${m.users.length} authorized users, orders sort by override / priority / urgency / user rank, macros expand, survives the wire`);
    S = migrate(JSON.parse(keep));
  })();
  // lore: the campaign book loads, links resolve, search finds, nothing private is in it
  (()=>{
    if(!LORE_DB || Object.keys(LORE_DB.notes).length<300 || !LORE_DB.notes[LORE_DB.home]) throw new Error('lore.js did not load');
    const N = LORE_DB.notes, all = JSON.stringify(LORE_DB);
    for(const id in N){ for(const m of N[id].h.matchAll(/loreGo\('([^']+)'\)/g)) if(!N[m[1]]) throw new Error('dead lore link on '+id+': '+m[1]); for(const b of N[id].back||[]) if(!N[b]) throw new Error('dead backlink on '+id); }
    for(const sec of LORE_DB.sections) for(const g of sec.groups) for(const id of g.ids) if(!N[id]) throw new Error('nav lists a missing page: '+id);
    if(/real_dates|Discord export|\(log\)\]\]|<script|onerror=/i.test(all) || Object.values(N).some(n=>n.type==='archive' || 'player' in n.fm)) throw new Error('private or unsafe text in lore.js');
    showTab('lore'); loreGo(loreFind('Bode Akuna')); const pg = document.getElementById('lorePage').innerHTML;
    if(!/Bode Akuna/.test(pg) || !/📄 sheet/.test(pg) || !/Mentioned on/.test(pg) || /undefined|NaN|\[object/.test(pg)) throw new Error('lore page render wrong');
    loreGo(loreFind('Kata Akuna')); loreBack(); if(LORE_UI.id!==loreFind('Bode Akuna')) throw new Error('lore back button wrong');
    const hits = loreSearch('centerpoint'); if(!hits.length || N[hits[0].id].t.toLowerCase().indexOf('centerpoint')<0) throw new Error('lore search should put title matches first');
    loreSet('q','mantis'); if(!/lhit|class="on"|<button/.test(document.getElementById('loreNav').innerHTML)) throw new Error('lore search list empty'); loreSet('q','');
    if(!/Active objectives/i.test(N[LORE_DB.home].h) || !/lbase|lempty/.test(N[LORE_DB.home].h)) throw new Error('home page lists did not generate');
    print(`  lore: ${Object.keys(N).length} pages in ${LORE_DB.sections.length} sections, every link resolves, no private markers`); showTab('tracker');
    // GM tab: the species guide loads, filters and renders
    showTab('gm'); if(!SPECIES_DB || SPECIES_DB.length<300) throw new Error('species.js did not load');
    if(SPECIES_DB.some(s=>s.a.length!==6 || !(s.wt>0) || !(s.st>0) || !(s.xp>0) || !s.n || (s.sub||[]).some(x=>x.a && x.a.length!==6))) throw new Error('a species is missing numbers');
    gmSet('q','nautolan'); if(speciesFiltered().length!==1) throw new Error('species search wrong');
    speciesPick(speciesFiltered()[0][1]); const sd = document.getElementById('gmDetail').innerHTML;
    if(!/Nautolan/.test(sd) || !/Wounds <b>14<\/b>/.test(sd) || !/Pheromone Detection/.test(sd) || /undefined|NaN|\[object|\[[A-Z]{2}\]/.test(sd)) throw new Error('species detail render wrong');
    gmSet('q',''); gmSet('attr','0'); const strong = speciesFiltered(); if(!strong.length || strong.length===SPECIES_DB.length || strong.some(([s])=>s.a[0]<3 && !(s.sub||[]).some(x=>x.a && x.a[0]>=3))) throw new Error('strong-in filter wrong');
    gmSet('attr',''); gmSet('sort','xp'); const byXp = speciesFiltered(); if(byXp[0][0].xp < byXp[byXp.length-1][0].xp) throw new Error('species sort wrong'); gmSet('sort','name');
    { const aq = SPECIES_DB.find(s=>s.n==='Aqualish'); GM_UI.sel = SPECIES_DB.indexOf(aq); renderSpeciesDetail(); if(!/Subspecies/.test(document.getElementById('gmDetail').innerHTML) || aq.sub.length!==3) throw new Error('subspecies not shown'); GM_UI.sel = -1; }
    print(`  species: ${SPECIES_DB.length} in the guide, ${SPECIES_DB.filter(s=>s.sub).length} with subspecies; search, filter, sort and detail render`); showTab('tracker');
    // GM tab: GM mode, NPC builder (templates, species numbers, skills, weapons, minion groups), and the wire
    { showTab('gm'); const keepNpcs = JSON.stringify(S.npcs);
      if(!ADV_DB || ADV_DB.length<40 || ADV_DB.some(a=>a.a.length!==6 || !NPC_TYPES[a.type] || !(a.wt>0))) throw new Error('adversaries.js did not load');
      gmMode(false); gmSec('npcs'); renderGM(); if(GM_UI.sec!=='species' || /NPCs/.test(document.getElementById('gmNav').innerHTML)) throw new Error('NPC section should be hidden without GM mode');
      gmMode(true); gmSec('npcs'); if(GM_UI.sec!=='npcs' || !/NPCs/.test(document.getElementById('gmNav').innerHTML)) throw new Error('GM mode should show the NPC section');
      const st0 = npcNew(ADV_DB.findIndex(a=>a.n==='Imperial Stormtrooper'));
      if(st0.type!=='minion' || st0.soak!==5 || st0.wt!==5 || st0.sk.length!==4 || !st0.sk.some(s=>s[0]==='Ranged: Heavy') || st0.w[0].sk!=='Ranged: Heavy' || st0.w[0].dam!=='9') throw new Error('stormtrooper template wrong: '+JSON.stringify(st0));
      GM_UI.grp = 4; const pool = npcPool(st0, 'Ranged: Heavy'); if((pool.match(/t-p/g)||[]).length!==3 || (pool.match(/t-a/g)||[]).length!==0) throw new Error('a group of four minions should roll three proficiency dice');
      if((npcPool(st0,'Stealth').match(/t-a/g)||[]).length!==3 || /t-p/.test(npcPool(st0,'Stealth'))) throw new Error('an unlisted skill should be characteristic only');
      const as = npcNew(ADV_DB.findIndex(a=>a.n==='Imperial Assassin')); if(as.type!=='nemesis' || as.st!==20 || !/Adversary 2: /.test(as.tal) || !/Neurotoxin/.test(as.ab)) throw new Error('nemesis template wrong');
      if((npcPool(as,'Melee').match(/t-p/g)||[]).length!==3 || (npcPool(as,'Melee').match(/t-a/g)||[]).length!==1) throw new Error('Melee 4 on Brawn 3 should be 3 proficiency + 1 ability');
      npcSetSpecies(as.id, 'twi\'lek'); if(as.sp!=="Twi'lek" || !as.k || as.a[0]!==3 || as.wt!==18) throw new Error('a species on a template should keep the template numbers');
      const nb = npcNew(); if(nb.type!=='rival' || nb.tpl) throw new Error('blank NPC wrong');
      npcSetSpecies(nb.id, 'Nautolan'); if(nb.a.join()!=='3,2,2,2,1,2' || nb.wt!==14 || nb.soak!==3 || nb.st!==0 || nb.k!=='NAUTOLAN') throw new Error('species numbers for a rival wrong: '+JSON.stringify(nb));
      npcType(nb.id,'nemesis'); npcSpeciesNumbers(nb.id); if(nb.wt!==19 || nb.st!==12) throw new Error('species numbers for a nemesis wrong');
      npcType(nb.id,'minion'); npcSpeciesNumbers(nb.id); if(nb.wt!==5 || nb.st!==0) throw new Error('species numbers for a minion wrong');
      npcType(nb.id,'rival'); npcAttr(nb.id, 0, 5); if(nb.soak!==5) throw new Error('soak should follow Brawn');
      npcSkillAdd(nb.id,'Brawl'); npcSkillRank(nb.id, 0, 2); npcWeaponAdd(nb.id,'Light Blaster Pistol'); npcWeaponAdd(nb.id,'Bone club'); npcWeaponSet(nb.id, 1, 'dam', '+2'); npcWeaponSet(nb.id, 1, 'sk', 'Brawl');
      if(nb.w[0].sk!=='Ranged: Light' || nb.w[0].dam!=='5' || nb.w[0].rng!=='Medium' || nb.w[1].n!=='Bone club' || npcDamage(nb, nb.w[1])!=='= 7') throw new Error('weapons wrong: '+JSON.stringify(nb.w));
      npcSet(nb.id,'n','Test <b>NPC</b>'); npcSet(nb.id,'notes','wants "credits"'); npcRandomName(st0.id); if(!/^\S+ \S+$/.test(st0.n)) throw new Error('random name wrong: '+st0.n);
      GM_UI.npc = nb.id; renderGM(); const ed = document.getElementById('gmNpcs').innerHTML;
      if(!/Test &lt;b>NPC/.test(ed) || /undefined|NaN|\[object/.test(ed) || !/use Nautolan numbers/.test(ed) || !/Pheromone Detection/.test(ed) || !/Bone club/.test(ed)) throw new Error('NPC editor render wrong');
      GM_UI.nq = 'nautolan'; if(npcFiltered().length!==1) throw new Error('library search wrong'); GM_UI.nq = '';
      npcDup(nb.id); if(S.npcs.length!==4 || S.npcs[3].n!=='Test <b>NPC</b> (copy)' || S.npcs[3].id===nb.id) throw new Error('copy wrong');
      const wire = migrate(JSON.parse(JSON.stringify(syncSubset(S)))); if(!same(syncSubset(wire).npcs, syncSubset(S).npcs) || wire.npcs.length!==4 || !Array.isArray(wire.npcs[0].w)) throw new Error('NPCs do not survive the wire');
      { const blank = normNpcs([{}])[0], back = normNpcs(JSON.parse(JSON.stringify(prune([JSON.parse(JSON.stringify(blank))]))))[0]; if(!same(blank, back) || !Array.isArray(back.sk)) throw new Error('an empty NPC should come back whole'); }
      const n4 = S.npcs.length; npcDel(S.npcs[3].id); if(S.npcs.length!==n4-1) throw new Error('delete wrong');
      print(`  NPC builder: ${ADV_DB.length} templates; species numbers by type, minion group pools, weapons from the catalog, copy / delete and the wire all hold`);
      S.npcs = JSON.parse(keepNpcs); GM_UI.npc = ''; GM_UI.grp = 3; gmMode(false); }
    // Encounter tab: strict initiative order, turns and rounds, NPC cards, hidden NPCs, per-key merge, the wire
    { const keepS = S; S = freshState(); const rolls0 = ROLLS.length;   // a rested party: nobody is down from hunger
      if('enc' in syncSubset(S)) throw new Error('no encounter should mean no enc key on the wire');
      showTab('enc'); gmMode(true); encStart('combat'); if(!encOn() || S.enc.mode!=='combat' || S.enc.cur!=='') throw new Error('encounter did not start');
      const lib = npcNew(ADV_DB.findIndex(a=>a.n==='Imperial Stormtrooper')), boss = npcNew(ADV_DB.findIndex(a=>a.n==='Imperial Assassin'));
      const tk = encAddNpc(lib.id, 3), bk = encAddNpc(boss.id), bk2 = encAddNpc(boss.id);
      if(!S.enc[tk].hid || S.enc[tk].count!==3 || S.enc[bk].count!==1 || encName(bk2)!=='Imperial Assassin #2' || encCopies(boss.id)!==2) throw new Error('adding NPCs wrong');
      lib.wt = 99; if(S.enc[tk].d.wt!==5) throw new Error('an encounter NPC should be a snapshot, not a link to the library');
      encSetInit('c_cal', 3, 1); encSetInit('c_bode', 3, 1); encSetInit('c_tann', 1, 0); encSetInit(tk, 3, 1); encSetInit(bk, 4, 0);
      encRollPC('merrin', 'vigilance'); if(!S.enc.c_merrin.r || S.enc.c_merrin.sk!=='vigilance' || ROLLS.length<=rolls0 || !/Initiative \(Vigilance\)/.test(ROLLS[ROLLS.length-1].l)) throw new Error('initiative roll did not record or reach the feed');
      encSetInit('c_merrin', 0, 0); encSit('gibbs', 1);
      let o = encOrder(); if(o.join()!==[bk,'c_bode','c_cal',tk,'c_tann','c_merrin'].join()) throw new Error('order wrong (successes, advantages, PCs before NPCs): '+o.join());
      encRollNPC(bk2, 'cool'); if(!S.enc[bk2].r || ROLLS[ROLLS.length-1].who!=='GM') throw new Error('a hidden NPC should roll as "GM"'); encSetInit(bk2, 0, 0);
      gmMode(false); o = encOrder(); if(o.includes(tk) || o.includes(bk) || o.length!==4) throw new Error('hidden NPCs should not be in the players\' order');
      ENC_UI.me = 'cal'; renderEnc(); let pv = document.getElementById('encScene').innerHTML + document.getElementById('encOrder').innerHTML + document.getElementById('encHead').innerHTML;
      if(/Stormtrooper|Assassin|Soak/.test(pv) || /undefined|NaN|\[object/.test(pv)) throw new Error('the player view leaks hidden NPCs or is broken');
      gmMode(true); encNpcSet(tk, 'hid', 0); encNpcSet(bk, 'hid', 0); gmMode(false); renderEnc(); pv = document.getElementById('encScene').innerHTML;
      if(!/Imperial Stormtrooper/.test(pv) || !/3 of 3 standing/.test(pv) || /Soak|Wounds/.test(pv)) throw new Error('a revealed NPC should show its name and condition only');
      encNext(); if(S.enc.cur!==bk || S.enc.round!==1) throw new Error('round 1 should start at the top');
      encNext(); encNext(); if(S.enc.cur!=='c_cal') throw new Error('turn should pass down the order'); renderEnc();
      if(!/Your turn, Cal/.test(document.getElementById('encHead').innerHTML) || !/End my turn/.test(document.getElementById('encHead').innerHTML)) throw new Error('your-turn banner missing');
      encNpcSet(tk, 'w', 5); if(encAlive(S.enc[tk])!==2 || encCond(S.enc[tk])[0]!=='2 of 3 standing') throw new Error('minion group should lose one member per threshold of wounds');
      encNpcAdj(tk, 'w', 10); if(encAlive(S.enc[tk])!==0 || !encDown(tk)) throw new Error('minion group should be defeated');
      encNext(); if(S.enc.cur!=='c_tann') throw new Error('a defeated group should be skipped');
      encNext(); encNext(); encNext(); if(S.enc.cur!==bk || S.enc.round!==2) throw new Error('round should advance at the top of the order: '+S.enc.cur+' r'+S.enc.round);
      encBack(); if(S.enc.cur!==bk2 || S.enc.round!==1) throw new Error('back should step to the end of the previous round: '+S.enc.cur);
      encNpcSet(bk, 'w', 19); if(encCond(S.enc[bk])[0]!=='Down') throw new Error('past the threshold is down'); encNpcSet(bk, 'w', 9); if(encCond(S.enc[bk])[0]!=='Hurt') throw new Error('half wounds is Hurt');
      gmMode(true); renderEnc(); const gv = document.getElementById('encScene').innerHTML; if(!/Soak <b>3<\/b>/.test(gv) || !/Disruptor rifle/.test(gv) || /undefined|NaN|\[object/.test(gv)) throw new Error('GM card wrong');
      const wire = migrate(JSON.parse(JSON.stringify(syncSubset(S)))); if(!same(syncSubset(wire).enc, syncSubset(S).enc) || !wire.enc[tk].d || !Array.isArray(wire.enc[tk].d.sk)) throw new Error('the encounter does not survive the wire');
      { const base = syncSubset(S), mine = JSON.parse(JSON.stringify(base)), theirs = JSON.parse(JSON.stringify(base));
        mine.enc.c_cal.s = 9; theirs.enc.c_bode.s = 8; theirs.enc.c_kata = { r:1, s:2, a:0, x:0, sk:'cool', out:0 };
        const m = threeWayMerge(base, mine, theirs); if(m.enc.c_cal.s!==9 || m.enc.c_bode.s!==8 || !m.enc.c_kata) throw new Error('two players rolling at once should both keep their rolls');
        const gone = JSON.parse(JSON.stringify(base)); delete gone.enc; if(threeWayMerge(base, mine, gone).enc) throw new Error('an encounter ended elsewhere should stay ended'); }
      encSet('mode','social'); renderEnc(); if(!/Conversation/.test(document.getElementById('encHead').innerHTML) || document.getElementById('encOrder').innerHTML!=='') throw new Error('conversation mode should drop the turn order');
      encSet('mode','combat'); encEnd(); if(encOn() || 'enc' in syncSubset(S) || !S.log.some(l=>/Encounter over after 1 round/.test(l.m) && /Defeated: Imperial Stormtrooper/.test(l.m))) throw new Error('ending the encounter wrong: '+S.log.map(l=>l.m).join(' | '));
      renderEnc(); print(`  encounter: strict order (successes, advantages, PCs first), rounds, skipped casualties, hidden NPCs stay out of the player view, simultaneous rolls merge, survives the wire`);
      S = keepS; ENC_UI.me = ''; gmMode(false); showTab('tracker'); }
    // Encounter options: sorting talents, attack difficulty from range / defense / Adversary, damage after soak, turn economy
    { const keepS = S; S = freshState(); showTab('enc'); gmMode(true); encStart('combat');
      const T = RULES_DB.talents; for(const [n, want] of [['Parry','defense'],['Reflect','defense'],['Dodge','defense'],['Saber Throw','offense'],['Toughened','defense'],['Quick Draw','offense'],['Sense Danger','force']])
        if(T[n] && abilCat(n, T[n])!==want) throw new Error(`${n} should sort under ${want}, got ${abilCat(n, T[n])}`);
      if(abilBadge('Active (Incidental, Out of Turn)')[0]!=='out' || abilBadge('Active (Maneuver)')[0]!=='man' || abilBadge('Passive')[0]!=='pas') throw new Error('activation badges wrong');
      const tk = encAddNpc(npcNew(ADV_DB.findIndex(a=>a.n==='Imperial Stormtrooper')).id, 3), bk = encAddNpc(npcNew(ADV_DB.findIndex(a=>a.n==='Imperial Assassin')).id);
      encNpcSet(tk,'hid',0); encNpcSet(bk,'hid',0);
      const cal = st('cal'); cal.inv.push({ name:'Light Blaster Pistol', ref:'Light Blaster Pistol', type:'Weapon', eq:1, qty:1 }); const wi = cal.inv.length-1;
      if(!isEquipped(cal.inv[wi]) || weaponState(cal, cal.inv[wi]).skill.k!=='ranged_light') throw new Error('test pistol is not an equipped ranged weapon');
      ENC_UI.tgt = bk; ENC_UI.rng = 'Long'; encAttackPC('cal', -1);
      if(DICE_UI.pool.d!==0 || DICE_UI.pool.c!==2 || DICE_UI.pool.k!==1 || DICE_UI.weapon.tgt!==bk || DICE_UI.weapon.rng!=='Engaged' || !/Adversary 2/.test(DICE_UI.weapon.note)) throw new Error('melee vs Adversary 2 and defense 1 should be two Challenge and one Setback: '+JSON.stringify(DICE_UI.pool));
      ENC_UI.tgt = tk; encAttackPC('cal', wi); if(DICE_UI.pool.d!==3 || DICE_UI.pool.c!==0 || DICE_UI.pool.k!==0 || !/Long range: Hard/.test(DICE_UI.weapon.note) || !/beyond this weapon/.test(DICE_UI.weapon.note)) throw new Error('long range should be Hard: '+JSON.stringify(DICE_UI.pool)+DICE_UI.weapon.note);
      ENC_UI.rng = 'Engaged'; encAttackPC('cal', wi); if(DICE_UI.pool.d!==2) throw new Error('a pistol while engaged should be Average');
      ENC_UI.rng = 'Short'; encAttackPC('cal', wi); if(DICE_UI.pool.d!==1 || DICE_UI.who!=='cal') throw new Error('short range should be Easy');
      const n0 = ROLLS.length; rollPool(); const sent = ROLLS[ROLLS.length-1]; if(ROLLS.length!==n0+1 || sent.w.tgt!==tk || sent.w.src || sent.w.note) throw new Error('the roll should carry its target and nothing private');
      const f1 = DICE.a.faces.find(x=>x==='s'); if(!f1) throw new Error('no single-success Ability face');
      ROLLS.push({ k:'r', who:'Cal Kestis', ts:1111, r:`a:${f1} a:${f1}`, w:{ n:'Pistol', dam:5, crit:4, q:'Stun Setting, Pierce 1', tgt:tk, tn:'Imperial Stormtrooper' } });
      const h = encHit(ROLLS[ROLLS.length-1].w, tally(parseRoll(ROLLS[ROLLS.length-1].r))); if(!h || h.soak!==4 || h.dmg!==3 || !h.stun) throw new Error('5 + 2 successes against soak 5 with Pierce 1 should be 3: '+JSON.stringify(h));
      let card = feedEntryHtml(ROLLS[ROLLS.length-1]); if(!/apply 3 wounds/.test(card) || !/as strain/.test(card) || !/after soak 4/.test(card)) throw new Error('GM feed card should offer to apply the hit');
      gmMode(false); card = feedEntryHtml(ROLLS[ROLLS.length-1]); if(/apply 3|after soak/.test(card) || !/the GM applies soak/.test(card)) throw new Error('players should not see an NPC\'s soak or apply the hit');
      gmMode(true); encApply(1111, 'st'); if(S.enc[tk].w!==3 || !S.enc.ap_1111) throw new Error('a minion takes strain as wounds'); encApply(1111, 'w'); if(S.enc[tk].w!==3) throw new Error('a hit should apply only once');
      if(!/✓ applied/.test(feedEntryHtml(ROLLS[ROLLS.length-1]))) throw new Error('applied hit should say so');
      ENC_UI.tpc = 'c_cal'; ENC_UI.rng = 'Medium'; encAttackNPC(bk, 0); if(DICE_UI.who!=='gm' || DICE_UI.pool.d!==2 || DICE_UI.pool.p!==3 || DICE_UI.pool.a!==1 || DICE_UI.weapon.tgt!=='c_cal' || DICE_UI.weapon.dam!==10) throw new Error('NPC attack setup wrong: '+JSON.stringify(DICE_UI.pool));
      const soak = combatStats(cal).soak, w0 = cal.wounds||0; ROLLS.push({ k:'r', who:'GM', ts:2222, r:`a:${f1}`, w:{ n:'Disruptor rifle', dam:10, crit:2, q:'Vicious 5', tgt:'c_cal', tn:'Cal Kestis' } });
      gmMode(false); if(!/apply \d+ wounds/.test(feedEntryHtml(ROLLS[ROLLS.length-1]))) throw new Error('anyone may apply a hit on a player character');
      encApply(2222, 'w'); if(cal.wounds!==w0 + Math.max(0, 11 - soak)) throw new Error('damage to a PC should be reduced by their soak');
      ROLLS.push({ k:'r', who:'x', ts:3333, r:`a:${f1}`, w:{ n:'x', dam:5, tgt:'constructor', tn:'x' } }); if(encHit(ROLLS[ROLLS.length-1].w, {netS:1})) throw new Error('a bad target key off the wire should be ignored');
      const wire = migrate(JSON.parse(JSON.stringify(syncSubset(S)))); if(!wire.enc.ap_1111 || !same(syncSubset(wire).enc, syncSubset(S).enc)) throw new Error('applied hits do not survive the wire');
      encSetInit('c_cal', 2, 0); encSetInit('c_bode', 1, 0); encNext(); const s0 = cal.strain||0; encTurnUse('cal','act'); encTurnUse('cal','man2'); encTurnUse('cal','man2');
      if(!S.enc.c_cal.act || S.enc.c_cal.man!==2 || cal.strain!==s0+2) throw new Error('a second maneuver should cost 2 strain once');
      encNext(); encNext(); if(S.enc.cur!=='c_cal' || S.enc.c_cal.act || S.enc.c_cal.man) throw new Error('action and maneuver should come back on your turn');
      ENC_UI.pc = 'cal'; for(const k of Object.keys(ABIL_CATS)){ encPanelSet('cat', k); const ph = document.getElementById('encPanel').innerHTML; if(/undefined|NaN|\[object/.test(ph) || !/Cal's options/.test(ph)) throw new Error('options panel broken on '+k); }
      encPanelSet('cat','offense'); const ph = document.getElementById('encPanel').innerHTML; if(!/Light Blaster Pistol/.test(ph) || !/Unarmed/.test(ph) || !/This turn:/.test(ph) || !/Imperial Assassin/.test(ph)) throw new Error('offense panel should list weapons, targets and the turn tracker');
      encEnd(); renderEnc(); if(!/Cal's options/.test(document.getElementById('encPanel').innerHTML)) throw new Error('options should stay available outside an encounter');
      print(`  encounter options: talents sort into offense / defense / force / utility; range, defense and Adversary set the pool; hits apply once after soak and Pierce; second maneuver costs strain`);
      S = keepS; setRolls(ROLLS.filter(e=>![1111,2222,3333].includes(e.ts))); Object.assign(ENC_UI, { me:'', pc:'', tgt:'', tpc:'', rng:'', cat:'offense' }); poolClear(); gmMode(false); showTab('tracker'); }
    // Map: sources, tokens, scale and range bands, lines, range fed into attacks, hidden tokens, per-key merge, the wire
    { const keepS = S; S = freshState(); showTab('enc'); gmMode(true);
      if('map' in syncSubset(S)) throw new Error('no map should mean no map key on the wire');
      for(const bad of ['javascript:alert(1)', 'img/maps/../../x.png', 'img/x.png', 'data:image/png;base64,AAAA', 'https://a.b/c.png" onerror="x', '']) if(mapSrcOk(bad)) throw new Error('bad map source accepted: '+bad);
      for(const ok of ['img/maps/Docking Bay (night).jpg', 'https://example.com/a/map.png?x=1', 'room:ab12cd34ef']) if(!mapSrcOk(ok)) throw new Error('good map source refused: '+ok);
      mapSetSrc('img/maps/test.png'); if(!mapOn() || S.map.sc!==0) throw new Error('map did not start');
      MAP_UI.asp = 0.5; mapCal(0.1); if(S.map.sc!==0.1 || MAP_UI.tool!=='move') throw new Error('calibration wrong');
      const bands = [[0.015,'Engaged'],[0.09,'Short'],[0.25,'Medium'],[0.7,'Long'],[0.95,'Extreme']]; for(const [d, want] of bands) if(mapBandFor(d)!==want) throw new Error(`${d} map widths should be ${want}, got ${mapBandFor(d)}`);
      if(mapDist({x:0,y:0},{x:0,y:1})!==0.5) throw new Error('vertical distance should use the picture\'s shape');
      encStart('combat'); const tk = encAddNpc(npcNew(ADV_DB.findIndex(a=>a.n==='Imperial Stormtrooper')).id, 3);
      const p0 = mapPos('c_cal'), n0 = mapPos(tk); if(!(p0.x<0.2) || !(n0.x>0.8) || S.map.t_c_cal) throw new Error('unplaced tokens should wait at the edges without being stored');
      if(mapBandKeys('c_cal', tk)!=='') throw new Error('range should not be read off the map until both tokens are placed');
      mapTokenSet('c_cal', 0.2, 0.5); mapTokenSet(tk, 0.45, 0.5); if(mapBandKeys('c_cal', tk)!=='Medium') throw new Error('0.25 apart at scale 0.1 should be Medium: '+mapBandKeys('c_cal', tk));
      mapTokenSet('constructor', 0.5, 0.5); mapTokenSet('c_cal', 7, -3); if(S.map.t_constructor || S.map.t_c_cal.x!==1 || S.map.t_c_cal.y!==0) throw new Error('token positions should be validated and clamped');
      mapTokenSet('c_cal', 0.2, 0.5);
      const cal = st('cal'); cal.inv.push({ name:'Light Blaster Pistol', ref:'Light Blaster Pistol', type:'Weapon', eq:1, qty:1 });
      encNpcSet(tk,'hid',0); ENC_UI.tgt = tk; ENC_UI.rng = 'Extreme'; encAttackPC('cal', cal.inv.length-1);
      if(DICE_UI.pool.d!==2 || !/Medium range \(from the map\)/.test(DICE_UI.weapon.note)) throw new Error('the attack should take Medium from the map, not the manual pick: '+DICE_UI.weapon.note);
      encAttackPC('cal', -1); if(!/close to Engaged first/.test(DICE_UI.weapon.note)) throw new Error('a melee attack from Medium should say so');
      mapTokenSet(tk, 0.21, 0.5); encAttackPC('cal', cal.inv.length-1); if(DICE_UI.pool.d!==2 || !/Engaged range/.test(DICE_UI.weapon.note)) throw new Error('a pistol at Engaged should be Average');
      MAP_UI.color = 2; mapStrokeAdd([0.1,0.1,0.2,0.2,0.3,0.1]); mapStrokeAdd([0.5,0.5]); const lines = () => Object.keys(S.map).filter(k=>k.startsWith('d_'));
      if(lines().length!==1 || S.map[lines()[0]].c!==2 || S.map[lines()[0]].p.length!==6) throw new Error('drawing a line wrong');
      renderEnc(); const mh = document.getElementById('mapToks').innerHTML, sv = document.getElementById('mapSvg').innerHTML;
      if(!/data-k="c_cal"/.test(mh) || !/data-k="n_/.test(mh) || !/<i>3<\/i>/.test(mh) || !/polyline/.test(sv) || /undefined|NaN|\[object/.test(mh+sv)) throw new Error('map layers render wrong');
      MAP_UI.sel = 'c_cal'; renderMapLayers(); if((document.getElementById('mapSvg').innerHTML.match(/<circle/g)||[]).length!==MAP_BANDS.length || !/Stormtrooper <b>Engaged<\/b>|Imperial <b>Engaged<\/b>/.test(document.getElementById('mapInfo').innerHTML)) throw new Error('range rings or the range list missing: '+document.getElementById('mapInfo').innerHTML);
      encNpcSet(tk,'hid',1); gmMode(false); renderEnc(); if(/data-k="n_/.test(document.getElementById('mapToks').innerHTML) || /Set scale|remove map|upload/.test(document.getElementById('mapBar').innerHTML)) throw new Error('players should not see hidden tokens or the GM\'s map controls');
      gmMode(true); const wire = migrate(JSON.parse(JSON.stringify(syncSubset(S)))); if(!same(syncSubset(wire).map, syncSubset(S).map) || !Array.isArray(wire.map[lines()[0]].p) || wire.map.sc!==0.1) throw new Error('the map does not survive the wire');
      if(normMap({ on:1, src:'javascript:alert(1)', t_c_cal:{x:.5,y:.5} }).on) throw new Error('a bad source off the wire should mean no map');
      { const base = syncSubset(S), mine = JSON.parse(JSON.stringify(base)), theirs = JSON.parse(JSON.stringify(base));
        mine.map.t_c_cal = { x:0.6, y:0.6 }; theirs.map.t_c_bode = { x:0.3, y:0.3 }; delete theirs.map[lines()[0]];
        const m = threeWayMerge(base, mine, theirs); if(m.map.t_c_cal.x!==0.6 || !m.map.t_c_bode || m.map[lines()[0]]) throw new Error('two people moving different tokens should both land');
        const gone = JSON.parse(JSON.stringify(base)); delete gone.map; if(threeWayMerge(base, mine, gone).map) throw new Error('a map removed elsewhere should stay removed'); }
      mapUndo(); if(lines().length!==0) throw new Error('undo should remove my last line');
      mapClear('t'); if(Object.keys(S.map).some(k=>k.startsWith('t_'))) throw new Error('reset tokens wrong');
      mapSetSrc('https://example.com/other.png'); if(S.map.sc!==0 || S.map.src!=='https://example.com/other.png') throw new Error('a new map should start uncalibrated');
      mapRemove(); if(mapOn() || 'map' in syncSubset(S)) throw new Error('removing the map wrong'); renderEnc();
      gmMode(false); renderEnc(); if(document.getElementById('encMap').style.display!=='none') throw new Error('with no map, players should not see the map box');
      print(`  map: sources checked, tokens clamp and merge per token, one Short-range drag sets every band, attacks read their range from the map, hidden tokens stay hidden, survives the wire`);
      S = keepS; Object.assign(MAP_UI, { tool:'move', color:0, sel:'', ruler:null, drag:null, asp:0.625, mine:[] }); Object.assign(ENC_UI, { me:'', pc:'', tgt:'', tpc:'', rng:'', cat:'offense' }); poolClear(); showTab('tracker'); }
  })();
  // objectives: three columns, sub-tasks, pinning, the log, seeding from the Lore, and the wire
  (()=>{
    const keep = JSON.stringify(S), log0 = S.log.length; S.obj = []; OBJ_UI.open = true;
    const a = objAdd('main','Reach the Central Control Room'), b = objAdd('side','Find worker uniforms'), c = objAdd('threat','Who is following us?');
    if(!a.pin || b.pin || S.obj.length!==3 || objAdd('main','   ') || objAdd('nope','x')) throw new Error('adding objectives wrong');
    objSubAdd(a.id,'Change into uniforms'); objSubAdd(a.id,'Cross the hub'); objSubTick(a.id, a.subs[0].id, true);
    render(); const oh = document.getElementById('objectives').innerHTML;
    if(!/next: Cross the hub/.test(oh) || !/\(1\/2\)/.test(oh) || !/Side quests/.test(oh) || !/Threats &amp; mysteries|Threats & mysteries/.test(oh) || /undefined|NaN|\[object/.test(oh)) throw new Error('objectives panel render wrong');
    objPin(b.id); if(a.pin || !b.pin) throw new Error('pinning should move'); objSet(b.id,'done'); if(b.pin || b.st!=='done') throw new Error('a finished objective should drop its pin');
    const logged = S.log.slice(0, 12).map(x=>x.m).join('|'); if(!/New main objective/.test(logged) || !/new step/.test(logged) || !/done \(1 of 2\)/.test(logged) || !/Objective complete/.test(logged) || !/Now tracking/.test(logged)) throw new Error('objective changes should reach the event log');
    const q = Object.keys(LORE_DB.notes).find(id=>LORE_DB.notes[id].type==='quest' && objLoreCat(LORE_DB.notes[id])==='main' && objLoreList('main').includes(id));
    if(!q) throw new Error('no open main quest found in the Lore'); const lo = objAddFromLore('main', q); if(!lo || lo.lore!==q || lo.t!==LORE_DB.notes[q].t || objLoreList('main').includes(q)) throw new Error('adding from the Lore wrong');
    objSummary(); if(!/Objectives summary/.test(S.log[0].m) || !/Completed/.test(S.log[0].m)) throw new Error('objectives summary wrong');
    const w = migrate(JSON.parse(JSON.stringify(syncSubset(S)))).obj; if(w.length!==4 || w[0].subs.length!==2 || !w[0].subs[0].d || w[0].subs[1].d || w[1].st!=='done' || w[3].lore!==q) throw new Error('objectives lost on the wire');
    const stripped = JSON.parse(JSON.stringify(syncSubset(S))); delete stripped.obj; stripped.obj = { 0:{ id:'x1', cat:'side', t:'From the room' } }; const w2 = migrate(stripped).obj; if(w2.length!==1 || !Array.isArray(w2[0].subs) || w2[0].st!=='active') throw new Error('a bare objective from the room should be repaired');
    objDel(c.id); objClearFinished('side'); if(S.obj.length!==2) throw new Error('removing objectives wrong');
    print(`  objectives: add, steps, pin, complete, from Lore and summary all log and survive the wire`);
    S = migrate(JSON.parse(keep)); OBJ_UI.open = false;
  })();
  // event log: keeps a session's worth, signs notes, exports as plain text with the objectives
  (()=>{
    const keep = JSON.stringify(S), me = CLOUD.player; S.log = []; S.obj = []; CLOUD.player = 'Tester';
    for(let i=0;i<LOG_MAX+20;i++) logMsg('filler '+i); if(S.log.length!==LOG_MAX) throw new Error('log should keep '+LOG_MAX+' entries');
    S.log = S.log.slice(0,3);
    document.getElementById('noteIn').value = 'Thrass has a <sister>?'; addNote();
    if(!/Thrass has a &lt;sister>\?/.test(S.log[0].m) || !/Tester/.test(S.log[0].m) || S.log[0].c!=='ln') throw new Error('note not signed or not escaped');
    const o = objAdd('main','Reach the control room'); objSubAdd(o.id,'Find uniforms'); objSubTick(o.id,o.subs[0].id,true);
    const txt = logText();
    if(!/📝 Thrass has a <sister>\? — Tester/.test(txt) || /<span|<b>|&lt;/.test(txt) || !/Objectives as they stand/.test(txt) || !/- \[x\] Find uniforms/.test(txt) || txt.indexOf('Thrass') < txt.indexOf('filler')) throw new Error('log export wrong:\n'+txt);
    rebuildLog(); if(!/Event log · 7/.test(document.getElementById('logTitle').textContent)) throw new Error('log title count wrong: '+document.getElementById('logTitle').textContent);
    print(`  event log: keeps ${LOG_MAX} entries, notes are signed, export is plain text oldest-first with the objectives`);
    CLOUD.player = me; S = migrate(JSON.parse(keep));
  })();
  // talents on the dice: always-on Boost, ignored Setback, situational tick boxes, and the feed note
  (()=>{
    const keep = JSON.stringify(S), cal = st('cal'), sh = cal.sheet, n0 = ROLLS.length;
    const nd = Object.values(RULES_DB.talents).filter(t=>t.d); if(nd.length<40) throw new Error('talent dice did not import');
    for(const t of nd) for(const e of t.d){ if(!TD_WORD[e.t] || !(e.n>0) || !e.sk.length) throw new Error('bad talent dice entry'); for(const n of e.sk) if(!tdSkillKeys(n).length) throw new Error('talent dice names an unknown skill: '+n); }
    sh.tr = {}; sh.sk = { stealth:{r:2}, mechanics:{r:1}, ranged_light:{r:2} }; sh.xp = 900; cal.attr.ag = 3; cal.attr.int = 2;
    specAdd('cal','padawan-survivor-universal',true); for(const n of ['r1c1','r2c1','r2c2','r2c3']) treeBuy('cal','padawan-survivor-universal',n);   // Sleight of Mind: +1 Boost to Stealth
    specAdd('cal','mechanic-technician',true); for(const n of ['r1c1','r2c1','r2c2','r2c3']) treeBuy('cal','mechanic-technician',n);                 // Gearhead ×2: ignore 2 Setback on Mechanics
    specAdd('cal','gunslinger-smuggler',true); for(const n of ['r1c2','r1c3','r2c3']) treeBuy('cal','gunslinger-smuggler',n);                       // Quick Strike ×2: situational
    const tS = talentDice(cal,'stealth'), tM = talentDice(cal,'mechanics'), tR = talentDice(cal,'ranged_light');
    if(tS.auto!==1 || tM.ign!==2 || tM.auto || tR.opts.length!==1 || tR.opts[0].amt!==2 || tR.auto) throw new Error('talent dice wrong: '+JSON.stringify([tS,tM,tR]));
    SHEET_UI.id = 'cal'; render(); const row = skillRowHtml(cal, SKILLS.find(x=>x.k==='stealth')), rowM = skillRowHtml(cal, SKILLS.find(x=>x.k==='mechanics')), rowR = skillRowHtml(cal, SKILLS.find(x=>x.k==='ranged_light'));
    if(!/die sm d6 t-b/.test(row) || !/−2 ■/.test(rowM) || !/\+1 option/.test(rowR) || /undefined|NaN/.test(row+rowM+rowR)) throw new Error('skill rows should show talent dice');
    rollSkill('cal','stealth'); if(DICE_UI.pool.b!==1 || !DICE_UI.tal) throw new Error('always-on Boost should load with the pool'); rollPool(); if(!/Sleight of Mind/.test(ROLLS[ROLLS.length-1].tal||'')) throw new Error('feed should name the talent');
    rollSkill('cal','mechanics'); poolAdj('k',1); poolAdj('k',1); poolAdj('k',1); rollPool(); const rm = ROLLS[ROLLS.length-1];
    if(!/2 Setback ignored/.test(rm.tal||'') || parseRoll(rm.r).filter(d=>d[0]==='k').length!==1) throw new Error('two of three Setback should be ignored: '+JSON.stringify(rm));
    rollSkill('cal','ranged_light'); const p0 = JSON.stringify(DICE_UI.pool), oid = DICE_UI.tal.opts[0].id; tdToggle(oid,true); if(DICE_UI.pool.b!==2) throw new Error('ticking Quick Strike should add 2 Boost');
    tdToggle(oid,false); if(JSON.stringify(DICE_UI.pool)!==p0) throw new Error('unticking should put the pool back');
    DICE_UI.tal = { key:'x', auto:0, ign:0, notes:[], opts:[{id:'u',n:'True Aim',t:'up',amt:2,c:'test'},{id:'d',n:'Confidence',t:'df',amt:1,c:'test'}], on:{}, undo:{} }; Object.assign(DICE_UI.pool,{p:0,a:1,b:0,k:0,d:2,c:0,F:0});
    tdToggle('u',true); if(DICE_UI.pool.p!==1 || DICE_UI.pool.a!==1) throw new Error('upgrade twice from one Ability should give 1 Proficiency + 1 Ability'); tdToggle('d',true); if(DICE_UI.pool.d!==1) throw new Error('fewer Difficulty wrong');
    tdToggle('u',false); tdToggle('d',false); if(DICE_UI.pool.p!==0 || DICE_UI.pool.a!==1 || DICE_UI.pool.d!==2) throw new Error('undoing upgrades wrong');
    poolClear(); if(DICE_UI.tal) throw new Error('clearing the pool should drop the talents');
    const dr0 = sh.defRMod; specAdd('cal','nightsister-universal',true); for(const n of ['r1c4','r2c4','r3c4']) treeBuy('cal','nightsister-universal',n); if(sh.defRMod!==dr0+1) throw new Error('Sixth Sense should add ranged defense'); treeRefund('cal','nightsister-universal','r3c4'); if(sh.defRMod!==dr0) throw new Error('Sixth Sense refund');
    treeBuy('cal','padawan-survivor-universal','r2c4'); if(!sh.sk.lightsaber || !sh.sk.lightsaber.c) throw new Error('Secrets of the Jedi should make Lightsaber a career skill');
    specAdd('cal','sleeper-agent-spy',true); treeBuy('cal','sleeper-agent-spy','r1c4','Astrogation, medicine'); if(!sh.sk.astrogation.c || !sh.sk.medicine.c) throw new Error('Well Rounded should tick two chosen skills');
    print(`  talent dice: ${nd.length} talents carry dice effects; Boost loads with the pool, Setback is ignored on the roll, tick boxes apply and undo`);
    ROLLS.length = n0; S = migrate(JSON.parse(keep)); showTab('tracker');
  })();
  const rules = document.getElementById('rules').innerHTML;
  const bad = (rules.match(/undefined|NaN|\[object/g)||[]).length;
  print(`  advanced to ${clockStr()} · ${S.log.length} log entries · rules reference ${rules.length} chars, ${bad} broken interpolations`);
  const wire = syncSubset(S), back = migrate(JSON.parse(JSON.stringify(wire)));
  print(`  sync wire format round-trips without phantom diffs: ${same(wire, syncSubset(back))}`);
  if(bad){ const i=rules.search(/undefined|NaN|\[object/); print("  >>> "+rules.slice(Math.max(0,i-160), i+60).replace(/\s+/g," ")); } if(bad) throw new Error('broken interpolation in rules text');
})();
TEST
} > "$OUT"
"$JSC" "$OUT"
