const path = require('path');
const fs = require('fs');
const { execFile } = require('child_process');
const { promisify } = require('util');

const execFileAsync = promisify(execFile);

/**
 * Extracts `/uploads/...` from local/LAN URLs so stored paths stay host-independent,
 * leaving external HTTPS URLs untouched.
 */
function toRelativeMediaPath(rawUrl) {
  if (!rawUrl || typeof rawUrl !== 'string') return '';
  const trimmed = rawUrl.trim();
  if (trimmed.startsWith('/uploads/')) return trimmed;

  const localUploadMatch = trimmed.match(
    /^https?:\/\/(?:localhost|127\.0\.0\.1|10\.0\.2\.2|\d{1,3}(?:\.\d{1,3}){3})(?::\d+)?(\/uploads\/.+)$/i
  );
  if (localUploadMatch) {
    return localUploadMatch[1];
  }
  return trimmed;
}

/**
 * Resolves relative `/uploads/...` or stale localhost/LAN IP URLs against the incoming request host,
 * so videos uploaded from desktop work seamlessly on physical phones over Wi-Fi or production domains.
 */
function normalizeMediaUrl(req, rawUrl) {
  if (!rawUrl || typeof rawUrl !== 'string') return '';
  const rel = toRelativeMediaPath(rawUrl);
  if (rel.startsWith('/')) {
    const protocol = req.protocol || 'http';
    const host = req.get('host');
    return host ? `${protocol}://${host}${rel}` : rel;
  }
  return rel;
}

/**
 * Probes an uploaded video file via ffprobe to inspect codecs and streams.
 */
async function probeMediaStreams(filePath) {
  try {
    const { stdout } = await execFileAsync('ffprobe', [
      '-v', 'error',
      '-show_entries', 'stream=codec_type,codec_name,pix_fmt,sample_rate,channels',
      '-of', 'json',
      filePath,
    ]);
    const parsed = JSON.parse(stdout || '{}');
    const streams = Array.isArray(parsed.streams) ? parsed.streams : [];
    const videoStream = streams.find(s => s.codec_type === 'video') || null;
    const audioStream = streams.find(s => s.codec_type === 'audio') || null;
    return {
      hasVideo: !!videoStream,
      hasAudio: !!audioStream,
      videoCodec: videoStream ? videoStream.codec_name : null,
      pixFmt: videoStream ? videoStream.pix_fmt : null,
      audioCodec: audioStream ? audioStream.codec_name : null,
    };
  } catch (err) {
    console.warn('ffprobe check failed:', err.message);
    return null;
  }
}

/**
 * Normalizes any uploaded MP4/MOV/video so it plays reliably with sound across
 * Chrome, Safari, and Android ExoPlayer (`h264 + yuv420p + aac + faststart`).
 */
async function ensureMp4PlayableWithSound(filePath) {
  if (!filePath || !fs.existsSync(filePath)) {
    return { processed: false, hasAudio: false };
  }

  const info = await probeMediaStreams(filePath);
  if (!info || !info.hasVideo) {
    return { processed: false, hasAudio: !!(info && info.hasAudio), info };
  }

  const ext = path.extname(filePath).toLowerCase();
  const isH264Yuv420 = info.videoCodec === 'h264' && info.pixFmt === 'yuv420p';
  const isAudioOk = !info.hasAudio || info.audioCodec === 'aac';
  const tmpOut = `${filePath}.faststart.mp4`;

  try {
    const args = ['-y', '-i', filePath];

    if (isH264Yuv420 && isAudioOk && ext === '.mp4') {
      // Fast remux to move moov atom to front (+faststart) without re-encoding
      args.push('-c', 'copy', '-movflags', '+faststart', tmpOut);
    } else {
      // Universal H.264 + AAC transcode preserving audio
      args.push(
        '-c:v', 'libx264',
        '-preset', 'veryfast',
        '-pix_fmt', 'yuv420p'
      );
      if (info.hasAudio) {
        args.push('-c:a', 'aac', '-b:a', '128k', '-ar', '44100');
      } else {
        args.push('-an');
      }
      args.push('-movflags', '+faststart', tmpOut);
    }

    await execFileAsync('ffmpeg', args, { timeout: 120000 });

    if (fs.existsSync(tmpOut) && fs.statSync(tmpOut).size > 0) {
      fs.renameSync(tmpOut, filePath);
    }
    return { processed: true, hasAudio: info.hasAudio, info };
  } catch (err) {
    console.warn('ffmpeg optimization skipped:', err.message);
    try {
      if (fs.existsSync(tmpOut)) fs.unlinkSync(tmpOut);
    } catch (_) {}
    return { processed: false, hasAudio: info.hasAudio, info };
  }
}

module.exports = {
  toRelativeMediaPath,
  normalizeMediaUrl,
  probeMediaStreams,
  ensureMp4PlayableWithSound,
};

