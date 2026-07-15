import { RepositoryResult } from '../core/RepositoryResult';
import { JsonObjectReader } from '../core/JsonObjectReader';
import {
  ForumPost,
  ForumPostMetadata,
  PostReaction,
  PostReactionUser,
  PostReactionUsers,
  Topic,
  TopicDetail,
  TopicDetailMetadata,
  TopicPostBatch
} from '../models/ForumModels';
import { ServerDraft } from '../models/AuthoringModels';
import {
  booleanOrFalse,
  decodeNumberArray,
  integerFromReader,
  numberOrZero,
  textOrEmpty
} from './ForumResponseDecoding';


function forumPostFromReader(
  post: JsonObjectReader,
  id: number | null,
  postNumber: number | null
): ForumPost | null {
  if (id === null || id <= 0 || postNumber === null || postNumber <= 0) {
    return null;
  }
  const rawReactions: Array<PostReaction> = decodeReactions(post, 'reactions');
  const reactions: Array<PostReaction> = rawReactions.length > 0
    ? rawReactions
    : decodeReactions(post, 'actions_summary');
  let likeCount: number = 0;
  if (rawReactions.length > 0) {
    for (const reaction of rawReactions) {
      likeCount += reaction.count;
    }
  } else {
    for (const reaction of reactions) {
      if (reaction.id === '2') {
        likeCount = reaction.count;
      }
    }
  }
  const currentUserReaction: JsonObjectReader | null = post.object('current_user_reaction');
  const replyToUser: JsonObjectReader | null = post.object('reply_to_user');
  const metadata: ForumPostMetadata = new ForumPostMetadata(
    textOrEmpty(post.string('user_title')),
    textOrEmpty(post.string('avatar_template')),
    textOrEmpty(post.string('flair_url')),
    replyToUser?.string('username') ?? null,
    replyToUser?.string('avatar_template') ?? null,
    likeCount,
    reactions,
    currentUserReaction?.string('id') ?? null,
    booleanOrFalse(post.boolean('can_edit')),
    booleanOrFalse(post.boolean('can_delete')),
    booleanOrFalse(post.boolean('accepted_answer')),
    booleanOrFalse(post.boolean('can_accept_answer')),
    booleanOrFalse(post.boolean('can_unaccept_answer')),
    booleanOrFalse(post.boolean('bookmarked')),
    post.number('bookmark_id'),
    post.number('post_type') ?? 1,
    textOrEmpty(post.string('action_code'))
  );
  return new ForumPost(
    id,
    numberOrZero(post.number('user_id')),
    textOrEmpty(post.string('username')),
    textOrEmpty(post.string('cooked')),
    textOrEmpty(post.string('raw')),
    postNumber,
    post.number('reply_to_post_number'),
    textOrEmpty(post.string('created_at')),
    metadata
  );
}

function reactionId(reaction: JsonObjectReader): string {
  const textId: string | null = reaction.string('id') ?? reaction.string('emoji') ??
    reaction.string('emoji_name') ?? reaction.string('reaction') ?? reaction.string('name') ??
    reaction.string('action_type');
  if (textId !== null) {
    return textId;
  }
  const numericId: number | null = reaction.number('id');
  return numericId === null ? '' : `${numericId}`;
}

function decodeReactions(post: JsonObjectReader, name: string): Array<PostReaction> {
  const values: Array<Object | null> | null = post.array(name);
  const reactions: Array<PostReaction> = [];
  if (values === null) {
    return reactions;
  }
  for (const value of values) {
    const reaction: JsonObjectReader | null = JsonObjectReader.fromValue(value);
    if (reaction === null) {
      continue;
    }
    const id: string = reactionId(reaction);
    const count: number = numberOrZero(reaction.number('count'));
    if (id.length > 0 && count > 0) {
      reactions.push(new PostReaction(id, count));
    }
  }
  return reactions;
}

function decodeStrings(source: JsonObjectReader, name: string): Array<string> {
  const values: Array<Object | null> | null = source.array(name);
  const strings: Array<string> = [];
  if (values === null) {
    return strings;
  }
  for (const value of values) {
    if (typeof value === 'string' && value.length > 0) {
      strings.push(value);
    }
  }
  return strings;
}

