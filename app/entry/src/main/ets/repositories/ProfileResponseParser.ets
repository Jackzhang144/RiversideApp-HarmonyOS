import { JsonObjectReader } from '../core/JsonObjectReader';
import { RepositoryResult } from '../core/RepositoryResult';
import { HomeChannel } from '../models/DiscoveryModels';
import { CurrentUser } from '../models/ReplyModels';
import {
  ProfileGroup,
  UserBookmarkItem,
  UserEmailInfo,
  UserProfile,
  UserProfileSummary,
  UserReplyItem
} from '../models/ProfileModels';

function numberOrZero(value: number | null): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : 0;
}

function booleanOrFalse(value: boolean | null): boolean {
  return value === true;
}

class GroupMemberships {
  public readonly names: Array<string>;
  public readonly ids: Array<number>;

  public constructor(names: Array<string>, ids: Array<number>) {
    this.names = names;
    this.ids = ids;
  }
}

function groupMemberships(user: JsonObjectReader): GroupMemberships {
  const values: Array<Object | null> | null = user.array('groups');
  const names: Array<string> = [];
  const ids: Array<number> = [];
  if (values !== null) {
    for (const value of values) {
      const group: JsonObjectReader | null = JsonObjectReader.fromValue(value);
      const name: string | null = group?.string('name') ?? null;
      const id: number | null = group?.number('id') ?? null;
      if (name !== null && name.trim().length > 0) {
        names.push(name.trim());
      }
      if (id !== null && Number.isInteger(id) && id > 0) {
        ids.push(id);
      }
    }
  }
  const primaryGroupName: string | null = user.string('primary_group_name');
  if (primaryGroupName !== null && primaryGroupName.trim().length > 0) {
    names.push(primaryGroupName.trim());
  }
  return new GroupMemberships(names, ids);
}

function hasFutureTimestamp(value: string | null): boolean {
  if (value === null || value.trim().length === 0) {
    return false;
  }
  const timestamp: number = Date.parse(value);
  return Number.isFinite(timestamp) && timestamp > Date.now();
}

function firstBoolean(user: JsonObjectReader, names: Array<string>, fallback: boolean): boolean {
  for (const name of names) {
    const value: boolean | null = user.boolean(name);
    if (value !== null) {
      return value;
    }
  }
  return fallback;
}

function canCreatePost(user: JsonObjectReader): boolean {
  if (
    user.boolean('silenced') === true ||
    user.boolean('suspended') === true ||
    hasFutureTimestamp(user.string('silenced_till')) ||
    hasFutureTimestamp(user.string('suspended_till'))
  ) {
    return false;
  }
  return firstBoolean(
    user,
    ['can_create_post', 'can_create_posts', 'can_create_topic', 'can_create_topics'],
    true
  );
}

function homeChannelFromUserOption(userOption: JsonObjectReader | null): HomeChannel | null {
  if (userOption === null) {
    return null;
  }
  const numericPreference: number | null = userOption.number('homepage_id') ??
    userOption.number('homepage') ?? userOption.number('default_homepage');
  if (numericPreference === 1) return HomeChannel.LATEST_REPLIES;
  if (numericPreference === 4) return HomeChannel.LATEST_CREATED;
  if (numericPreference === 5) return HomeChannel.HOT;
  const textPreference: string = (
    userOption.string('homepage_id') ?? userOption.string('homepage') ??
      userOption.string('default_homepage') ?? ''
  ).trim().toLowerCase();
  if (textPreference === 'latest') return HomeChannel.LATEST_REPLIES;
  if (textPreference === 'new' || textPreference === 'created') return HomeChannel.LATEST_CREATED;
  if (textPreference === 'top' || textPreference === 'hot') return HomeChannel.HOT;
  return null;
}

