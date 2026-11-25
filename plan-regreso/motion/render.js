// Renderiza rotulo.html a MP4 16:9 con audio.  Uso:  node render.js [salida.mp4]
const { chromium } = require('playwright');
const { execFileSync } = require('child_process');
const fs = require('fs'), os = require('os'), p = require('path');

const DIR = __dirname;
const OUT = p.resolve(process.argv[2] || p.join(DIR, 'rotulo-hora-15.mp4'));

(async () => {
  const tmp = fs.mkdtempSync(p.join(os.tmpdir(), 'rot-'));
  const b = await chromium.launch();
  const pg = await b.newPage({ viewport:{width:1920,height:1080}, deviceScaleFactor:1 });
  await pg.goto('file://' + p.join(DIR, 'rotulo.html'), { waitUntil:'load' });
  await pg.evaluate(() => document.fonts.ready);
  // Overrides por variable de entorno: no hace falta tocar el HTML para una tirada rápida
  const OV = {};
  for (const k of ['eyebrow','titulo','dato','pie','fondo','fondoImagen','acento','tinta','transicion','salida'])
    if (process.env[k.toUpperCase()] !== undefined) OV[k] = process.env[k.toUpperCase()];
  if (process.env.DURACION) OV.duracion = parseFloat(process.env.DURACION);
  if (process.env.FPS)      OV.fps      = parseInt(process.env.FPS);
  if (Object.keys(OV).length) {
    await pg.evaluate(o => { Object.assign(window.CONFIG, o); location.reload(); }, OV).catch(()=>{});
    await pg.goto('file://' + p.join(DIR,'rotulo.html') + '?o=' + encodeURIComponent(JSON.stringify(OV)), {waitUntil:'load'});
    await pg.evaluate(() => document.fonts.ready);
  }
  const C = await pg.evaluate(() => window.CONFIG);
  const N = Math.round(C.duracion * C.fps);

  for (let f = 0; f < N; f++) {
    await pg.evaluate(t => window.setT(t), f / C.fps);
    await pg.screenshot({ path: p.join(tmp, String(f).padStart(4,'0') + '.png') });
  }
  await b.close();
  console.log(`✓ ${N} fotogramas`);

  // ---------- audio sintetizado ----------
  const A = C.audio, D = C.duracion, hit = C.t.titulo;
  const ff = a => execFileSync('ffmpeg', ['-y','-hide_banner','-loglevel','error', ...a]);
  const ins = [], fc = [], mix = [];
  let ai = 1;            // la entrada 0 es la secuencia de imágenes
  if (A.viento) {
    ff(['-f','lavfi','-i',`anoisesrc=c=brown:r=48000:d=${D}:a=0.6`,
        '-af',`lowpass=f=360,volume=${A.volViento},afade=t=in:st=0:d=0.9,afade=t=out:st=${D-0.6}:d=0.6`,
        p.join(tmp,'wind.wav')]);
    ins.push('-i', p.join(tmp,'wind.wav')); mix.push(`[${ai++}:a]`);
  }
  if (A.impacto) {
    // sub que cae de 96 Hz a 34 Hz con cola larga
    ff(['-f','lavfi','-i',
        `aevalsrc='exp(-2.9*t)*sin(2*PI*(34+62*exp(-6*t))*t)*${A.volImpacto}':s=48000:d=${Math.min(2.8,D)}`,
        p.join(tmp,'sub.wav')]);
    // transitorio de ataque
    ff(['-f','lavfi','-i',`aevalsrc='exp(-42*t)*(random(7)*2-1)*0.32':s=48000:d=0.25`,
        p.join(tmp,'tick.wav')]);
    const ms = Math.round(hit*1000);
    ins.push('-i', p.join(tmp,'sub.wav'));  fc.push(`[${ai++}:a]adelay=${ms}|${ms}[s]`); mix.push('[s]');
    ins.push('-i', p.join(tmp,'tick.wav')); fc.push(`[${ai++}:a]adelay=${ms}|${ms}[k]`); mix.push('[k]');
  }
  let af = null;
  if (mix.length) {
    fc.push(`${mix.join('')}amix=inputs=${mix.length}:normalize=0,alimiter=limit=0.92,` +
            `afade=t=out:st=${D-0.3}:d=0.3,apad,atrim=0:${D}[a]`);
    af = fc.join(';');
  }

  const args = ['-y','-hide_banner','-loglevel','error',
    '-framerate', String(C.fps), '-i', p.join(tmp,'%04d.png'), ...ins];
  if (af) args.push('-filter_complex', af, '-map','0:v','-map','[a]',
                    '-c:a','aac','-b:a','320k','-ac','2','-ar','48000');
  args.push('-c:v','libx264','-profile:v','high','-crf','15',
            '-pix_fmt','yuv420p','-movflags','+faststart','-r',String(C.fps), OUT);
  execFileSync('ffmpeg', args);
  fs.rmSync(tmp, {recursive:true, force:true});
  console.log('✓ ' + OUT);
})();