function topicFromReader(topic: JsonObjectReader): Topic | null {
  const id: number | null = topic.number('id');
  const title: string = textOrEmpty(topic.string('title')).length > 0
    ? textOrEmpty(topic.string('title'))
    : textOrEmpty(topic.string('fancy_title'));
  if (id === null || id <= 0 || title.length === 0) {
    return null;
  }
  return new Topic(
    id,
    title,
    numberOrZero(topic.number('category_id')),
    numberOrZero(topic.number('posts_count')),
    numberOrZero(topic.number('views')),
    numberOrZero(topic.number('like_count')),
    textOrEmpty(topic.string('excerpt')),
    textOrEmpty(topic.string('last_posted_at')),
    booleanOrFalse(topic.boolean('pinned')),
    textOrEmpty(topic.string('last_poster_username'))
  );
}

function decodeSuggestedTopics(envelope: JsonObjectReader): Array<Topic> {
  const values: Array<Object | null> | null = envelope.array('suggested_topics');
  const topics: Array<Topic> = [];
  if (values === null) {
    return topics;
  }
  for (const value of values) {
    const reader: JsonObjectReader | null = JsonObjectReader.fromValue(value);
    const topic: Topic | null = reader === null ? null : topicFromReader(reader);
    if (topic !== null) {
      topics.push(topic);
    }
  }
  return topics;
}

function decodePostReader(post: JsonObjectReader): ForumPost | null {
  return forumPostFromReader(post, post.number('id'), post.number('post_number'));
}

function decodeCreatedPostReader(post: JsonObjectReader): ForumPost | null {
  return forumPostFromReader(
    post,
    post.number('id') ?? post.number('post_id'),
    post.number('post_number') ?? post.number('target_post_number')
  );
}

function decodePost(value: Object): ForumPost | null {
  const post: JsonObjectReader | null = JsonObjectReader.fromValue(value);
  return post === null ? null : decodePostReader(post);
}

function decodePosts(postStream: JsonObjectReader): Array<ForumPost> | null {
  const values: Array<Object | null> | null = postStream.array('posts');
  if (values === null) {
    return null;
  }
  const posts: Array<ForumPost> = [];
  const seenIds: Set<number> = new Set<number>();
  for (const value of values) {
    if (value === null) {
      continue;
    }
    const post: ForumPost | null = decodePost(value);
    if (post === null) {
      return null;
    }
    if (!seenIds.has(post.id)) {
      seenIds.add(post.id);
      posts.push(post);
    }
  }
  return posts;
}

function firstReplyPermission(envelope: JsonObjectReader, details: JsonObjectReader | null): boolean {
  const names: Array<string> = ['can_reply', 'can_create_post', 'can_create_reply'];
  if (details !== null) {
    for (const name of names) {
      const value: boolean | null = details.boolean(name);
      if (value !== null) {
        return value;
      }
    }
  }
  for (const name of names) {
    const value: boolean | null = envelope.boolean(name);
    if (value !== null) {
      return value;
    }
  }
  return true;
}

export class TopicResponseParser {
  public parseTopicDetail(text: string): RepositoryResult<TopicDetail> {
    const envelope: JsonObjectReader | null = JsonObjectReader.parse(text);
    if (envelope === null) {
      return RepositoryResult.invalidResponse<TopicDetail>('服务器响应缺少 Topic 详情');
    }
    const id: number | null = envelope.number('id');
    const directTitle: string = textOrEmpty(envelope.string('title'));
    const title: string = directTitle.length > 0 ? directTitle : textOrEmpty(envelope.string('fancy_title'));
    const postStream: JsonObjectReader | null = envelope.object('post_stream');
    if (id === null || id <= 0 || title.length === 0 || postStream === null) {
      return RepositoryResult.invalidResponse<TopicDetail>('服务器响应缺少 Topic 详情');
    }
    const postIds: Array<number> | null = decodeNumberArray(postStream, 'stream');
    const posts: Array<ForumPost> | null = decodePosts(postStream);
    if (postIds === null || posts === null) {
      return RepositoryResult.invalidResponse<TopicDetail>('服务器响应缺少 Post 列表');
    }
    const closed: boolean = envelope.boolean('closed') === true;
    const archived: boolean = envelope.boolean('archived') === true;
    const detail: TopicDetail = new TopicDetail(
      id,
      title,
      numberOrZero(envelope.number('views')),
      numberOrZero(envelope.number('posts_count')),
      numberOrZero(envelope.number('like_count')),
      closed,
      archived,
      firstReplyPermission(envelope, envelope.object('details')),
      postIds,
      posts,
      numberOrZero(envelope.number('highest_post_number')),
      new TopicDetailMetadata(
        numberOrZero(envelope.number('category_id')),
        booleanOrFalse(envelope.boolean('can_edit')) ||
          booleanOrFalse(envelope.object('details')?.boolean('can_edit') ?? null),
        textOrEmpty(envelope.object('details')?.object('created_by')?.string('username') ??
          (posts.length > 0 ? posts[0].username : '')),
        decodeStrings(envelope, 'valid_reactions'),
        decodeSuggestedTopics(envelope),
        numberOrZero(envelope.number('last_read_post_number'))
      )
    );
    return RepositoryResult.success<TopicDetail>(detail);
  }

