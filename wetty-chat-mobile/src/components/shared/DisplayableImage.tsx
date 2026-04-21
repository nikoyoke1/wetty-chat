import { type ImgHTMLAttributes, type SyntheticEvent, useEffect, useRef, useState } from 'react';
import { convertHeicSourceToJpegBlob, isHeicLikeMedia, shouldPreferNativeHeicRendering } from '@/utils/heicMedia';

interface DisplayableImageProps extends ImgHTMLAttributes<HTMLImageElement> {
  src: string;
  mimeType?: string | null;
  fileName?: string | null;
}

const TRANSPARENT_PIXEL =
  'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==';

export function DisplayableImage({ src, mimeType, fileName, onError, ...imgProps }: DisplayableImageProps) {
  return (
    <DisplayableImageInner
      key={src}
      src={src}
      mimeType={mimeType}
      fileName={fileName}
      onError={onError}
      {...imgProps}
    />
  );
}

function DisplayableImageInner({ src, mimeType, fileName, onError, ...imgProps }: DisplayableImageProps) {
  const rawHeicLike = isHeicLikeMedia({ mimeType, fileName, url: src });
  const needsConversion = rawHeicLike && !shouldPreferNativeHeicRendering();
  const [displaySrc, setDisplaySrc] = useState(() => (needsConversion ? TRANSPARENT_PIXEL : src));
  const [isResolving, setIsResolving] = useState(needsConversion);
  const mountedRef = useRef(true);
  const conversionStartedRef = useRef(false);

  useEffect(() => {
    mountedRef.current = true;
    return () => {
      mountedRef.current = false;
    };
  }, []);

  useEffect(() => {
    if (!needsConversion || conversionStartedRef.current) {
      return;
    }

    conversionStartedRef.current = true;
    convertHeicSourceToJpegBlob(src)
      .then((blob) => {
        if (!mountedRef.current) return;
        const convertedUrl = URL.createObjectURL(blob);
        setDisplaySrc(convertedUrl);
        setIsResolving(false);
      })
      .catch((error) => {
        if (!mountedRef.current) return;
        setDisplaySrc(src);
        setIsResolving(false);
        console.warn('[media:heic] Failed to convert HEIC preview', {
          src,
          mimeType,
          fileName,
          error,
        });
      });
  }, [fileName, mimeType, needsConversion, src]);

  const handleError = (event: SyntheticEvent<HTMLImageElement, Event>) => {
    setIsResolving(false);
    onError?.(event);
  };

  useEffect(() => {
    if (displaySrc === src || displaySrc === TRANSPARENT_PIXEL) return;
    return () => {
      URL.revokeObjectURL(displaySrc);
    };
  }, [displaySrc, src]);

  return <img {...imgProps} src={displaySrc} onError={handleError} style={{ opacity: isResolving ? 0 : 1, ...imgProps.style }} />;
}
