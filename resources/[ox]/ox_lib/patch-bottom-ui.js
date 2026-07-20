/**
 * ox_lib — patch de posicionamento "bottom-center".
 *
 * O bundle de web/build é minificado e o source do ox_lib nao esta versionado
 * aqui, entao as alteracoes de layout sao aplicadas por substituicao textual
 * direta sobre os style-objects do emotion/Mantine.
 *
 * REAPLICAR sempre que ox_lib for atualizado ou reconstruido:
 *   node patch-bottom-ui.js
 *
 * O script e idempotente: rodar duas vezes nao duplica nada.
 *
 * Alvos:
 *   1. progressBar    -> fica a 70px da base
 *   2. progressCircle -> fica a 70px da base
 *   3. skillCheck     -> sai do centro da tela e vai para 16vh do bottom
 */
const fs = require('fs');
const path = require('path');

const ASSETS = path.join(__dirname, 'web', 'build', 'assets');

// Alinhado com nv_minigames (--stage-bottom) para manter o mesmo eixo vertical.
const BAR_BOTTOM = '70px';
const SKILLCHECK_CENTER = '16vh';

const PATCHES = [
  {
    name: 'tema: paleta grafite fria do redesign',
    from: 'iv1=["#e6e4e3","#c8c5c9","#86828a","#4c4850","#232025","#232025","#17161a","#17161a","#0f0e10","#0c0c0e"]',
    to: 'iv1=["#f2f3f5","#d9dce1","#a7abb4","#737984","#2a2d34","#22252b","rgba(20,22,26,.94)","#17191e","#101216","#090a0c"]',
  },
  {
    name: 'tema: vermelho #e5484d',
    from: 'fv1=["#ffe8ea","#ffc9ce","#ff9aa4","#ff6070","#ff3346","#ff2438","#ff2438","#e01d30","#c0192a","#9c1421"]',
    to: 'fv1=["#fff0f0","#ffd9da","#ffb3b5","#f98286","#f05b60","#e5484d","#e5484d","#cf3f44","#ad3438","#85282b"]',
  },
  {
    name: 'tema: tipografia, raios e sombras',
    from: 'fontFamily:"Roboto",primaryColor:"brand",primaryShade:{dark:6,light:6},defaultRadius:"sm",radius:{sm:4},white:"#e6e4e3",black:"#0c0c0e"',
    to: 'fontFamily:"Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif",primaryColor:"brand",primaryShade:{dark:6,light:6},defaultRadius:"md",radius:{sm:6,md:8},white:"#f2f3f5",black:"#090a0c"',
  },
  {
    name: 'tema: sombras do novo layout',
    from: 'shadows:{sm:"0 2px 6px rgba(0, 0, 0, 0.45)",md:"0 6px 18px rgba(0, 0, 0, 0.55)"}',
    to: 'shadows:{sm:"0 10px 30px rgba(0,0,0,.24)",md:"0 18px 48px rgba(0,0,0,.34)"}',
  },
  {
    name: 'context menu: 286px centralizado a direita',
    from: 'container:{position:"absolute",top:"15%",right:"25%",width:320}',
    to: 'container:{position:"fixed",top:"50%",right:28,transform:"translateY(-50%)",width:286}',
  },
  {
    name: 'menu simples: largura 286px',
    from: 'fontFamily:"Roboto",width:384}',
    to: 'fontFamily:"Inter, ui-sans-serif, system-ui, sans-serif",width:286}',
  },
  {
    name: 'menu simples: centralizado a direita',
    from: 'container:{position:"absolute",pointerEvents:"none",marginTop:t.position==="top-left"||t.position==="top-right"?5:0,marginLeft:t.position==="top-left"||t.position==="bottom-left"?5:0,marginRight:t.position==="top-right"||t.position==="bottom-right"?5:0,marginBottom:t.position==="bottom-left"||t.position==="bottom-right"?5:0,right:t.position==="top-right"||t.position==="bottom-right"?1:void 0,left:t.position==="bottom-left"?1:void 0,bottom:t.position==="bottom-left"||t.position==="bottom-right"?1:void 0,fontFamily:"Inter, ui-sans-serif, system-ui, sans-serif",width:286}',
    to: 'container:{position:"fixed",pointerEvents:"none",top:"50%",right:28,transform:"translateY(-50%)",fontFamily:"Inter, ui-sans-serif, system-ui, sans-serif",width:286}',
  },
  {
    name: 'cabecalho menu simples: largura 286px',
    from: 'height:46,width:384,display:"flex"',
    to: 'height:45,width:286,display:"flex"',
  },
  {
    name: 'context menu: raio de 8px',
    from: 'borderRadius:4,overflow:"hidden",boxShadow:e.shadows.sm',
    to: 'borderRadius:8,overflow:"hidden",boxShadow:e.shadows.md',
  },
  {
    name: 'notificacoes: largura, painel e tipografia',
    from: 'container:{width:300,height:"fit-content",backgroundColor:e.colors.dark[6],color:e.colors.dark[0],padding:12,borderRadius:e.radius.sm,border:`1px solid ${e.colors.dark[4]}`,borderLeft:`2px solid ${e.colors.dark[3]}`,fontFamily:"Roboto",boxShadow:e.shadows.sm}',
    to: 'container:{width:286,height:"fit-content",backgroundColor:e.colors.dark[6],color:e.colors.dark[0],padding:"11px 13px 11px 15px",borderRadius:e.radius.md,border:`1px solid ${e.colors.dark[4]}`,borderLeft:`2px solid ${e.colors.dark[3]}`,fontFamily:"Inter, ui-sans-serif, system-ui, sans-serif",boxShadow:e.shadows.sm}',
  },
  {
    name: 'notificacoes: cores de estado',
    from: 'case"error":s="#ff2438";break;case"success":s="#3ddc84";break;case"warning":s="#e0a83d";break;default:s="#4a90d9"',
    to: 'case"error":s="#e5484d";break;case"success":s="#39b980";break;case"warning":s="#d79a36";break;default:s="#4d8ed8"',
  },
  {
    name: 'text UI: dimensoes e offset inferior',
    from: 'container:{fontSize:13,padding:"8px 12px",margin:8,backgroundColor:e.colors.dark[6],color:e.colors.dark[2],border:`1px solid ${e.colors.dark[4]}`,fontFamily:"Roboto",borderRadius:e.radius.sm,boxShadow:e.shadows.sm}',
    to: 'container:{fontSize:11,padding:"7px 10px",margin:t.position==="bottom-center"?24:8,backgroundColor:e.colors.dark[6],color:e.colors.dark[2],border:`1px solid ${e.colors.dark[4]}`,fontFamily:"Inter, ui-sans-serif, system-ui, sans-serif",borderRadius:e.radius.sm,boxShadow:e.shadows.sm}',
  },
  {
    name: 'modal: raio de 10px',
    from: 'borderRadius:4},header:{marginBottom:12',
    to: 'borderRadius:10},header:{marginBottom:12',
  },
  {
    name: 'progress bar: migrar offset antigo para 70px',
    from: 'bottom:"10vh"',
    to: 'bottom:"70px"',
  },
  {
    name: 'progress circle: offset fixo de 70px',
    from: 'container:{width:"100%",height:"20%",bottom:0,position:"absolute"',
    to: 'container:{width:"100%",height:"auto",bottom:70,position:"absolute"',
  },
  {
    name: 'progressBar: bottom 18% -> ' + BAR_BOTTOM,
    from: 'bottom:"18%"',
    to: `bottom:"${BAR_BOTTOM}"`,
  },
  {
    name: 'skillCheck (svg): centro da tela -> ' + SKILLCHECK_CENTER + ' do bottom',
    // O svg tem 500x500 com o circulo em cy=250, logo o centro do circulo fica
    // a 250px do rodape da caixa: descontamos isso do offset desejado.
    from: 'top:"50%",left:"50%",transform:"translate(-50%, -50%)",r:50',
    to: `bottom:"calc(${SKILLCHECK_CENTER} - 250px)",left:"50%",transform:"translateX(-50%)",r:50`,
  },
  {
    name: 'skillCheck (keycap): acompanha o centro do circulo',
    from:
      'button:{position:"absolute",left:"50%",top:"50%",transform:"translate(-50%, -50%)",backgroundColor:e.colors.dark[5]',
    to: `button:{position:"absolute",left:"50%",bottom:"${SKILLCHECK_CENTER}",transform:"translate(-50%, 50%)",backgroundColor:e.colors.dark[5]`,
  },
];