  public parseTopicPosts(text: string): RepositoryResult<Array<ForumPost>> {
    const envelope: JsonObjectReader | null = JsonObjectReader.parse(text);
    const postStream: JsonObjectReader | null = envelope?.object('post_stream') ?? null;
    if (postStream === null) {
      return RepositoryResult.invalidResponse<Array<ForumPost>>('服务器响应缺少 Post 列表');
    }
    const posts: Array<ForumPost> | null = decodePosts(postStream);
    return posts === null
      ? RepositoryResult.invalidResponse<Array<ForumPost>>('服务器响应缺少 Post 列表')
      : RepositoryResult.success<Array<ForumPost>>(posts);
  }

  public parseTopicPostBatch(text: string): RepositoryResult<TopicPostBatch> {
    const envelope: JsonObjectReader | null = JsonObjectReader.parse(text);
    const postStream: JsonObjectReader | null = envelope?.object('post_stream') ?? null;
    if (envelope === null || postStream === null) {
      return RepositoryResult.invalidResponse<TopicPostBatch>('服务器响应缺少 Post 列表');
    }
    const posts: Array<ForumPost> | null = decodePosts(postStream);
    return posts === null
      ? RepositoryResult.invalidResponse<TopicPostBatch>('服务器响应缺少 Post 列表')
      : RepositoryResult.success<TopicPostBatch>(new TopicPostBatch(posts, decodeSuggestedTopics(envelope)));
  }

  public parseTopicSuggestions(text: string): RepositoryResult<Array<Topic>> {
    const envelope: JsonObjectReader | null = JsonObjectReader.parse(text);
    return envelope === null
      ? RepositoryResult.invalidResponse<Array<Topic>>('服务器响应缺少推荐 Topic')
      : RepositoryResult.success<Array<Topic>>(decodeSuggestedTopics(envelope));
  }

  public parsePostReactionUsers(text: string): RepositoryResult<Array<PostReactionUsers>> {
    const envelope: JsonObjectReader | null = JsonObjectReader.parse(text);
    const reactionValues: Array<Object | null> | null = envelope?.array('reaction_users') ?? null;
    if (envelope === null || reactionValues === null) {
      return RepositoryResult.invalidResponse<Array<PostReactionUsers>>('服务器响应缺少 Reaction 用户');
    }
    const reactionUsers: Array<PostReactionUsers> = [];
    for (const reactionValue of reactionValues) {
      const reaction: JsonObjectReader | null = JsonObjectReader.fromValue(reactionValue);
      if (reaction === null) {
        continue;
      }
      const id: string = reactionId(reaction).trim();
      const userValues: Array<Object | null> | null = reaction.array('users');
      if (id.length === 0 || userValues === null) {
        continue;
      }
      const users: Array<PostReactionUser> = [];
      for (const userValue of userValues) {
        const user: JsonObjectReader | null = JsonObjectReader.fromValue(userValue);
        if (user === null) {
          continue;
        }
        const username: string = (
          user.string('username') ?? user.string('user_name') ?? user.string('slug') ?? ''
        ).trim();
        if (username.length === 0) {
          continue;
        }
        const avatar: string = user.string('avatar_template') ?? user.string('avatar_url') ??
          user.string('avatar') ?? '';
        users.push(new PostReactionUser(username, avatar));
      }
      if (users.length > 0) {
        reactionUsers.push(new PostReactionUsers(id, numberOrZero(reaction.number('count')), users));
      }
    }
    return RepositoryResult.success<Array<PostReactionUsers>>(reactionUsers);
  }

  public parseBookmarkId(text: string): RepositoryResult<number> {
    const envelope: JsonObjectReader | null = JsonObjectReader.parse(text);
    const id: number | null = envelope?.number('id') ?? null;
    return id === null || !Number.isInteger(id) || id <= 0
      ? RepositoryResult.invalidResponse<number>('服务器响应缺少书签标识')
      : RepositoryResult.success<number>(id);
  }