export class ProfileResponseParser {
  public parseCurrentUser(text: string): RepositoryResult<CurrentUser> {
    const envelope: JsonObjectReader | null = JsonObjectReader.parse(text);
    const user: JsonObjectReader | null = envelope?.object('current_user') ?? null;
    if (user === null) {
      return RepositoryResult.failure<CurrentUser>('服务器响应缺少当前用户');
    }
    const currentUser: CurrentUser | null = this.parseUser(user);
    return currentUser === null
      ? RepositoryResult.failure<CurrentUser>('服务器响应缺少当前用户')
      : RepositoryResult.success<CurrentUser>(currentUser);
  }

  public parseUserProfile(text: string): RepositoryResult<CurrentUser> {
    const envelope: JsonObjectReader | null = JsonObjectReader.parse(text);
    const user: JsonObjectReader | null = envelope?.object('user') ?? null;
    const currentUser: CurrentUser | null = user === null ? null : this.parseUser(user);
    return currentUser === null
      ? RepositoryResult.failure<CurrentUser>('服务器响应缺少用户 Profile')
      : RepositoryResult.success<CurrentUser>(currentUser);
  }

  public parseFullUserProfile(text: string): RepositoryResult<UserProfile> {
    const envelope: JsonObjectReader | null = JsonObjectReader.parse(text);
    const user: JsonObjectReader | null = envelope?.object('user') ?? null;
    const profile: UserProfile | null = user === null ? null : this.parseProfile(user);
    return profile === null
      ? RepositoryResult.failure<UserProfile>('服务器响应缺少完整 Profile')
      : RepositoryResult.success<UserProfile>(profile);
  }

  public parseUserProfileSummary(text: string): RepositoryResult<UserProfileSummary> {
    const envelope: JsonObjectReader | null = JsonObjectReader.parse(text);
    if (envelope === null) {
      return RepositoryResult.failure<UserProfileSummary>('服务器 Profile 概览格式无效');
    }
    const summary: JsonObjectReader | null = envelope.object('user_summary');
    if (summary === null) {
      return RepositoryResult.success<UserProfileSummary>(UserProfileSummary.unavailable());
    }
    const badges: Array<string> = [];
    for (const value of envelope.array('badges') ?? []) {
      const badge: JsonObjectReader | null = JsonObjectReader.fromValue(value);
      const name: string = badge?.string('display_name') ?? badge?.string('name') ?? '';
      if (name.trim().length > 0) {
        badges.push(name.trim());
      }
    }
    return RepositoryResult.success<UserProfileSummary>(new UserProfileSummary(
      true,
      numberOrZero(summary.number('likes_given')),
      numberOrZero(summary.number('likes_received')),
      numberOrZero(summary.number('days_visited')),
      numberOrZero(summary.number('topic_count')),
      numberOrZero(summary.number('post_count')),
      numberOrZero(summary.number('solved_count')),
      badges
    ));
  }

  public parseUserEmails(text: string): RepositoryResult<UserEmailInfo> {
    const envelope: JsonObjectReader | null = JsonObjectReader.parse(text);
    if (envelope === null) {
      return RepositoryResult.failure<UserEmailInfo>('服务器邮箱响应格式无效');
    }
    const secondaryEmails: Array<string> = [];
    for (const value of envelope.array('secondary_emails') ?? []) {
      if (typeof value === 'string') secondaryEmails.push(value);
    }
    const unconfirmedEmails: Array<string> = [];
    for (const value of envelope.array('unconfirmed_emails') ?? []) {
      if (typeof value === 'string') unconfirmedEmails.push(value);
    }
    return RepositoryResult.success<UserEmailInfo>(new UserEmailInfo(
      envelope.string('email') ?? '',
      secondaryEmails,
      unconfirmedEmails
    ));
  }

