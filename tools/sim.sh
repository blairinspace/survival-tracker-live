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
  render(); if(/Datapad/.test(invSection(pk)) || !/1 stowed/.test(invSection(pk)) || !/Multitool/.test(invSection(pk))) throw new Error('card inventory should list carried items only');
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
  const cardInv = invSection(st('cal')); if((cardInv.match(/<details/g)||[]).length!==5 || !/Consumables/.test(cardInv) || !/Tools/.test(cardInv) || !/Weapons/.test(cardInv) || !/Armor/.test(cardInv) || /undefined|NaN/.test(cardInv)) throw new Error('card should have five inventory dropdowns');
  const crate = gearHtml(st('cal')); if(!/Personal Item Storage Crate/.test(crate) || (crate.match(/<details/g)||[]).length!==6 || !/Consumables/.test(crate) || /undefined|NaN/.test(crate)) throw new Error('sheet inventory should be a crate with three dropdowns');
  sheetOpen('armor',false); if(/<details class="sfold" open[^>]*'armor'/.test(gearHtml(st('cal'))) || !/<details class="sfold" open[^>]*'weapons'/.test(gearHtml(st('cal')))) throw new Error('dropdown open state not remembered'); sheetOpen('armor',true);
  const ordC = [...invSection(st('cal')).split('🎒 Gear')[1].matchAll(/<td><span class="[a-z]*" title="[^"]*">([^<]+)</g)].map(m=>m[1]); if(ordC.length<3 || ordC.join('|')!==[...ordC].sort((a,b)=>a.localeCompare(b,undefined,{sensitivity:'base',numeric:true})).join('|')) throw new Error('card gear not alphabetical: '+ordC.join(', '));
  const invBefore = JSON.stringify(st('cal').inv.map(x=>x.name)); render(); if(JSON.stringify(st('cal').inv.map(x=>x.name))!==invBefore) throw new Error('sorting changed the stored order');
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