  public parseNotificationIdsForTopic(
    text: string,
    topicId: number,
    upToPostNumber: number
  ): RepositoryResult<Array<number>> {
    const envelope: JsonObjectReader | null = JsonObjectReader.parse(text);
    const values: Array<Object | null> | null = envelope?.array('notifications') ?? null;
    if (envelope === null || values === null) {
      return RepositoryResult.invalidResponse<Array<number>>('服务器响应缺少通知列表');
    }
    const uniqueIds: Set<number> = new Set<number>();
    for (const value of values) {
      const notification: JsonObjectReader | null = JsonObjectReader.fromValue(value);
      if (notification === null || notification.boolean('read') === true) {
        continue;
      }
      const data: JsonObjectReader | null = notification.object('data');
      const notificationTopicId: number | null = notification.number('topic_id') ?? data?.number('topic_id') ?? null;
      const postNumber: number | null = notification.number('post_number');
      const id: number | null = notification.number('id');
      if (
        id !== null && id > 0 &&
        notificationTopicId === topicId &&
        (postNumber === null || postNumber <= upToPostNumber)
      ) {
        uniqueIds.add(id);
      }
    }
    const ids: Array<number> = Array.from(uniqueIds.values());
    ids.sort((left: number, right: number): number => left - right);
    return RepositoryResult.success<Array<number>>(ids);
  }

  public parseCreatedReply(text: string): RepositoryResult<ForumPost> {
    const envelope: JsonObjectReader | null = JsonObjectReader.parse(text);
    if (envelope === null) {
      return RepositoryResult.invalidResponse<ForumPost>('服务器响应缺少已创建的 Reply');
    }
    const nestedPost: JsonObjectReader | null = envelope.object('post');
    const post: ForumPost | null = decodeCreatedPostReader(nestedPost ?? envelope);
    return post === null
      ? RepositoryResult.invalidResponse<ForumPost>('服务器响应缺少已创建的 Reply')
      : RepositoryResult.success<ForumPost>(post);
  }

  public parseCreatedTopicId(text: string): RepositoryResult<number> {
    const envelope: JsonObjectReader | null = JsonObjectReader.parse(text);
    const topicId: number | null = envelope === null
      ? null
      : integerFromReader(envelope, ['topic_id', 'id']);
    return topicId === null || topicId <= 0
      ? RepositoryResult.invalidResponse<number>('服务器发帖响应格式无效')
      : RepositoryResult.success<number>(topicId);
  }

  public parseDraftSequence(text: string): RepositoryResult<number> {
    const envelope: JsonObjectReader | null = JsonObjectReader.parse(text);
    const sequence: number | null = envelope === null
      ? null
      : integerFromReader(envelope, ['draft_sequence', 'sequence']);
    return sequence === null || sequence < 0
      ? RepositoryResult.invalidResponse<number>('服务器草稿响应格式无效')
      : RepositoryResult.success<number>(sequence);
  }

  public parseServerDrafts(text: string): RepositoryResult<Array<ServerDraft>> {
    const envelope: JsonObjectReader | null = JsonObjectReader.parse(text);
    const values: Array<Object | null> | null = envelope?.array('drafts') ?? null;
    if (envelope === null || values === null) {
      return RepositoryResult.invalidResponse<Array<ServerDraft>>('服务器草稿响应格式无效');
    }
    const drafts: Array<ServerDraft> = [];
    for (const value of values) {
      const item: JsonObjectReader | null = JsonObjectReader.fromValue(value);
      if (item === null) {
        continue;
      }
      const draftKey: string = item.string('draft_key')?.trim() ?? '';
      const sequence: number | null = integerFromReader(item, ['sequence']);
      let data: JsonObjectReader | null = item.object('data');
      if (data === null) {
        const encodedData: string | null = item.string('data');
        data = encodedData === null ? null : JsonObjectReader.parse(encodedData);
      }
      if (draftKey.length === 0 || sequence === null || sequence < 0 || data === null) {
        continue;
      }
      drafts.push(new ServerDraft(
        draftKey,
        sequence,
        data.string('action') ?? '',
        data.string('title') ?? item.string('title') ?? '',
        data.string('reply') ?? data.string('raw') ?? '',
        integerFromReader(data, ['category_id', 'categoryId']) ?? item.number('category_id'),
        integerFromReader(data, ['topic_id', 'topicId']) ?? item.number('topic_id'),
        integerFromReader(data, ['reply_to_post_number', 'replyToPostNumber']) ??
          item.number('reply_to_post_number')
      ));
    }
    return RepositoryResult.success<Array<ServerDraft>>(drafts);
  }
}
