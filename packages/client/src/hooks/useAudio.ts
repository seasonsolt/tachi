import { useCallback, useEffect, useRef, useState } from 'react';

const AMBIENT_URL = '/audio/ambient.mp3';

export function useAudio() {
  const ctxRef = useRef<AudioContext | null>(null);
  const sourceRef = useRef<AudioBufferSourceNode | null>(null);
  const gainRef = useRef<GainNode | null>(null);
  const bufferRef = useRef<AudioBuffer | null>(null);
  const [playing, setPlaying] = useState(false);
  const [volume, setVolumeState] = useState(0.4);
  const [loaded, setLoaded] = useState(false);

  const ensureContext = useCallback(() => {
    if (!ctxRef.current) {
      ctxRef.current = new AudioContext();
      gainRef.current = ctxRef.current.createGain();
      gainRef.current.gain.value = volume;
      gainRef.current.connect(ctxRef.current.destination);
    }
    if (ctxRef.current.state === 'suspended') {
      ctxRef.current.resume();
    }
    return ctxRef.current;
  }, [volume]);

  const loadAudio = useCallback(async () => {
    const ctx = ensureContext();
    if (bufferRef.current) return bufferRef.current;
    try {
      const res = await fetch(AMBIENT_URL);
      if (!res.ok) return null;
      const data = await res.arrayBuffer();
      const buffer = await ctx.decodeAudioData(data);
      bufferRef.current = buffer;
      setLoaded(true);
      return buffer;
    } catch {
      return null;
    }
  }, [ensureContext]);

  const play = useCallback(async () => {
    const ctx = ensureContext();
    const buffer = await loadAudio();
    if (!buffer || !gainRef.current) return;

    if (sourceRef.current) {
      try { sourceRef.current.stop(); } catch { /* already stopped */ }
    }

    const source = ctx.createBufferSource();
    source.buffer = buffer;
    source.loop = true;
    source.connect(gainRef.current);
    source.start(0);
    sourceRef.current = source;
    setPlaying(true);
  }, [ensureContext, loadAudio]);

  const pause = useCallback(() => {
    if (sourceRef.current) {
      try { sourceRef.current.stop(); } catch { /* already stopped */ }
      sourceRef.current = null;
    }
    setPlaying(false);
  }, []);

  const toggle = useCallback(() => {
    if (playing) pause();
    else play();
  }, [playing, play, pause]);

  const setVolume = useCallback((v: number) => {
    const clamped = Math.max(0, Math.min(1, v));
    setVolumeState(clamped);
    if (gainRef.current) {
      gainRef.current.gain.value = clamped;
    }
  }, []);

  useEffect(() => {
    return () => {
      if (sourceRef.current) {
        try { sourceRef.current.stop(); } catch { /* noop */ }
      }
      if (ctxRef.current) {
        ctxRef.current.close();
      }
    };
  }, []);

  return { playing, toggle, volume, setVolume, loaded, play };
}
