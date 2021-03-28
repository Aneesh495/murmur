"use strict";
(() => {
  const data = JSON.parse(document.getElementById("review-data").textContent);
  const {plan, analysis} = data;
  const audio = document.getElementById("audio");
  const canvas = document.getElementById("wave");
  const ctx = canvas.getContext("2d");
  const $ = id => document.getElementById(id);
  const duration = plan.frames / plan.rate;
  let zoom = 1, viewStart = 0, selection = null, dragging = null, looping = false;
  let animation = null;
  const stamp = seconds => {
    const ms = Math.max(0, Math.round(seconds * 1000));
    return `${String(Math.floor(ms / 60000)).padStart(2,"0")}:${String(Math.floor(ms / 1000) % 60).padStart(2,"0")}.${String(ms % 1000).padStart(3,"0")}`;
  };
  const node = (tag, text, cls) => {
    const n = document.createElement(tag);
    if (text !== undefined) n.textContent = text;
    if (cls) n.className = cls;
    return n;
  };
  const error = message => { $("error").textContent = message; $("error").hidden = false; };
  const seek = seconds => { audio.currentTime = Math.max(0, Math.min(duration, seconds)); update(); };
  const jump = (label, seconds, parent, suffix) => {
    const b = node("button", label, "jump");
    b.append(node("span", suffix || stamp(seconds)));
    b.addEventListener("click", () => seek(seconds)); parent.append(b);
  };
  const source = id => plan.sources.find(s => s.id === id);
  const viewLength = () => duration / zoom;
  const clampView = () => { viewStart = Math.max(0, Math.min(duration - viewLength(), viewStart)); };
  const selectionClips = () => {
    if (!selection) return [];
    const lo = Math.floor(selection[0] * plan.rate), hi = Math.ceil(selection[1] * plan.rate);
    return plan.clips.map(c => ({c, lo: Math.max(lo, c.at), hi: Math.min(hi, c.at + c.frames)})).filter(x => x.lo < x.hi);
  };
  const updateSelection = () => {
    $("selection").textContent = selection ? `${stamp(selection[0])} / ${stamp(selection[1])}` : "No selection";
    $("patch").disabled = selectionClips().length === 0;
    if (!selection) { looping = false; $("loop").setAttribute("aria-pressed", "false"); }
  };
  const draw = () => {
    const bounds = canvas.getBoundingClientRect(), dpr = window.devicePixelRatio || 1;
    if (canvas.width !== Math.round(bounds.width*dpr) || canvas.height !== Math.round(bounds.height*dpr)) {
      canvas.width = Math.round(bounds.width*dpr); canvas.height = Math.round(bounds.height*dpr);
    }
    const w = bounds.width, h = bounds.height, length = viewLength();
    ctx.setTransform(dpr,0,0,dpr,0,0); ctx.clearRect(0,0,w,h);
    const x = seconds => (seconds-viewStart)/length*w;
    ctx.strokeStyle = "#a6cdb114"; ctx.lineWidth = 1;
    for(let i=0;i<9;i++){const at=i*w/8;ctx.beginPath();ctx.moveTo(at,0);ctx.lineTo(at,h);ctx.stroke();}
    plan.clips.forEach(c => c.redactions.forEach(r => {
      const a=x(r.start/plan.rate), b=x(r.end/plan.rate);
      ctx.fillStyle="#dc8e5a20"; ctx.fillRect(a,0,b-a,h);
      ctx.fillStyle="#dc8e5a";ctx.fillRect(a,0,Math.max(1,b-a),2);
    }));
    const waves=analysis.audio.waveform, ch=h/waves.length;
    waves.forEach((wave,c) => {
      const mid=ch*(c+.5), scale=ch*.37;
      ctx.strokeStyle="#74947c35";ctx.beginPath();ctx.moveTo(0,mid);ctx.lineTo(w,mid);ctx.stroke();
      ctx.strokeStyle=c===0?"#a6cdb1":"#7fae8b";ctx.lineWidth=Math.max(1,w/wave.length/zoom);
      wave.forEach((v,i) => {
        const at=x((i+.5)/wave.length*duration);
        if(at>=-2&&at<=w+2){ctx.beginPath();ctx.moveTo(at,mid-v[1]*scale);ctx.lineTo(at,mid-v[0]*scale);ctx.stroke();}
      });
      ctx.fillStyle="#75947f";ctx.font="9px monospace";ctx.fillText(waves.length===1?"MONO":c===0?"L":"R",7,ch*c+17);
    });
    if(selection){ctx.fillStyle="#c4dec52b";ctx.fillRect(x(selection[0]),0,x(selection[1])-x(selection[0]),h);}
    const cursor=x(audio.currentTime||0);ctx.strokeStyle="#e9b786";ctx.lineWidth=1;ctx.beginPath();ctx.moveTo(cursor,0);ctx.lineTo(cursor,h);ctx.stroke();
    ctx.fillStyle="#e9b786";ctx.beginPath();ctx.moveTo(cursor-4,0);ctx.lineTo(cursor+4,0);ctx.lineTo(cursor,7);ctx.fill();
    $("view-start").textContent=stamp(viewStart);$("view-mid").textContent=stamp(viewStart+length/2);$("view-end").textContent=stamp(viewStart+length);
  };
  const update = () => {
    const t=audio.currentTime||0, frame=Math.min(plan.frames-1,Math.floor(t*plan.rate));
    $("clock").textContent=stamp(t);$("frame").textContent=`FRAME ${Math.max(0,frame).toLocaleString()}`;
    const active=plan.clips.filter(c=>frame>=c.at&&frame<c.at+c.frames);
    $("contributors").replaceChildren();
    active.forEach(c=>{
      const s=source(c.source), at=c.sourceStart+(frame-c.at)*s.rate/plan.rate;
      const masked=s.redactions.some(r=>at>=r.start&&at<r.end);
      $("contributors").append(node("div",`${c.id} / ${c.source} / source ${stamp(at/s.rate)}${masked?" / redacted":""}`));
    });
    if(!active.length) $("contributors").append(node("div","No active clip. Effect tails may remain."));
    draw();
  };
  const tick = () => {
    if(looping&&selection&&audio.currentTime>=selection[1]) audio.currentTime=selection[0];
    if(zoom>1&&(audio.currentTime>viewStart+viewLength()||audio.currentTime<viewStart)){viewStart=audio.currentTime;clampView();}
    update(); if(!audio.paused) animation=requestAnimationFrame(tick); else animation=null;
  };
  const toggle = async () => {
    try { if(audio.paused){if(looping&&selection&&(audio.currentTime<selection[0]||audio.currentTime>=selection[1]))seek(selection[0]);await audio.play();}else audio.pause(); }
    catch(e){error(`Audio playback failed: ${e.message}. Open audio.wav in a local player.`);}
  };
  $("duration").textContent=stamp(duration);
  $("format").textContent=`${plan.rate.toLocaleString()} Hz / ${plan.channels===1?"mono":"stereo"} / ${plan.clips.length} clips`;
  $("clip-count").textContent=`${plan.clips.length} CLIPS`;
  plan.clips.forEach(c=>{
    const row=node("div",undefined,"clip"), text=node("div");text.append(node("strong",c.id));
    text.append(node("small",`${c.source} / ${stamp(c.at/plan.rate)} → ${stamp((c.at+c.frames)/plan.rate)} / ${c.gainDb} dB`));
    const button=node("button","Listen ↗");button.addEventListener("click",()=>seek(c.at/plan.rate));row.append(node("i",undefined,"dot"),text,button);$("clips").append(row);
  });
  let redactionCount=0;
  plan.sources.forEach(s=>s.redactions.forEach(r=>{
    redactionCount++;const row=node("div",undefined,"redaction");row.append(node("span",`${s.id} / ${stamp(r.start/s.rate)} → ${stamp(r.end/s.rate)}`),node("span",r.mode,"tag"));$("redactions").append(row);
  }));
  if(!redactionCount) $("redactions").append(node("p","No source redactions in this render.","empty"));
  analysis.audio.channels.forEach((m,c)=>{
    [["Sample peak",m.peakDb],["RMS",m.rmsDb]].forEach(([label,value])=>{
      const row=node("div",undefined,"meter");row.append(node("span",`${plan.channels>1?(c===0?"L / ":"R / "):""}${label}`),node("strong",`${value.toFixed(1)} dBFS`));
      const bar=node("div",undefined,"bar"), fill=node("i");fill.style.width=`${Math.max(0,Math.min(100,(value+72)/72*100))}%`;bar.append(fill);$("meters").append(row,bar);
    });
  });
  $("marker-count").textContent=`${plan.markers.length} MARKERS`;
  plan.markers.forEach(m=>jump(m.label,m.frame/plan.rate,$("markers")));
  if(!plan.markers.length) $("markers").append(node("p","No markers.","empty"));
  analysis.silenceSuggestions.slice(0,12).forEach(s=>jump("Quiet passage",s.start/plan.rate,$("silences"),`${stamp(s.start/plan.rate)} / ${stamp(s.end/plan.rate)}`));
  if(!analysis.silenceSuggestions.length) $("silences").append(node("p","No quiet passages at the default threshold.","empty"));
  if(analysis.silenceSuggestions.length>12) $("silences").append(node("p",`${analysis.silenceSuggestions.length-12} more in analysis.json`,"empty"));
  $("play").addEventListener("click",toggle);$("back").addEventListener("click",()=>seek(audio.currentTime-5));$("forward").addEventListener("click",()=>seek(audio.currentTime+5));
  $("loop").addEventListener("click",()=>{if(selection){looping=!looping;$("loop").setAttribute("aria-pressed",String(looping));}});
  $("zoom").addEventListener("input",e=>{zoom=Number(e.target.value);viewStart=(audio.currentTime||0)-viewLength()/2;clampView();draw();});
  $("reset").addEventListener("click",()=>{zoom=1;viewStart=0;$("zoom").value="1";selection=null;updateSelection();draw();});
  const timeAt = e=>Math.max(0,Math.min(duration,viewStart+(e.clientX-canvas.getBoundingClientRect().left)/canvas.getBoundingClientRect().width*viewLength()));
  canvas.addEventListener("pointerdown",e=>{dragging={time:timeAt(e),select:e.shiftKey};canvas.setPointerCapture(e.pointerId);if(!e.shiftKey)seek(dragging.time);});
  canvas.addEventListener("pointermove",e=>{if(dragging&&dragging.select){const t=timeAt(e);selection=[Math.min(t,dragging.time),Math.max(t,dragging.time)];updateSelection();draw();}});
  canvas.addEventListener("pointerup",e=>{if(dragging&&dragging.select&&selection&&selection[1]-selection[0]<1/plan.rate)selection=null;dragging=null;updateSelection();canvas.releasePointerCapture(e.pointerId);});
  canvas.addEventListener("pointercancel",()=>{dragging=null;});
  document.addEventListener("keydown",e=>{
    if(["INPUT","SELECT","TEXTAREA","BUTTON","A"].includes(document.activeElement.tagName))return;
    if(e.code==="Space"){e.preventDefault();toggle();}if(e.code==="ArrowLeft"){e.preventDefault();seek(audio.currentTime-1);}if(e.code==="ArrowRight"){e.preventDefault();seek(audio.currentTime+1);}
  });
  $("patch").addEventListener("click",()=>{
    const mode=$("mode").value, patches=selectionClips().map(({c,lo,hi})=>{
      const s=source(c.source), a=Math.max(c.sourceStart,Math.floor(c.sourceStart+(lo-c.at)*s.rate/plan.rate)), b=Math.min(c.sourceEnd,Math.ceil(c.sourceStart+(hi-c.at)*s.rate/plan.rate));
      return `  (redact ${c.source} (from ${a}/${s.rate}) (to ${b}/${s.rate}) (mode ${mode}))`;
    });
    const hashes=data.sources.map(s=>`  (source-sha256 ${s.id} "${s.sha256}")`).join("\n");
    const text=`(murmur-patch (version 1)\n  (base-plan "${data.planSha256}")\n${hashes}\n${patches.join("\n")}\n)\n`;
    const url=URL.createObjectURL(new Blob([text],{type:"text/plain;charset=utf-8"})), a=node("a");a.href=url;a.download="patch.mur";a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
  });
  audio.addEventListener("play",()=>{$("play").textContent="Ⅱ";$("play").setAttribute("aria-label","Pause recording");$("play-state").textContent="PLAYING";if(animation===null)tick();});
  audio.addEventListener("pause",()=>{$("play").textContent="▶";$("play").setAttribute("aria-label","Play recording");$("play-state").textContent="PAUSED";update();});
  audio.addEventListener("seeked",update);
  audio.addEventListener("error",()=>error("This browser could not open audio.wav. Keep the bundle together, or use a local WAV player."));
  new ResizeObserver(draw).observe(canvas);
  updateSelection();update();
})();
