const MAX_STICKER_DIMENSION: u32 = 512;

pub struct ProcessedMedia {
    pub data: Vec<u8>,
    pub content_type: String,
    pub width: Option<i32>,
    pub height: Option<i32>,
}

/// Process an image sticker: resize so the largest dimension is 512px and convert to webp.
/// For video/webm, only extracts dimensions (no re-encoding).
pub fn process_sticker(content_type: &str, data: &[u8]) -> ProcessedMedia {
    if content_type.starts_with("image/") {
        if let Some(result) = process_image_sticker(data) {
            return result;
        }
        tracing::warn!("failed to process image sticker, storing original");
    } else if content_type == "video/webm" {
        let dims = extract_webm_dimensions(data);
        return ProcessedMedia {
            data: data.to_vec(),
            content_type: content_type.to_string(),
            width: dims.map(|(w, _)| w),
            height: dims.map(|(_, h)| h),
        };
    }
    ProcessedMedia {
        data: data.to_vec(),
        content_type: content_type.to_string(),
        width: None,
        height: None,
    }
}

fn process_image_sticker(data: &[u8]) -> Option<ProcessedMedia> {
    let reader = image::ImageReader::new(std::io::Cursor::new(data))
        .with_guessed_format()
        .ok()?;
    let img = reader.decode().ok()?;

    let img = if img.width() > MAX_STICKER_DIMENSION || img.height() > MAX_STICKER_DIMENSION {
        img.resize(
            MAX_STICKER_DIMENSION,
            MAX_STICKER_DIMENSION,
            image::imageops::FilterType::Lanczos3,
        )
    } else {
        img
    };

    let (w, h) = (img.width() as i32, img.height() as i32);

    let mut buf = std::io::Cursor::new(Vec::new());
    img.write_to(&mut buf, image::ImageFormat::WebP).ok()?;

    Some(ProcessedMedia {
        data: buf.into_inner(),
        content_type: "image/webp".to_string(),
        width: Some(w),
        height: Some(h),
    })
}

pub fn extract_webm_dimensions(data: &[u8]) -> Option<(i32, i32)> {
    let cursor = std::io::Cursor::new(data);
    let mkv = matroska::Matroska::open(cursor).ok()?;
    let track = mkv.video_tracks().next()?;
    if let matroska::Settings::Video(video) = &track.settings {
        Some((video.pixel_width as i32, video.pixel_height as i32))
    } else {
        None
    }
}
