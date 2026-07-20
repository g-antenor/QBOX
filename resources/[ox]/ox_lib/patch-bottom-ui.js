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
 *   1. progressBar    -> sobe do bottom 18% para 10vh
 *   2. progressCircle -> deixa de centralizar na tela quando position="middle"
 *   3. skillCheck     -> sai do centro da tela e vai para 16vh do bottom
 */
const fs = require('fs');
const path = require('path');

const ASSETS = path.join(__dirname, 'web', 'build', 'assets');

// Alinhado com nv_minigames (--stage-bottom) para manter o mesmo eixo vertical.
const BAR_BOTTOM = '10vh';
const SKILLCHECK_CENTER = '16vh';

const PATCHES = [
  {
    name: 'progressBar: bottom 18% -> ' + BAR_BOTTOM,
    from: 'bottom:"18%"',
    to: `bottom:"${BAR_BOTTOM}"`,
  },
  {
    name: 'progressCircle: nunca ocupar a tela inteira (sempre faixa inferior)',
    from: 'height:t.position==="middle"?"100%":"20%"',
    to: 'height:"20%"',
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
