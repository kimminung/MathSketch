// 소개 영상 렌더러 — intro.html 의 타임라인을 프레임 단위로 캡처해 영상으로 만든다.
// 준비: npm i playwright && npx playwright install chromium   (ffmpeg 필요)
//
//   node render.js stills 1.0 3.2 ...        -> stills/t_<time>.png
//   node render.js video intro.mp4 [fps]     -> PNG 프레임을 ffmpeg 로 파이프 (H.264, CRF 지정 가능: CRF=20)
//   node render.js frames <dir> [fps]        -> PNG 프레임을 폴더로 (GIF 인코딩용)
//
// 실제로 쓴 설정:
//   CRF=18 node render.js video ../intro.mp4 30
//   node render.js frames frames20 20
//   ffmpeg -framerate 20 -i frames20/f_%05d.png -vf "scale=960:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=256:stats_mode=diff[p];[b][p]paletteuse=dither=sierra2_4a:diff_mode=rectangle" -loop 0 ../intro.gif
// 첫 프레임과 마지막 프레임이 같은 제목 카드라 GIF가 끊김 없이 반복된다.
const { chromium } = require('playwright');
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

(async () => {
  const mode = process.argv[2] || 'stills';
  const dir = __dirname;
  const browser = await chromium.launch({ args: ['--allow-file-access-from-files'] });
  const page = await browser.newPage({ viewport: { width: 1920, height: 1080 }, deviceScaleFactor: 1 });
  page.on('pageerror', e => { console.error('PAGE ERROR', e.message); });
  await page.goto('file://' + path.join(dir, 'intro.html'));
  await page.evaluate(() => window.ready);
  await page.evaluate(t => window.renderFrame(t), 0.01); // 글꼴 워밍업
  await page.waitForTimeout(400);
  const duration = await page.evaluate(() => window.DURATION);

  if (mode === 'stills') {
    const out = path.join(dir, 'stills'); fs.mkdirSync(out, { recursive: true });
    for (const t of process.argv.slice(3).map(Number)) {
      await page.evaluate(t => window.renderFrame(t), t);
      await page.screenshot({ path: path.join(out, `t_${t.toFixed(2)}.png`) });
    }
  } else if (mode === 'frames') {
    const out = process.argv[3] || 'frames'; const fps = Number(process.argv[4] || 15);
    fs.mkdirSync(out, { recursive: true });
    const total = Math.round(duration * fps);
    for (let i = 0; i < total; i++) {
      await page.evaluate(t => window.renderFrame(t), i / fps);
      await page.screenshot({ path: path.join(out, `f_${String(i).padStart(5, '0')}.png`) });
      if (i % 100 === 0) console.log(`frame ${i}/${total}`);
    }
  } else {
    const out = process.argv[3] || 'out.mp4';
    const fps = Number(process.argv[4] || 30);
    const crf = String(process.env.CRF || 18);
    const total = Math.round(duration * fps);
    const ff = spawn('ffmpeg', ['-y', '-loglevel', 'error', '-f', 'image2pipe', '-framerate', String(fps), '-c:v', 'png', '-i', '-',
      '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', crf, '-preset', 'slow', '-tune', 'animation', '-movflags', '+faststart', out], { stdio: ['pipe', 'inherit', 'inherit'] });
    const t0 = Date.now();
    for (let i = 0; i < total; i++) {
      await page.evaluate(t => window.renderFrame(t), i / fps);
      const buf = await page.screenshot({ type: 'png' });
      if (!ff.stdin.write(buf)) await new Promise(r => ff.stdin.once('drain', r));
      if (i % 150 === 0) console.log(`frame ${i}/${total} (${((Date.now() - t0) / 1000).toFixed(0)}s)`);
    }
    ff.stdin.end();
    await new Promise(r => ff.on('close', r));
    console.log('done', total, 'frames in', ((Date.now() - t0) / 1000).toFixed(0), 's');
  }
  await browser.close();
})();
