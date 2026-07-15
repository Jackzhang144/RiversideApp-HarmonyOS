import { UserProfile } from '../models/ProfileModels';

export function canClearProfileBackground(profile: UserProfile | null): boolean {
  return profile?.canUploadProfileBackground === true && profile.profileBackgroundUrl.length > 0;
}
