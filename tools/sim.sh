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
(function(){ fresh(); const cs=st('cal'); const it=cs.inv.find(i=>i.type==='Weapon'); let h=0; while((it.wear||0)<100&&h<50000){ tick(cs,1); h++; } print(`  weapon ambient wear 0→100: ${span(h)} temperate · +${WEAR_PER_USE}/use ⇒ ${Math.ceil(100/WEAR_PER_USE)} hard uses`); })();
print(`  ship: ${SHIP.fuelCap} t ⇒ cruising ${(SHIP.fuelCap/SHIP_ACTS.cruising.tph/24).toFixed(0)} d · hyperspace ${(SHIP.fuelCap/SHIP_ACTS.hyperspace.tph).toFixed(0)} h · one condition pip per ${SHIP_MAINT_WEEK/24} d powered`);

print('\n=== SMOKE TEST — UI code paths ===');
(function(){
  fresh(); buildRules(); render();
  startStatus('cal','meal'); startStatus('merrin','med30'); startStatus('kata','sleep',10); startStatus('bode','wash');
  advance(0.25); advance(0.5); advance(1); advance(12);
  drink('cal',OZ_PER_CANTEEN); eatSnack('pike'); useStim('gibbs'); wipeDown('tann'); cleanClothes('cal'); setForce('cal',3); setAttr('cal','br',3);
  swapPack('bd1'); rechargeAll('bd1'); tuneUp('alpha'); overhaul('alpha');
  addCond('cal','sick'); condLvl('cal','sick',1); addCond('bd1','ion'); partySetAct('travel'); partyAddCond('chilled'); rmCond('cal','sick');
  setEnv('scorching'); S.travelDest='Koboh'; S.travelEta=3;
  setShipAct('cruising'); energyAdj('shields',-1); energyAdj('engines',1); setSensorRange('Long'); fireTorp(); shipBurn(); repairSys('engines',-1);
  addInv('cal'); setInv('cal', st('cal').inv.length-1, 'type', 'Weapon'); useItem('cal', st('cal').inv.length-1); addCargo('cargo');
  showTab('items'); itemsSet('q','blaster pistol'); const hits = itemsFiltered().length; itemsSet('g','Gear'); itemsSet('c','Survival'); itemsSet('g',''); itemsSet('q','');
  hbAdd(); const hb = S.homebrew[0]; hbSet(hb.id,'n','Test Gadget'); hbSet(hb.id,'p','125'); hbSet(hb.id,'r',true); hbSet(hb.id,'e','abc'); hbSet(hb.id,'d','does a thing');
  giveItem('c0','cal'); giveItem('h'+hb.id,'bode'); itemsSet('q','test gadget'); const hbHit = itemsFiltered().length; itemsSet('q',''); hbDel(hb.id);
  advance(48); render();
  const items = document.getElementById('itemsBody').innerHTML, itemsBad = (items.match(/undefined|NaN|\[object/g)||[]).length;
  print(`  items: ${CATALOG.length} in catalog, ${hits} match "blaster pistol", homebrew round-trip ${hbHit===1?'ok':'FAILED'}, ${itemsBad} broken interpolations in the tab`);
  if(itemsBad || hbHit!==1 || !CATALOG.length) throw new Error('items tab smoke test failed');
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
  const saber = cal.inv.findIndex(x=>x.name==='Lightsaber'), kitArmor = cal.inv.find(x=>x.type==='Armor');
  giveItem(ci('Vibroknife'),'cal'); const knife = cal.inv.length-1; if(cal.inv[knife].sk!=='melee' || !cal.inv[knife].brn || weaponState(cal,cal.inv[knife]).total!==1+cal.attr.br) throw new Error('catalog weapon stats wrong');
  const pistolRow = st('bode').inv.find(x=>x.name==='Blaster pistol'), pw = weaponState(st('bode'), pistolRow);
  if(pw.sk!=='ranged_light' || pw.dam!==6 || pw.crit!==3 || pw.rng!=='Medium') throw new Error('kit weapon did not borrow catalog stats: '+JSON.stringify(pw));
  const soak0 = combatStats(cal).soak; gearAdd('cal','Armor'); const ar = cal.inv.length-1; gearSet('cal',ar,'name','Beskar Plating'); gearSet('cal',ar,'soak',3); gearSet('cal',ar,'def',2);
  gearSet('cal',knife,'q','Pierce 2, Defensive 1'); gearSet('cal',knife,'eq',1);
  const cb1 = combatStats(cal); if(cb1.soak!==soak0+3 || cb1.defR!==2 || cb1.defM!==3) throw new Error('derived soak/defense wrong: '+JSON.stringify(cb1));
  gearSet('cal',ar,'eq',0); if(combatStats(cal).soak!==soak0) throw new Error('stowed armor still counted');
  gearSet('cal',saber,'dam',7); gearSet('cal',saber,'crit',2); gearSet('cal',saber,'q','Breach 1, <u>Sunder</u>'); rollAttack('cal',saber);
  if(!DICE_UI.weapon || DICE_UI.weapon.dam!==7 || DICE_UI.pool.p!==5 || DICE_UI.label!=='Lightsaber') throw new Error('rollAttack wrong: '+JSON.stringify(DICE_UI));
  const nBefore = ROLLS.length; rollPool(); const atk = ROLLS[ROLLS.length-1]; if(ROLLS.length!==nBefore+1 || !atk.w || atk.w.n!=='Lightsaber') throw new Error('attack roll lost its weapon');
  const card = weaponCardHtml({n:'<b>X</b>',dam:7,crit:2,q:'q'}, parseRoll('p:sa p:x a:a d:f'));
  if(!/7 \+ 1 = <b>8<\/b>/.test(card) || !/critical available/.test(card) || /<b>X/.test(card.replace('<div class="wcard"><b>','')) ) throw new Error('weapon card wrong: '+card);
  rollSkill('cal','stealth'); if(DICE_UI.weapon) throw new Error('weapon stuck to a skill roll');
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
