import { useCallback, useEffect, useRef } from 'react';
import { useStore, type AudioSource } from '../stores/store';

const AMBIENT_URL = '/audio/ambient.mp3';
const LS_AUDIO_VOLUME = 'ritual-audio-volume';
const LS_AUDIO_YOUTUBE_URL = 'ritual-audio-youtube-url';
export const DEFAULT_YOUTUBE_URL = 'https://www.youtube.com/watch?v=OWz7HiR6H-0';

type YouTubeNamespace = {
  Player: new (
    element: HTMLElement,
    options: {
      videoId?: string;
      height?: string;
      width?: string;
      playerVars?: Record<string, number>;
      events?: {
        onReady?: (event: { target: YouTubePlayer }) => void;
        onStateChange?: (event: { data: number; target: YouTubePlayer }) => void;
        onError?: () => void;
      };
    },
  ) => YouTubePlayer;
  PlayerState: {
    ENDED: number;
  };
};

type YouTubePlayer = {
  playVideo: () => void;
  pauseVideo: () => void;
  stopVideo: () => void;
  setVolume: (value: number) => void;
  loadVideoById: (videoId: string) => void;
  cueVideoById: (videoId: string) => void;
  seekTo: (seconds: number) => void;
  destroy: () => void;
};

declare global {
  interface Window {
    YT?: YouTubeNamespace;
    onYouTubeIframeAPIReady?: () => void;
  }
}

let youtubeApiPromise: Promise<YouTubeNamespace> | null = null;

function loadYouTubeApi(): Promise<YouTubeNamespace> {
  if (typeof window === 'undefined') {
    return Promise.reject(new Error('YouTube is only available in the browser.'));
  }

  if (window.YT?.Player) {
    return Promise.resolve(window.YT);
  }

  if (youtubeApiPromise) {
    return youtubeApiPromise;
  }

  youtubeApiPromise = new Promise((resolve, reject) => {
    const existingScript = document.querySelector<HTMLScriptElement>('script[data-ritual-youtube-api="true"]');

    const handleReady = () => {
      if (window.YT?.Player) resolve(window.YT);
      else reject(new Error('YouTube Player API failed to initialize.'));
    };

    window.onYouTubeIframeAPIReady = handleReady;

    if (existingScript) return;

    const script = document.createElement('script');
    script.src = 'https://www.youtube.com/iframe_api';
    script.async = true;
    script.dataset.ritualYoutubeApi = 'true';
    script.onerror = () => reject(new Error('Failed to load YouTube Player API.'));
    document.head.appendChild(script);
  });

  return youtubeApiPromise;
}

function getDefaultSource(): AudioSource {
  return {
    kind: 'default',
    url: AMBIENT_URL,
    label: 'ambient',
  };
}

function getInitialYouTubeSource(): AudioSource | null {
  const persistedUrl = typeof window !== 'undefined'
    ? window.localStorage.getItem(LS_AUDIO_YOUTUBE_URL)
    : null;
  const url = persistedUrl || DEFAULT_YOUTUBE_URL;

  const parsed = parseYouTubeUrl(url);
  if (!parsed) return null;

  return {
    kind: 'youtube',
    url,
    label: parsed.label,
    youtubeVideoId: parsed.videoId,
  };
}

function getPersistedVolume(): number {
  if (typeof window === 'undefined') return 0.4;
  const raw = window.localStorage.getItem(LS_AUDIO_VOLUME);
  const parsed = raw ? Number(raw) : NaN;
  if (Number.isNaN(parsed)) return 0.4;
  return Math.max(0, Math.min(1, parsed));
}

function parseYouTubeUrl(input: string): { videoId: string; label: string } | null {
  try {
    const url = new URL(input.trim());
    const host = url.hostname.replace(/^www\./, '');

    let videoId = '';

    if (host === 'youtu.be') {
      videoId = url.pathname.replace('/', '').split('/')[0] ?? '';
    } else if (host === 'youtube.com' || host === 'm.youtube.com' || host === 'music.youtube.com') {
      if (url.pathname === '/watch') {
        videoId = url.searchParams.get('v') ?? '';
      } else if (url.pathname.startsWith('/shorts/')) {
        videoId = url.pathname.split('/')[2] ?? '';
      } else if (url.pathname.startsWith('/embed/')) {
        videoId = url.pathname.split('/')[2] ?? '';
      }
    }

    if (!/^[a-zA-Z0-9_-]{11}$/.test(videoId)) return null;

    return {
      videoId,
      label: 'youtube ritual',
    };
  } catch {
    return null;
  }
}