  public parseUserReplies(text: string): RepositoryResult<Array<UserReplyItem>> {
    const envelope: JsonObjectReader | null = JsonObjectReader.parse(text);
    const values: Array<Object | null> | null = envelope?.array('user_actions') ?? null;
    if (envelope === null || values === null) {
      return RepositoryResult.failure<Array<UserReplyItem>>('服务器响应缺少用户回复列表');
    }
    const replies: Array<UserReplyItem> = [];
    for (const value of values) {
      const item: JsonObjectReader | null = JsonObjectReader.fromValue(value);
      if (item === null) continue;
      const topicId: number | null = item.number('topic_id') ?? item.number('target_topic_id');
      const topicTitle: string = (item.string('topic_title') ?? item.string('title') ?? '').trim();
      const postNumber: number | null = item.number('post_number') ?? item.number('target_post_number');
      if (topicId === null || topicId <= 0 || topicTitle.length === 0 || postNumber === null || postNumber <= 0) {
        continue;
      }
      replies.push(new UserReplyItem(
        item.number('id') ?? item.number('post_id') ?? 0,
        topicId,
        topicTitle,
        item.number('category_id') ?? 0,
        postNumber,
        item.string('created_at') ?? '',
        item.string('acting_username') ?? item.string('username') ?? item.string('target_username') ?? '',
        item.string('excerpt') ?? item.string('action_excerpt') ?? ''
      ));
    }
    return RepositoryResult.success<Array<UserReplyItem>>(replies);
  }

  public parseUserBookmarks(text: string): RepositoryResult<Array<UserBookmarkItem>> {
    const envelope: JsonObjectReader | null = JsonObjectReader.parse(text);
    const list: JsonObjectReader | null = envelope?.object('user_bookmark_list') ?? null;
    const values: Array<Object | null> | null = list?.array('bookmarks') ?? null;
    if (envelope === null || list === null || values === null) {
      return RepositoryResult.failure<Array<UserBookmarkItem>>('服务器响应缺少用户收藏列表');
    }
    const bookmarks: Array<UserBookmarkItem> = [];
    for (const value of values) {
      const item: JsonObjectReader | null = JsonObjectReader.fromValue(value);
      if (item === null) continue;
      const bookmarkId: number | null = item.number('id');
      const topicId: number | null = item.number('topic_id');
      const title: string = item.string('title')?.trim() ?? '';
      const postNumber: number | null = item.number('linked_post_number');
      if (bookmarkId === null || bookmarkId <= 0 || topicId === null || topicId <= 0 ||
        title.length === 0 || postNumber === null || postNumber <= 0) {
        continue;
      }
      bookmarks.push(new UserBookmarkItem(
        bookmarkId,
        topicId,
        title,
        item.string('excerpt') ?? '',
        postNumber,
        item.number('category_id') ?? 0,
        item.number('highest_post_number') ?? postNumber,
        item.string('bumped_at') ?? '',
        item.object('user')?.string('username') ?? ''
      ));
    }
    return RepositoryResult.success<Array<UserBookmarkItem>>(bookmarks);
  }

