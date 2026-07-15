import { JsonObjectReader } from '../core/JsonObjectReader';
import { RepositoryResult } from '../core/RepositoryResult';
import { ComposerMentionUser } from '../models/ComposerMentionModels';
import {
  ForumSearchResult,
  OnlineUser,
  OnlineUsers,
  SearchGroup,
  SearchPost,
  SearchTag,
  SearchUser
} from '../models/DiscoveryModels';
import { Category, Topic } from '../models/ForumModels';

function numberOrZero(value: number | null): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : 0;
}

export class DiscoveryResponseParser {
  public parseSearch(text: string): RepositoryResult<ForumSearchResult> {
    const envelope: JsonObjectReader | null = JsonObjectReader.parse(text);
    if (envelope === null) {
      return RepositoryResult.failure<ForumSearchResult>('服务器搜索响应格式无效');
    }
    const postValues: Array<Object | null> | null = envelope.array('posts');
    const topicValues: Array<Object | null> | null = envelope.array('topics');
    const userValues: Array<Object | null> | null = envelope.array('users');
    const categoryValues: Array<Object | null> | null = envelope.array('categories');
    const tagValues: Array<Object | null> | null = envelope.array('tags');
    const groupValues: Array<Object | null> | null = envelope.array('groups');
    if ((envelope.has('posts') && postValues === null && !envelope.isNull('posts')) ||
      (envelope.has('topics') && topicValues === null && !envelope.isNull('topics')) ||
      (envelope.has('users') && userValues === null && !envelope.isNull('users')) ||
      (envelope.has('categories') && categoryValues === null && !envelope.isNull('categories')) ||
      (envelope.has('tags') && tagValues === null && !envelope.isNull('tags')) ||
      (envelope.has('groups') && groupValues === null && !envelope.isNull('groups'))) {
      return RepositoryResult.failure<ForumSearchResult>('服务器搜索响应格式无效');
    }

    const postReaders: Array<JsonObjectReader> = [];
    for (const value of postValues ?? []) {
      const post: JsonObjectReader | null = JsonObjectReader.fromValue(value);
      if (post !== null) postReaders.push(post);
    }
    const topics: Array<Topic> = [];
    const topicsById: Map<number, Topic> = new Map<number, Topic>();
    for (const value of topicValues ?? []) {
      const topic: JsonObjectReader | null = JsonObjectReader.fromValue(value);
      const id: number | null = topic?.number('id') ?? null;
      const title: string = topic?.string('title') ?? topic?.string('fancy_title') ?? '';
      if (topic === null || id === null || title.trim().length === 0) continue;
      let username: string = topic.string('username') ?? '';
      if (username.length === 0) {
        for (const post of postReaders) {
          if (post.number('topic_id') === id) {
            username = post.string('username') ?? '';
            break;
          }
        }
      }
      const parsedTopic: Topic = new Topic(
        id,
        title,
        numberOrZero(topic.number('category_id')),
        numberOrZero(topic.number('posts_count')),
        numberOrZero(topic.number('views')),
        numberOrZero(topic.number('like_count')),
        topic.string('excerpt') ?? '',
        topic.string('last_posted_at') ?? topic.string('bumped_at') ?? '',
        topic.boolean('pinned') === true,
        username
      );
      topics.push(parsedTopic);
      topicsById.set(id, parsedTopic);
    }

    const posts: Array<SearchPost> = [];
    for (const post of postReaders) {
      const id: number | null = post.number('id');
      const topicId: number | null = post.number('topic_id');
      if (id === null || topicId === null) continue;
      const fallbackTopic: Topic = new Topic(
        topicId,
        '搜索结果',
        0,
        0,
        0,
        0,
        post.string('blurb') ?? '',
        post.string('created_at') ?? '',
        false,
        post.string('username') ?? ''
      );
      posts.push(new SearchPost(
        id,
        topicsById.get(topicId) ?? fallbackTopic,
        numberOrZero(post.number('post_number')) || 1,
        post.string('username') ?? post.string('name') ?? '',
        post.string('blurb') ?? '',
        post.string('created_at') ?? ''
      ));
    }

    const users: Array<SearchUser> = [];
    for (const value of userValues ?? []) {
      const user: JsonObjectReader | null = JsonObjectReader.fromValue(value);
      const id: number | null = user?.number('id') ?? null;
      const username: string | null = user?.string('username') ?? null;
      if (user !== null && id !== null && username !== null && username.trim().length > 0) {
        users.push(new SearchUser(id, username, user.string('name') ?? '', user.string('avatar_template') ?? ''));
      }
    }

    const categories: Array<Category> = [];
    for (const value of categoryValues ?? []) {
      const category: JsonObjectReader | null = JsonObjectReader.fromValue(value);
      const id: number | null = category?.number('id') ?? null;
      const name: string | null = category?.string('name') ?? null;
      if (category !== null && id !== null && name !== null && name.trim().length > 0) {
        categories.push(new Category(
          id,
          name,
          category.string('color') ?? '',
          category.string('description_text') ?? category.string('description') ?? '',
          numberOrZero(category.number('position')),
          category.number('parent_category_id'),
          []
        ));
      }
    }

    const tags: Array<SearchTag> = [];
    for (const value of tagValues ?? []) {
      if (typeof value === 'string') {
        const name: string = value.trim();
        if (name.length > 0) tags.push(new SearchTag(name, name, 0));
        continue;
      }
      const tag: JsonObjectReader | null = JsonObjectReader.fromValue(value);
      const name: string | null = tag?.string('name') ?? null;
      if (tag !== null && name !== null && name.trim().length > 0) {
        const numericId: number | null = tag.number('id');
        tags.push(new SearchTag(
          tag.string('id') ?? (numericId === null ? name : numericId.toString()),
          name,
          numberOrZero(tag.number('topic_count'))
        ));
      }
    }

    const groups: Array<SearchGroup> = [];
    for (const value of groupValues ?? []) {
      const group: JsonObjectReader | null = JsonObjectReader.fromValue(value);
      const id: number | null = group?.number('id') ?? null;
      const name: string | null = group?.string('name') ?? null;
      if (group !== null && id !== null && name !== null && name.trim().length > 0) {
        groups.push(new SearchGroup(
          id,
          name,
          group.string('full_name') ?? group.string('title') ?? '',
          numberOrZero(group.number('user_count'))
        ));
      }
    }

    const grouped: JsonObjectReader | null = envelope.object('grouped_search_result');
    const hasMore: boolean = grouped?.boolean('more_full_page_results') === true ||
      grouped?.boolean('more_posts') === true || grouped?.boolean('more_users') === true ||
      grouped?.boolean('more_categories') === true || grouped?.boolean('more_tags') === true ||
      grouped?.boolean('more_groups') === true;
    return RepositoryResult.success<ForumSearchResult>(
      new ForumSearchResult(topics, posts, users, categories, tags, groups, hasMore)
    );
  }