export function useAudioController() {
  const audioSource = useStore((s) => s.audioSource);
  const audioPlaying = useStore((s) => s.audioPlaying);
  const audioVolume = useStore((s) => s.audioVolume);
  const setAudioSource = useStore((s) => s.setAudioSource);
  const setAudioReady = useStore((s) => s.setAudioReady);
  const setAudioError = useStore((s) => s.setAudioError);
  const setAudioPlaying = useStore((s) => s.setAudioPlaying);
  const setAudioVolume = useStore((s) => s.setAudioVolume);
  const htmlAudioRef = useRef<HTMLAudioElement | null>(null);
  const ytHostRef = useRef<HTMLDivElement | null>(null);
  const ytPlayerRef = useRef<YouTubePlayer | null>(null);
  const lastYouTubeIdRef = useRef<string | undefined>(undefined);
  const bootedRef = useRef(false);

  useEffect(() => {
    if (bootedRef.current) return;
    bootedRef.current = true;

    setAudioVolume(getPersistedVolume());

    const persistedYouTube = getInitialYouTubeSource();
    if (persistedYouTube) {
      setAudioSource(persistedYouTube);
    } else {
      setAudioSource(getDefaultSource());
    }
  }, [setAudioSource, setAudioVolume]);

  useEffect(() => {
    if (typeof document === 'undefined') return undefined;

    const host = document.createElement('div');
    host.style.display = 'none';
    host.setAttribute('aria-hidden', 'true');
    document.body.appendChild(host);
    ytHostRef.current = host;

    return () => {
      ytHostRef.current = null;
      host.remove();
    };
  }, []);

  useEffect(() => {
    const audio = new Audio();
    audio.loop = true;
    audio.preload = 'auto';
    audio.volume = useStore.getState().audioVolume;
    htmlAudioRef.current = audio;

    const handleCanPlay = () => setAudioReady(true);
    const handleError = () => {
      setAudioReady(false);
      setAudioError('This audio source could not be played.');
      setAudioPlaying(false);
    };

    audio.addEventListener('canplay', handleCanPlay);
    audio.addEventListener('error', handleError);

    return () => {
      audio.pause();
      audio.removeAttribute('src');
      audio.load();
      audio.removeEventListener('canplay', handleCanPlay);
      audio.removeEventListener('error', handleError);
      if (ytPlayerRef.current) {
        ytPlayerRef.current.destroy();
        ytPlayerRef.current = null;
      }
    };
  }, [setAudioError, setAudioPlaying, setAudioReady]);

  useEffect(() => {
    if (typeof window !== 'undefined') {
      window.localStorage.setItem(LS_AUDIO_VOLUME, String(audioVolume));
    }
    if (htmlAudioRef.current) {
      htmlAudioRef.current.volume = audioVolume;
    }
    if (ytPlayerRef.current) {
      ytPlayerRef.current.setVolume(Math.round(audioVolume * 100));
    }
  }, [audioVolume]);

  useEffect(() => {
    const audio = htmlAudioRef.current;
    if (!audio) return;

    setAudioReady(false);
    setAudioError(null);

    if (audioSource.kind === 'youtube') {
      audio.pause();
      audio.removeAttribute('src');
      audio.load();

      if (typeof window !== 'undefined') {
        window.localStorage.setItem(LS_AUDIO_YOUTUBE_URL, audioSource.url);
      }

      let cancelled = false;

      loadYouTubeApi()
        .then((YT) => {
          if (cancelled || !ytHostRef.current || !audioSource.youtubeVideoId) return;

          const ensureReady = (player: YouTubePlayer) => {
            setAudioReady(true);
            setAudioError(null);
            player.setVolume(Math.round(audioVolume * 100));
            if (audioPlaying) {
              player.playVideo();
            } else {
              player.pauseVideo();
            }
          };

          if (!ytPlayerRef.current) {
            ytPlayerRef.current = new YT.Player(ytHostRef.current, {
              height: '0',
              width: '0',
              videoId: audioSource.youtubeVideoId,
              playerVars: {
                autoplay: 0,
                controls: 0,
                playsinline: 1,
                rel: 0,
              },
              events: {
                onReady: (event) => ensureReady(event.target),
                onStateChange: (event) => {
                  if (event.data === YT.PlayerState.ENDED) {
                    event.target.seekTo(0);
                    if (audioPlaying) event.target.playVideo();
                  }
                },
                onError: () => {
                  setAudioReady(false);
                  setAudioError('YouTube playback is unavailable for this link.');
                  setAudioPlaying(false);
                },
              },
            });
          } else if (lastYouTubeIdRef.current !== audioSource.youtubeVideoId) {
            ytPlayerRef.current.cueVideoById(audioSource.youtubeVideoId);
            ensureReady(ytPlayerRef.current);
          } else {
            ensureReady(ytPlayerRef.current);
          }

          lastYouTubeIdRef.current = audioSource.youtubeVideoId;
        })
        .catch(() => {
          if (cancelled) return;
          setAudioReady(false);
          setAudioError('Failed to load the YouTube player.');
          setAudioPlaying(false);
        });

      return () => {
        cancelled = true;
      };
    }

    if (typeof window !== 'undefined') {
      window.localStorage.removeItem(LS_AUDIO_YOUTUBE_URL);
    }

    if (ytPlayerRef.current) {
      ytPlayerRef.current.pauseVideo();
    }

    audio.src = audioSource.url;
    audio.load();

    return undefined;
  }, [
    audioPlaying,
    audioSource,
    audioVolume,
    setAudioError,
    setAudioPlaying,
    setAudioReady,
  ]);

  useEffect(() => {
    const audio = htmlAudioRef.current;

    if (audioSource.kind === 'youtube') {
      if (!ytPlayerRef.current) return;
      if (audioPlaying) ytPlayerRef.current.playVideo();
      else ytPlayerRef.current.pauseVideo();
      return;
    }

    if (!audio?.src) return;

    if (!audioPlaying) {
      audio.pause();
      return;
    }

    audio.play().catch(() => {
      setAudioError('Playback was blocked. Press play again to start the ritual.');
      setAudioPlaying(false);
    });
  }, [audioPlaying, audioSource.kind, setAudioError, setAudioPlaying]);

  return undefined;
}