  private parseProfile(user: JsonObjectReader): UserProfile | null {
    const id: number | null = user.number('id');
    const username: string | null = user.string('username');
    if (id === null || username === null) return null;
    const groups: Array<ProfileGroup> = [];
    for (const value of user.array('groups') ?? []) {
      const group: JsonObjectReader | null = JsonObjectReader.fromValue(value);
      if (group === null) continue;
      const groupId: number = Math.trunc(group.number('id') ?? 0);
      const groupName: string = group.string('name') ?? '';
      if (groupId > 0 || groupName.trim().length > 0) {
        groups.push(new ProfileGroup(
          groupId,
          groupName,
          group.string('display_name') ?? group.string('full_name') ?? '',
          group.string('flair_url') ?? ''
        ));
      }
    }
    const userOption: JsonObjectReader | null = user.object('user_option');
    return UserProfile.create(id, username, {
      name: user.string('name') ?? '',
      title: user.string('title') ?? user.string('user_title') ?? '',
      avatarUrl: (user.string('avatar_template') ?? '').replace('{size}', '192'),
      primaryGroupId: user.number('primary_group_id'),
      flairGroupId: user.number('flair_group_id'),
      primaryGroupName: user.string('primary_group_name') ?? '',
      flairGroupName: user.string('flair_name') ?? '',
      trustLevel: numberOrZero(user.number('trust_level')),
      admin: booleanOrFalse(user.boolean('admin')),
      moderator: booleanOrFalse(user.boolean('moderator')),
      groups: groups,
      canFollow: booleanOrFalse(user.boolean('can_follow')) || booleanOrFalse(user.boolean('can_follow_user')) ||
        booleanOrFalse(user.boolean('can_follow_users')),
      following: booleanOrFalse(user.boolean('is_followed')) || booleanOrFalse(user.boolean('following')) ||
        booleanOrFalse(user.boolean('is_following')),
      canMute: booleanOrFalse(user.boolean('can_mute_user')) || booleanOrFalse(user.boolean('can_mute_users')),
      canIgnore: booleanOrFalse(user.boolean('can_ignore_user')) || booleanOrFalse(user.boolean('can_ignore_users')),
      muted: booleanOrFalse(user.boolean('muted')),
      ignored: booleanOrFalse(user.boolean('ignored')),
      canUploadProfileBackground: booleanOrFalse(user.boolean('can_upload_profile_header')),
      canUploadCardBackground: booleanOrFalse(user.boolean('can_upload_user_card_background')),
      profileBackgroundUrl: user.string('profile_background_upload_url') ?? '',
      cardBackgroundUrl: user.string('card_background_upload_url') ?? '',
      bioRaw: user.string('bio_raw') ?? '',
      bioExcerpt: user.string('bio_excerpt') ?? user.string('bio_raw') ?? '',
      location: user.string('location') ?? '',
      website: user.string('website') ?? '',
      timezone: user.string('timezone') ?? userOption?.string('timezone') ?? '',
      hideProfile: booleanOrFalse(user.boolean('hide_profile')) ||
        booleanOrFalse(userOption?.boolean('hide_profile') ?? null),
      hidePresence: booleanOrFalse(user.boolean('hide_presence')) ||
        booleanOrFalse(userOption?.boolean('hide_presence') ?? null),
      canCreatePost: canCreatePost(user),
      canChat: booleanOrFalse(user.boolean('can_chat')) || booleanOrFalse(user.boolean('has_chat_enabled')) ||
        booleanOrFalse(userOption?.boolean('chat_enabled') ?? null),
      canDirectMessage: booleanOrFalse(user.boolean('can_direct_message')) ||
        booleanOrFalse(user.boolean('can_send_private_messages')),
      canChatWithUser: booleanOrFalse(user.boolean('can_chat_user')) ||
        booleanOrFalse(user.boolean('can_send_private_message_to_user'))
    });
  }

  private parseUser(user: JsonObjectReader): CurrentUser | null {
    const id: number | null = user.number('id');
    const username: string | null = user.string('username');
    if (id === null || username === null) return null;
    const groups: GroupMemberships = groupMemberships(user);
    const userOption: JsonObjectReader | null = user.object('user_option');
    return CurrentUser.create(id, username, {
      name: user.string('name') ?? '',
      title: user.string('title') ?? user.string('user_title') ?? '',
      admin: booleanOrFalse(user.boolean('admin')),
      moderator: booleanOrFalse(user.boolean('moderator')),
      trustLevel: numberOrZero(user.number('trust_level')),
      canCreatePost: canCreatePost(user),
      canChat: booleanOrFalse(user.boolean('can_chat')) || booleanOrFalse(user.boolean('has_chat_enabled')) ||
        booleanOrFalse(userOption?.boolean('chat_enabled') ?? null),
      canDirectMessage: booleanOrFalse(user.boolean('can_direct_message')) ||
        booleanOrFalse(user.boolean('can_send_private_messages')),
      canChatWithUser: booleanOrFalse(user.boolean('can_chat_user')) ||
        booleanOrFalse(user.boolean('can_send_private_message_to_user')),
      unreadNotifications: numberOrZero(user.number('unread_notifications')) +
        numberOrZero(user.number('unread_high_priority_notifications')),
      groupNames: groups.names,
      groupIds: groups.ids,
      primaryGroupId: user.number('primary_group_id'),
      flairGroupId: user.number('flair_group_id'),
      defaultHomeChannel: homeChannelFromUserOption(userOption)
    });
  }
}
