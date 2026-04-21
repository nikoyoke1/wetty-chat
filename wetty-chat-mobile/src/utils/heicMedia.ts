import { heicTo } from 'heic-to/csp';

const HEIC_MIME_TYPES = new Set(['image/heic', 'image/heif', 'image/heic-sequence', 'image/heif-sequence']);
const HEIC_EXTENSION_PATTERN = /\.(heic|heif)(?:$|[?#])/i;

function normalizeMimeType(mimeType?: string | null) {
  return mimeType?.split(';', 1)[0]?.trim().toLowerCase() ?? '';
}

export function isHeicMimeType(mimeType?: string | null) {
  return HEIC_MIME_TYPES.has(normalizeMimeType(mimeType));
}

export function isHeicFileName(fileName?: string | null) {
  return fileName != null && HEIC_EXTENSION_PATTERN.test(fileName);
}

export function isHeicLikeMedia({
  mimeType,
  fileName,
  url,
}: {
  mimeType?: string | null;
  fileName?: string | null;
  url?: string | null;
}) {
  return isHeicMimeType(mimeType) || isHeicFileName(fileName) || isHeicFileName(url);
}

export function isImageFile(file: File) {
  return file.type.startsWith('image/') || isHeicFileName(file.name);
}

export function isVideoFile(file: File) {
  return file.type.startsWith('video/');
}

export function isSupportedMediaFile(file: File) {
  return isImageFile(file) || isVideoFile(file);
}

function isLikelySafariUserAgent(userAgent: string) {
  return /Safari\//.test(userAgent) && !/(Chrome|Chromium|CriOS|Edg|EdgiOS|OPR|FxiOS|Firefox|SamsungBrowser)\//.test(userAgent);
}

function parseSafariMajorVersion(userAgent: string) {
  const versionMatch = userAgent.match(/Version\/(\d+)(?:\.\d+)?/);
  if (versionMatch) {
    return Number.parseInt(versionMatch[1], 10);
  }

  const iosMatch = userAgent.match(/OS (\d+)_\d+(?:_\d+)? like Mac OS X/);
  if (iosMatch) {
    return Number.parseInt(iosMatch[1], 10);
  }

  return null;
}

export function shouldPreferNativeHeicRendering() {
  if (typeof navigator === 'undefined') {
    return false;
  }

  const userAgent = navigator.userAgent;
  if (!isLikelySafariUserAgent(userAgent)) {
    return false;
  }

  const safariMajorVersion = parseSafariMajorVersion(userAgent);
  return safariMajorVersion != null && safariMajorVersion >= 17;
}

export function getUploadMimeType(file: File) {
  if (file.type) return file.type;
  if (isHeicFileName(file.name)) return 'image/heic';
  return 'application/octet-stream';
}

export async function convertHeicBlobToJpegBlob(blob: Blob) {
  return heicTo({
    blob,
    type: 'image/jpeg',
    quality: 0.92,
  });
}

const convertedSourceCache = new Map<string, Promise<Blob>>();

export function convertHeicSourceToJpegBlob(src: string) {
  const cached = convertedSourceCache.get(src);
  if (cached) return cached;

  const conversion = fetch(src)
    .then((response) => {
      if (!response.ok) {
        throw new Error(`Failed to load HEIC media: ${response.status}`);
      }

      return response.blob().then((blob) => {
        if (blob.size === 0) {
          throw new Error('Failed to load HEIC media: empty blob');
        }

        return blob;
      });
    })
    .then(convertHeicBlobToJpegBlob)
    .catch((error) => {
      convertedSourceCache.delete(src);
      throw error;
    });

  convertedSourceCache.set(src, conversion);
  return conversion;
}

export function getImageDimensionsFromBlob(blob: Blob): Promise<{ width?: number; height?: number }> {
  return new Promise((resolve) => {
    const img = new Image();
    const objectUrl = URL.createObjectURL(blob);

    img.onload = () => {
      URL.revokeObjectURL(objectUrl);
      resolve({ width: img.width, height: img.height });
    };
    img.onerror = () => {
      URL.revokeObjectURL(objectUrl);
      resolve({});
    };
    img.src = objectUrl;
  });
}