export function useAudio() {
  const audioSource = useStore((s) => s.audioSource);
  const playing = useStore((s) => s.audioPlaying);
  const volume = useStore((s) => s.audioVolume);
  const ready = useStore((s) => s.audioReady);
  const error = useStore((s) => s.audioError);
  const setAudioSource = useStore((s) => s.setAudioSource);
  const setAudioPlaying = useStore((s) => s.setAudioPlaying);
  const setAudioVolume = useStore((s) => s.setAudioVolume);
  const setAudioError = useStore((s) => s.setAudioError);

  const toggle = useCallback(() => {
    setAudioPlaying(!playing);
  }, [playing, setAudioPlaying]);

  const play = useCallback(() => {
    setAudioPlaying(true);
  }, [setAudioPlaying]);

  const pause = useCallback(() => {
    setAudioPlaying(false);
  }, [setAudioPlaying]);

  const setVolume = useCallback((value: number) => {
    const clamped = Math.max(0, Math.min(1, value));
    setAudioVolume(clamped);
  }, [setAudioVolume]);

  const useDefaultTrack = useCallback(() => {
    const previous = useStore.getState().audioSource;
    if (previous.kind === 'local' && previous.url.startsWith('blob:')) {
      URL.revokeObjectURL(previous.url);
    }
    setAudioError(null);
    setAudioSource(getDefaultSource());
  }, [setAudioError, setAudioSource]);

  const useYouTubeTrack = useCallback((input: string) => {
    const parsed = parseYouTubeUrl(input);
    if (!parsed) {
      setAudioError('Please enter a valid YouTube video link.');
      return false;
    }

    const previous = useStore.getState().audioSource;
    if (previous.kind === 'local' && previous.url.startsWith('blob:')) {
      URL.revokeObjectURL(previous.url);
    }

    setAudioError(null);
    setAudioSource({
      kind: 'youtube',
      url: input.trim(),
      label: parsed.label,
      youtubeVideoId: parsed.videoId,
    });
    return true;
  }, [setAudioError, setAudioSource]);

  const useLocalFile = useCallback((file: File | null) => {
    if (!file) return false;

    const previous = useStore.getState().audioSource;
    if (previous.kind === 'local' && previous.url.startsWith('blob:')) {
      URL.revokeObjectURL(previous.url);
    }

    const objectUrl = URL.createObjectURL(file);
    setAudioError(null);
    setAudioSource({
      kind: 'local',
      url: objectUrl,
      label: file.name.replace(/\.[^.]+$/, '') || 'local file',
    });
    return true;
  }, [setAudioError, setAudioSource]);

  return {
    audioSource,
    playing,
    volume,
    ready,
    error,
    toggle,
    play,
    pause,
    setVolume,
    useDefaultTrack,
    useYouTubeTrack,
    useLocalFile,
  };
}