const bundles = fs
  .readdirSync(ASSETS)
  .filter((f) => f.startsWith('index-') && f.endsWith('.js'));

if (!bundles.length) {
  console.error('Nenhum bundle index-*.js encontrado em', ASSETS);
  process.exit(1);
}

let touched = 0;

for (const file of bundles) {
  const full = path.join(ASSETS, file);
  let src = fs.readFileSync(full, 'utf8');
  const before = src;
  const report = [];

  for (const p of PATCHES) {
    const hits = src.split(p.from).length - 1;
    if (hits === 0) {
      // Ja aplicado (ou o ox_lib mudou o codigo).
      report.push(
        src.includes(p.to)
          ? `  = ${p.name} (ja aplicado)`
          : `  ! ${p.name} — ALVO NAO ENCONTRADO, revisar manualmente`
      );
      continue;
    }
    if (hits > 1) {
      report.push(`  ! ${p.name} — ${hits} ocorrencias, abortado por seguranca`);
      continue;
    }
    src = src.replace(p.from, p.to);
    report.push(`  + ${p.name}`);
  }

  console.log(file);
  report.forEach((l) => console.log(l));

  if (src !== before) {
    if (!fs.existsSync(full + '.bak')) fs.writeFileSync(full + '.bak', before);
    fs.writeFileSync(full, src);
    touched++;
  }
}

console.log(touched ? `\nOK — ${touched} bundle(s) atualizado(s).` : '\nNada a fazer.');
