const DEFAULT_AVATAR_SIZE: number = 36;
const MINIMUM_AVATAR_SIZE: number = 24;
const MAXIMUM_AVATAR_SIZE: number = 96;
const MINIMUM_AVATAR_CORNER_RADIUS: number = 6;
const AVATAR_CORNER_RADIUS_RATIO: number = 0.22;

export function normalizedAvatarSize(size: number): number {
  if (!Number.isFinite(size) || size <= 0) {
    return DEFAULT_AVATAR_SIZE;
  }
  return Math.max(MINIMUM_AVATAR_SIZE, Math.min(size, MAXIMUM_AVATAR_SIZE));
}

export function avatarCornerRadius(size: number): number {
  const normalizedSize: number = normalizedAvatarSize(size);
  return Math.max(
    MINIMUM_AVATAR_CORNER_RADIUS,
    Math.round(normalizedSize * AVATAR_CORNER_RADIUS_RATIO)
  );
}

export function avatarInitial(displayName: string): string {
  const normalizedName: string = displayName.trim();
  return normalizedName.length > 0 ? normalizedName.slice(0, 1).toUpperCase() : '人';
}
