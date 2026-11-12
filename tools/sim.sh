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
