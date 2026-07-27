export class ImageAspectRatio {
  public readonly url: string;
  public readonly ratio: number;

  public constructor(url: string, ratio: number) {
    this.url = url;
    this.ratio = ratio;
  }
}

export function resolveImageAspectRatio(
  imageRatios: Array<ImageAspectRatio>,
  url: string,
  sourceWidth: number = 0,
  sourceHeight: number = 0,
  fallbackRatio: number = 4 / 3
): number {
  for (const imageRatio of imageRatios) {
    if (imageRatio.url === url) {
      return imageRatio.ratio;
    }
  }
  if (sourceWidth > 0 && sourceHeight > 0) {
    return sourceWidth / sourceHeight;
  }
  return fallbackRatio;
}

export function updateImageAspectRatios(
  imageRatios: Array<ImageAspectRatio>,
  url: string,
  width: number,
  height: number
): Array<ImageAspectRatio> {
  if (!Number.isFinite(width) || !Number.isFinite(height) || width <= 0 || height <= 0) {
    return imageRatios;
  }
  const ratio: number = width / height;
  for (const imageRatio of imageRatios) {
    if (imageRatio.url === url && Math.abs(imageRatio.ratio - ratio) < 0.001) {
      return imageRatios;
    }
  }
  return imageRatios
    .filter((imageRatio: ImageAspectRatio): boolean => imageRatio.url !== url)
    .concat([new ImageAspectRatio(url, ratio)]);
}
