/* آيات تتلى — تركيب المقطع في متصفح الزائر للأجهزة القادرة.
   الخادم يرسل الإطارات الشفافة والصوت والخلفية، والمتصفح يركبها ويسجلها MP4.
   أي تعذر => يرجع الموقع تلقائيا للتوليد على الخادم. */
(function () {
  'use strict';
  var OFF = 'ayt_cr_off_v1';
  function mime() {
    if (!window.MediaRecorder || !MediaRecorder.isTypeSupported) return null;
    var c = ['video/mp4;codecs=avc1.42E01E,mp4a.40.2', 'video/mp4;codecs=avc1,mp4a.40.2', 'video/mp4'];
    for (var i = 0; i < c.length; i++) if (MediaRecorder.isTypeSupported(c[i])) return c[i];
    return null; /* MP4 فقط: WebM لا تقبله واتساب وتيك توك جيدا */
  }
  function ok() {
    try { if (localStorage.getItem(OFF)) return false; } catch (e) {}
    try {
      var cv = document.createElement('canvas');
      if (!cv.captureStream || !(window.AudioContext || window.webkitAudioContext)) return false;
    } catch (e) { return false; }
    var cores = navigator.hardwareConcurrency || 2, mem = navigator.deviceMemory || 4;
    var slowNet = navigator.connection && (navigator.connection.saveData || /2g/.test(navigator.connection.effectiveType || ''));
    return !!mime() && cores >= 4 && mem >= 4 && !slowNet;
  }
  function disable() { try { localStorage.setItem(OFF, '1'); } catch (e) {} }
  function img(u) {
    return new Promise(function (res, rej) { var i = new Image(); i.decoding = 'async'; i.onload = function () { res(i); }; i.onerror = rej; i.src = u; });
  }
  function vid(u) {
    return new Promise(function (res, rej) {
      var v = document.createElement('video'), t = setTimeout(function () { rej(new Error('bg timeout')); }, 30000);
      v.muted = true; v.loop = true; v.playsInline = true; v.setAttribute('playsinline', ''); v.preload = 'auto';
      v.oncanplay = function () { v.oncanplay = null; clearTimeout(t); res(v); }; v.onerror = function () { clearTimeout(t); rej(new Error('bg error')); };
      v.src = u; v.load();
    });
  }
  async function run(manUrl, onP) {
    var base = manUrl.replace(/[^\/]+$/, '');
    var m = await (await fetch(manUrl, { cache: 'no-store' })).json();
    var W = m.w, H = m.h, fps = m.fps || 30;
    var names = Array.from(new Set(m.frames.map(function (f) { return f[0]; }))), imgs = {};
    await Promise.all(names.map(async function (n) { imgs[n] = await img(base + n); }));
    var bg = null;
    if (m.bg.type === 'video') bg = await vid(base + m.bg.src); else if (m.bg.type === 'image') bg = await img(base + m.bg.src);
    var AC = window.AudioContext || window.webkitAudioContext, ac = new AC();
    var buf = await ac.decodeAudioData(await (await fetch(base + m.audio)).arrayBuffer());
    var tl = [], acc = 0;
    m.frames.forEach(function (f) { tl.push([acc, imgs[f[0]]]); acc += f[1]; });
    var total = Math.min(m.total || acc, buf.duration + 0.3);
    function frameAt(t) { var lo = 0, hi = tl.length - 1; while (lo < hi) { var mid = (lo + hi + 1) >> 1; if (tl[mid][0] <= t) lo = mid; else hi = mid - 1; } return tl[lo][1]; }
    var cv = document.createElement('canvas'); cv.width = W; cv.height = H;
    var cx = cv.getContext('2d', { alpha: false });
    function draw(t) {
      if (!bg) { cx.fillStyle = '#0b1f1a'; cx.fillRect(0, 0, W, H); }
      else {
        var iw = bg.videoWidth || bg.naturalWidth, ih = bg.videoHeight || bg.naturalHeight, s, ox = 0, oy = 0;
        if (m.bg.type === 'image' && m.bg.motion) { s = 1; var mx = (iw - W) / 2, my = (ih - H) / 2; ox = mx * 0.9 * Math.sin(t / 9); oy = my * 0.9 * Math.cos(t / 11); }
        else s = Math.max(W / iw, H / ih);
        if (m.bg.blur) cx.filter = 'blur(5px)';
        cx.drawImage(bg, (W - iw * s) / 2 + ox, (H - ih * s) / 2 + oy, iw * s, ih * s);
        cx.filter = 'none';
        if (m.bg.dim) { cx.fillStyle = 'rgba(0,0,0,' + (m.bg.dim / 100) + ')'; cx.fillRect(0, 0, W, H); }
      }
      cx.drawImage(frameAt(t), 0, 0, W, H);
    }
    var mt = mime(), dest = ac.createMediaStreamDestination(), src = ac.createBufferSource();
    src.buffer = buf; src.connect(dest);
    var stream = new MediaStream(cv.captureStream(fps).getVideoTracks().concat(dest.stream.getAudioTracks()));
    var rec = new MediaRecorder(stream, { mimeType: mt, videoBitsPerSecond: 6000000, audioBitsPerSecond: 160000 }), chunks = [];
    rec.ondataavailable = function (e) { if (e.data && e.data.size) chunks.push(e.data); };
    var stopped = new Promise(function (res, rej) { rec.onstop = res; rec.onerror = function (e) { rej(e.error || e); }; });
    draw(0);
    if (bg && bg.play) { try { await bg.play(); } catch (e) {} }
    if (ac.state !== 'running') { await Promise.race([ac.resume(), new Promise(function (r) { setTimeout(r, 3000); })]); if (ac.state !== 'running') throw new Error('audio blocked'); }
    rec.start(1000);
    var t0 = ac.currentTime + 0.1; src.start(t0);
    await new Promise(function (res, rej) {
      var last = -1, guard = setTimeout(function () { rej(new Error('render timeout')); }, (total + 30) * 1000);
      (function tick() {
        var t = ac.currentTime - t0;
        if (t >= total) { clearTimeout(guard); res(); return; }
        if (t >= 0) { draw(t); var p = Math.min(99, Math.round(100 * t / total)); if (p !== last) { last = p; if (onP) onP(p); } }
        if (document.hidden) setTimeout(tick, 1000 / fps); else requestAnimationFrame(tick);
      })();
    });
    await new Promise(function (r) { setTimeout(r, 250); });
    rec.stop(); await stopped;
    try { src.stop(); } catch (e) {}
    try { ac.close(); } catch (e) {}
    if (bg && bg.pause) bg.pause();
    var blob = new Blob(chunks, { type: 'video/mp4' });
    if (blob.size < 20000) throw new Error('empty recording');
    if (onP) onP(100);
    return { url: URL.createObjectURL(blob), ext: '.mp4', blob: blob };
  }
  window.CR = { ok: ok, run: run, disable: disable };
})();
