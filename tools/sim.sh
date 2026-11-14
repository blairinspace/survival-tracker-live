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
    if(RULES_DB.species.length<9 || RULES_DB.careers.length<20) throw new Error('species / careers did not load');
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
