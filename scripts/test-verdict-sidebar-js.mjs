// No browser required: execute the production JS with controlled page API inputs.
// Real DOM and installed key round-trip checks remain a separate browser-lease gate.
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
let result;
if (process.argv.includes('--source-only')) {
  const source=readFileSync(new URL('../helperFunctions.lua',import.meta.url),'utf8');
  const match=source.match(/return M\.browserJS\(bundleID, \[\[([\s\S]*?)\]\]\) == true/);
  if(!match) throw new Error('Could not extract the production JS literal');
  result={ok:true,code:match[1]};
} else {
const output = execFileSync('hs', ['-c', 'local ok,code=pcall(dofile,hs.configdir .. "/scripts/test-verdict-sidebar.lua"); print("VERDICT_JS:" .. hs.json.encode({ok=ok,code=code}))'], {encoding:'utf8'});
result=JSON.parse(output.split('\n').find(line=>line.startsWith('VERDICT_JS:')).slice(11));
if (!result.ok) throw new Error(result.code);
}
const selector='button#vd-pane-toggle[data-action="toggle-review-controls"][aria-controls="vd-pane-body"]';
const legacySelector='aside.vd-bar > .vd-pane-head > button.vd-pane-toggle[type="button"][aria-controls="vd-pane-body"]:not([id]):not([data-action])';
function suite(code) {
  const run=new Function('location','document','getComputedStyle','innerHeight','innerWidth','return '+code);
  const failures=[];
  const cases=[
    ['open/collapse/expand',{},true,2],
    ['installed legacy collapse/expand', {legacy:true},true,2],
    ['legacy submit-like label', {legacy:true,label:'Submit'},true,0],
    ['legacy ambiguous duplicate', {legacy:true,count:2},true,0],
    ['legacy missing controlled body', {legacy:true,body:false},true,0],
    ['legacy control outside review', {legacy:true,wrongContainer:true},true,0],
    ['non-Verdict', {review:false},false,0],
    ['index', {path:'/'},false,0],
    ['input', {editing:true},true,0],
    ['contenteditable', {editable:true},true,0],
    ['address bar', {focus:false},true,0],
    ['hidden', {height:0},true,0],
    ['invisible', {visibility:'hidden'},true,0],
    ['offscreen', {top:-1000,bottom:-990},true,0],
    ['disabled', {disabled:true},true,0],
    ['aria-disabled', {ariaDisabled:'true'},true,0],
    ['missing toggle', {count:0},true,0],
    ['ambiguous duplicate', {count:2},true,0],
    ['missing controlled body', {body:false},true,0],
    ['invalid expansion state', {expanded:'unknown'},true,0],
  ];
  for (const [name,options,handled,wantClicks] of cases) {
    let clicks=0, expanded=options.expanded??'true';
    const data={answers:{},comments:[],general:'synthetic unsent draft',status:'open'};
    const before=JSON.stringify(data);
    const controlled={};
    const panel={contains:value=>value===controlled && !options.wrongContainer};
    const button={disabled:!!options.disabled,
      closest:value=>value==='aside.vd-bar'?panel:null,
      getBoundingClientRect:()=>({width:20,height:options.height??20,top:options.top??5,bottom:options.bottom??25,right:25,left:5}),
      getAttribute:key=>({'aria-disabled':options.ariaDisabled??'false','aria-expanded':expanded,'aria-label':options.label??(expanded==='true'?'Collapse review controls':'Expand review controls')})[key],
      click:()=>{clicks++;expanded=expanded==='true'?'false':'true';},
    };
    const document={body:{classList:{contains:name=>name==='vd-review' && options.review!==false}},
      hasFocus:()=>options.focus!==false,
      activeElement:{isContentEditable:!!options.editable,closest:()=>options.editing?{}:null},
      querySelectorAll:value=>value===(options.legacy?legacySelector:selector)?Array(options.count??1).fill(button):[],
      getElementById:value=>value==='vd-pane-body' && options.body!==false?controlled:null,
    };
    for(let i=0;i<2;i++) {
      if(run({pathname:options.path??'/r/synthetic-review/'},document,()=>({visibility:options.visibility??'visible'}),800,1000)!==handled) failures.push(name+':handled');
      if((name==='open/collapse/expand' || name==='installed legacy collapse/expand') && expanded!==(i===0?'false':'true')) failures.push(name+':state');
    }
    if(clicks!==wantClicks || JSON.stringify(data)!==before) failures.push(name+':side effects');
  }
  return {checks:cases.length,failures};
}
const baseline=suite(result.code);
if(baseline.failures.length) throw new Error(baseline.failures.join(', '));
const mutations=[
 ['disabled guard',result.code.replace('!e.disabled','true'),'disabled:side effects'],
 ['focus and input guards',result.code.replace(/var focused[\s\S]*?(?=    var controlled)/,''),'input:side effects'],
 ['legacy label guard',result.code.replace("e.getAttribute('aria-label') === (expanded === 'true' ? 'Collapse review controls' : 'Expand review controls')",'true'),'legacy submit-like label:side effects'],
 ['controlled panel guard',result.code.replace('panel.contains(controlled)','true'),'legacy control outside review:side effects'],
 ['stable target',result.code.replace('button#vd-pane-toggle','button#wrong-toggle'),'open/collapse/expand:side effects'],
];
for(const [name,code,expected] of mutations) {
 if(code===result.code || !suite(code).failures.includes(expected)) throw new Error('Surviving mutation: '+name);
}
console.log('verdict-sidebar-js: '+baseline.checks+' controlled-page cases passed; 5 mutations killed; real browser acceptance is separate');