  public parseSearchSuggestions(text: string): RepositoryResult<Array<string>> {
    const envelope: JsonObjectReader | null = JsonObjectReader.parse(text);
    const topicValues: Array<Object | null> | null = envelope?.array('topics') ?? null;
    if (envelope === null ||
      (envelope.has('topics') && topicValues === null && !envelope.isNull('topics'))) {
      return RepositoryResult.failure<Array<string>>('服务器搜索建议格式无效');
    }
    const suggestions: Array<string> = [];
    for (const value of topicValues ?? []) {
      const topic: JsonObjectReader | null = JsonObjectReader.fromValue(value);
      const title: string | null = topic?.string('title') ?? null;
      if (title !== null && title.trim().length > 0 && suggestions.length < 5) {
        suggestions.push(title.trim());
      }
    }
    return RepositoryResult.success<Array<string>>(suggestions);
  }

  public parseComposerMentionUsers(text: string): RepositoryResult<Array<ComposerMentionUser>> {
    const envelope: JsonObjectReader | null = JsonObjectReader.parse(text);
    const userValues: Array<Object | null> | null = envelope?.array('users') ?? null;
    if (envelope === null || userValues === null) {
      return RepositoryResult.failure<Array<ComposerMentionUser>>('用户提及联想格式无效');
    }
    const users: Array<ComposerMentionUser> = [];
    for (const value of userValues) {
      const user: JsonObjectReader | null = JsonObjectReader.fromValue(value);
      const username: string | null = user?.string('username') ?? null;
      if (username !== null && username.trim().length > 0 && users.length < 6) {
        users.push(new ComposerMentionUser(
          username,
          user?.string('name') ?? '',
          user?.string('avatar_template') ?? ''
        ));
      }
    }
    return RepositoryResult.success<Array<ComposerMentionUser>>(users);
  }

  public parseOnlineUsers(text: string): RepositoryResult<OnlineUsers> {
    const envelope: JsonObjectReader | null = JsonObjectReader.parse(text);
    const state: JsonObjectReader | null = envelope?.object('whos_online_state') ?? null;
    if (state === null) {
      return RepositoryResult.failure<OnlineUsers>('服务器在线用户格式无效');
    }
    const userValues: Array<Object | null> | null = state.array('users');
    if (state.has('users') && userValues === null && !state.isNull('users')) {
      return RepositoryResult.failure<OnlineUsers>('服务器在线用户格式无效');
    }
    const users: Array<OnlineUser> = [];
    for (const value of userValues ?? []) {
      const user: JsonObjectReader | null = JsonObjectReader.fromValue(value);
      const username: string | null = user?.string('username') ?? null;
      if (user !== null && username !== null && username.trim().length > 0) {
        users.push(new OnlineUser(
          numberOrZero(user.number('id')),
          username,
          user.string('name') ?? '',
          user.string('avatar_template') ?? ''
        ));
      }
    }
    const count: number = state.number('count') ?? users.length;
    return RepositoryResult.success<OnlineUsers>(new OnlineUsers(
      count,
      numberOrZero(state.number('last_message_id')),
      users
    ));
  }
}
