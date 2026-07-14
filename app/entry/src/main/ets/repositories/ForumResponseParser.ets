import { RepositoryResult } from '../core/RepositoryResult';
import { JsonObjectReader } from '../core/JsonObjectReader';
import { Category, ForumPost, Topic, TopicDetail } from '../models/ForumModels';
import {
  ForumSearchResult,
  HomeChannel,
  SearchGroup,
  SearchPost,
  SearchTag,
  SearchUser
} from '../models/DiscoveryModels';
import { CurrentUser } from '../models/ReplyModels';

interface UserDto {
  id: number | null;
  username: string | null;
}

interface TopicPosterDto {
  user_id: number | null;
}

interface TopicDto {
  id: number | null;
  title: string | null;
  fancy_title: string | null;
  category_id: number | null;
  posts_count: number | null;
  views: number | null;
  like_count: number | null;
  excerpt: string | null;
  last_posted_at: string | null;
  bumped_at: string | null;
  pinned: boolean | null;
  posters: Array<TopicPosterDto | null> | null;
}

interface LatestTopicsDto {
  users: Array<UserDto | null>;
  topics: Array<TopicDto | null> | null;
}

interface CategoryDto {
  id: number | null;
  name: string | null;
  color: string | null;
  description_text: string | null;
  description_excerpt: string | null;
  description: string | null;
  position: number | null;
  parent_category_id: number | null;
  subcategory_ids: Array<number> | null;
  subcategories: Array<CategoryDto | null> | null;
}

function parseLatestEnvelope(text: string): LatestTopicsDto | null {
  const envelope: JsonObjectReader | null = JsonObjectReader.parse(text);
  if (envelope === null) {
    return null;
  }
  const users: Array<UserDto | null> = [];
  const userValues: Array<Object | null> | null = envelope.array('users');
  if (envelope.has('users') && userValues === null) {
    return null;
  }
  if (userValues !== null) {
    for (const value of userValues) {
      if (value === null) {
        users.push(null);
        continue;
      }
      const user: JsonObjectReader | null = JsonObjectReader.fromValue(value);
      if (user === null) {
        return null;
      }
      users.push({
        id: user.number('id'),
        username: user.string('username')
      });
    }
  }

  const topicList: JsonObjectReader | null = envelope.object('topic_list');
  if (topicList === null) {
    return { users: users, topics: null };
  }
  const topicValues: Array<Object | null> | null = topicList.array('topics');
  if (topicValues === null) {
    return { users: users, topics: null };
  }
  const topics: Array<TopicDto | null> = [];
  for (const value of topicValues) {
    if (value === null) {
      topics.push(null);
      continue;
    }
    const topic: JsonObjectReader | null = JsonObjectReader.fromValue(value);
    if (topic === null) {
      return null;
    }
    const posters: Array<TopicPosterDto | null> | null = decodePosters(topic);
    if (topic.has('posters') && posters === null) {
      return null;
    }
    topics.push({
      id: topic.number('id'),
      title: topic.string('title'),
      fancy_title: topic.string('fancy_title'),
      category_id: topic.number('category_id'),
      posts_count: topic.number('posts_count'),
      views: topic.number('views'),
      like_count: topic.number('like_count'),
      excerpt: topic.string('excerpt'),
      last_posted_at: topic.string('last_posted_at'),
      bumped_at: topic.string('bumped_at'),
      pinned: topic.boolean('pinned'),
      posters: posters
    });
  }
  return { users: users, topics: topics };
}

function decodePosters(topic: JsonObjectReader): Array<TopicPosterDto | null> | null {
  const values: Array<Object | null> | null = topic.array('posters');
  if (values === null) {
    return null;
  }
  const posters: Array<TopicPosterDto | null> = [];
  for (const value of values) {
    if (value === null) {
      posters.push(null);
      continue;
    }
    const poster: JsonObjectReader | null = JsonObjectReader.fromValue(value);
    if (poster === null) {
      return null;
    }
    posters.push({ user_id: poster.number('user_id') });
  }
  return posters;
}

function textOrEmpty(value: string | null): string {
  return typeof value === 'string' ? value : '';
}

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
  if (numericPreference === 1) {
    return HomeChannel.LATEST_REPLIES;
  }
  if (numericPreference === 4) {
    return HomeChannel.LATEST_CREATED;
  }
  if (numericPreference === 5) {
    return HomeChannel.HOT;
  }
  const textPreference: string = (
    userOption.string('homepage_id') ?? userOption.string('homepage') ??
      userOption.string('default_homepage') ?? ''
  ).trim().toLowerCase();
  if (textPreference === 'latest') {
    return HomeChannel.LATEST_REPLIES;
  }
  if (textPreference === 'new' || textPreference === 'created') {
    return HomeChannel.LATEST_CREATED;
  }
  if (textPreference === 'top' || textPreference === 'hot') {
    return HomeChannel.HOT;
  }
  return null;
}

function usernameForTopic(
  users: Array<UserDto | null>,
  posters: Array<TopicPosterDto | null> | null
): string {
  if (!Array.isArray(posters) || posters.length === 0) {
    return '';
  }
  const poster: TopicPosterDto | null = posters[0];
  if (poster === null) {
    return '';
  }
  const userId: number | null = poster.user_id;
  if (typeof userId !== 'number') {
    return '';
  }
  for (const user of users) {
    if (user !== null && user.id === userId && typeof user.username === 'string') {
      return user.username;
    }
  }
  return '';
}

function topicFromDto(dto: TopicDto, users: Array<UserDto | null>): Topic | null {
  if (typeof dto.id !== 'number') {
    return null;
  }
  const title: string = textOrEmpty(dto.title).length > 0
    ? textOrEmpty(dto.title)
    : textOrEmpty(dto.fancy_title);
  if (title.length === 0) {
    return null;
  }
  const lastPostedAt: string = textOrEmpty(dto.last_posted_at).length > 0
    ? textOrEmpty(dto.last_posted_at)
    : textOrEmpty(dto.bumped_at);
  return new Topic(
    dto.id,
    title,
    numberOrZero(dto.category_id),
    numberOrZero(dto.posts_count),
    numberOrZero(dto.views),
    numberOrZero(dto.like_count),
    textOrEmpty(dto.excerpt),
    lastPostedAt,
    dto.pinned === true,
    usernameForTopic(users, dto.posters)
  );
}

function collectCategoryDtos(envelope: JsonObjectReader): Array<CategoryDto> | null {
  const collected: Array<CategoryDto> = [];
  if (!appendCategoryArray(collected, envelope, 'categories') ||
    !appendCategoryArray(collected, envelope, 'subcategories')) {
    return null;
  }
  const listNames: Array<string> = ['category_list', 'subcategory_list'];
  for (const listName of listNames) {
    const list: JsonObjectReader | null = envelope.object(listName);
    if (list === null) {
      if (envelope.has(listName)) {
        return null;
      }
      continue;
    }
    if (!appendCategoryArray(collected, list, 'categories') ||
      !appendCategoryArray(collected, list, 'subcategories')) {
      return null;
    }
  }
  return collected;
}

function appendCategoryArray(
  target: Array<CategoryDto>,
  source: JsonObjectReader,
  name: string
): boolean {
  const values: Array<Object | null> | null = source.array(name);
  if (values === null) {
    return !source.has(name);
  }
  for (const value of values) {
    if (value === null) {
      continue;
    }
    const dto: CategoryDto | null = decodeCategoryDto(value);
    if (dto === null) {
      return false;
    }
    target.push(dto);
    appendNestedCategories(target, dto.subcategories);
  }
  return true;
}

function appendNestedCategories(target: Array<CategoryDto>, source: Array<CategoryDto | null> | null): void {
  if (source === null) {
    return;
  }
  for (const dto of source) {
    if (dto !== null) {
      target.push(dto);
      appendNestedCategories(target, dto.subcategories);
    }
  }
}

function decodeCategoryDto(value: Object): CategoryDto | null {
  const category: JsonObjectReader | null = JsonObjectReader.fromValue(value);
  if (category === null) {
    return null;
  }
  const subcategoryIds: Array<number> | null = decodeNumberArray(category, 'subcategory_ids');
  if (category.has('subcategory_ids') && subcategoryIds === null) {
    return null;
  }
  const subcategories: Array<CategoryDto | null> | null = decodeCategoryArray(category, 'subcategories');
  if (category.has('subcategories') && subcategories === null) {
    return null;
  }
  return {
    id: category.number('id'),
    name: category.string('name'),
    color: category.string('color'),
    description_text: category.string('description_text'),
    description_excerpt: category.string('description_excerpt'),
    description: category.string('description'),
    position: category.number('position'),
    parent_category_id: category.number('parent_category_id'),
    subcategory_ids: subcategoryIds,
    subcategories: subcategories
  };
}

function decodeNumberArray(source: JsonObjectReader, name: string): Array<number> | null {
  const values: Array<Object | null> | null = source.array(name);
  if (values === null) {
    return null;
  }
  const numbers: Array<number> = [];
  for (const value of values) {
    if (typeof value !== 'number' || !Number.isFinite(value)) {
      return null;
    }
    numbers.push(value);
  }
  return numbers;
}

function decodeCategoryArray(source: JsonObjectReader, name: string): Array<CategoryDto | null> | null {
  const values: Array<Object | null> | null = source.array(name);
  if (values === null) {
    return null;
  }
  const categories: Array<CategoryDto | null> = [];
  for (const value of values) {
    if (value === null) {
      categories.push(null);
      continue;
    }
    const category: CategoryDto | null = decodeCategoryDto(value);
    if (category === null) {
      return null;
    }
    categories.push(category);
  }
  return categories;
}

function descriptionFor(dto: CategoryDto): string {
  const descriptionText: string = textOrEmpty(dto.description_text);
  if (descriptionText.length > 0) {
    return descriptionText;
  }
  const excerpt: string = textOrEmpty(dto.description_excerpt);
  return excerpt.length > 0 ? excerpt : textOrEmpty(dto.description);
}

function categoryFromDto(dto: CategoryDto): Category | null {
  if (typeof dto.id !== 'number' || typeof dto.name !== 'string' || dto.name.length === 0) {
    return null;
  }
  const subcategoryIds: Array<number> = [];
  if (dto.subcategory_ids !== null) {
    for (const id of dto.subcategory_ids) {
      if (typeof id === 'number') {
        subcategoryIds.push(id);
      }
    }
  }
  return new Category(
    dto.id,
    dto.name,
    textOrEmpty(dto.color),
    descriptionFor(dto),
    typeof dto.position === 'number' ? dto.position : Number.MAX_SAFE_INTEGER,
    typeof dto.parent_category_id === 'number' ? dto.parent_category_id : null,
    subcategoryIds
  );
}

function compareCategoryPosition(left: Category, right: Category): number {
  if (left.position !== right.position) {
    return left.position - right.position;
  }
  return left.id - right.id;
}

function isChildOf(parent: Category, candidate: Category): boolean {
  return candidate.parentCategoryId === parent.id || parent.subcategoryIds.includes(candidate.id);
}

function compareChildren(parent: Category, left: Category, right: Category): number {
  const leftIndex: number = parent.subcategoryIds.indexOf(left.id);
  const rightIndex: number = parent.subcategoryIds.indexOf(right.id);
  if (leftIndex >= 0 && rightIndex >= 0 && leftIndex !== rightIndex) {
    return leftIndex - rightIndex;
  }
  if (leftIndex >= 0 && rightIndex < 0) {
    return -1;
  }
  if (leftIndex < 0 && rightIndex >= 0) {
    return 1;
  }
  return compareCategoryPosition(left, right);
}

function appendCategoryTree(
  parent: Category,
  categories: Array<Category>,
  visited: Set<number>,
  ordered: Array<Category>
): void {
  if (visited.has(parent.id)) {
    return;
  }
  visited.add(parent.id);
  ordered.push(parent);
  const children: Array<Category> = categories.filter((candidate: Category): boolean => {
    return !visited.has(candidate.id) && isChildOf(parent, candidate);
  });
  children.sort((left: Category, right: Category): number => compareChildren(parent, left, right));
  for (const child of children) {
    appendCategoryTree(child, categories, visited, ordered);
  }
}

function orderCategoryTree(categories: Array<Category>): Array<Category> {
  const categoriesById: Map<number, Category> = new Map<number, Category>();
  const referencedChildIds: Set<number> = new Set<number>();
  for (const category of categories) {
    categoriesById.set(category.id, category);
  }
  for (const category of categories) {
    if (category.parentCategoryId !== null && categoriesById.has(category.parentCategoryId)) {
      referencedChildIds.add(category.id);
    }
    for (const subcategoryId of category.subcategoryIds) {
      if (categoriesById.has(subcategoryId)) {
        referencedChildIds.add(subcategoryId);
      }
    }
  }

  const roots: Array<Category> = categories.filter((category: Category): boolean => {
    return !referencedChildIds.has(category.id);
  });
  roots.sort(compareCategoryPosition);
  const ordered: Array<Category> = [];
  const visited: Set<number> = new Set<number>();
  for (const root of roots) {
    appendCategoryTree(root, categories, visited, ordered);
  }

  const remaining: Array<Category> = categories.filter((category: Category): boolean => {
    return !visited.has(category.id);
  });
  remaining.sort(compareCategoryPosition);
  for (const category of remaining) {
    appendCategoryTree(category, categories, visited, ordered);
  }
  return ordered;
}

function forumPostFromReader(
  post: JsonObjectReader,
  id: number | null,
  postNumber: number | null
): ForumPost | null {
  if (id === null || id <= 0 || postNumber === null || postNumber <= 0) {
    return null;
  }
  return new ForumPost(
    id,
    numberOrZero(post.number('user_id')),
    textOrEmpty(post.string('username')),
    textOrEmpty(post.string('cooked')),
    textOrEmpty(post.string('raw')),
    postNumber,
    post.number('reply_to_post_number'),
    textOrEmpty(post.string('created_at'))
  );
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

export class ForumResponseParser {
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
      if (post !== null) {
        postReaders.push(post);
      }
    }
    const topics: Array<Topic> = [];
    const topicsById: Map<number, Topic> = new Map<number, Topic>();
    for (const value of topicValues ?? []) {
      const topic: JsonObjectReader | null = JsonObjectReader.fromValue(value);
      const id: number | null = topic?.number('id') ?? null;
      const title: string = topic?.string('title') ?? topic?.string('fancy_title') ?? '';
      if (topic === null || id === null || title.trim().length === 0) {
        continue;
      }
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
      if (id === null || topicId === null) {
        continue;
      }
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
        if (name.length > 0) {
          tags.push(new SearchTag(name, name, 0));
        }
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

  public parseCurrentUser(text: string): RepositoryResult<CurrentUser> {
    const envelope: JsonObjectReader | null = JsonObjectReader.parse(text);
    const user: JsonObjectReader | null = envelope?.object('current_user') ?? null;
    if (user === null) {
      return RepositoryResult.failure<CurrentUser>('服务器响应缺少当前用户');
    }
    const id: number | null = user.number('id');
    const username: string | null = user.string('username');
    const groups: GroupMemberships = groupMemberships(user);
    const userOption: JsonObjectReader | null = user.object('user_option');
    const currentUser: CurrentUser | null = id === null || username === null
      ? null
      : CurrentUser.create(
        id,
        username,
        {
          name: user.string('name') ?? '',
          title: user.string('title') ?? user.string('user_title') ?? '',
          admin: booleanOrFalse(user.boolean('admin')),
          moderator: booleanOrFalse(user.boolean('moderator')),
          trustLevel: numberOrZero(user.number('trust_level')),
          canCreatePost: canCreatePost(user),
          canChat: booleanOrFalse(user.boolean('can_chat')) ||
            booleanOrFalse(user.boolean('has_chat_enabled')) ||
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
        }
      );
    return currentUser === null
      ? RepositoryResult.failure<CurrentUser>('服务器响应缺少当前用户')
      : RepositoryResult.success<CurrentUser>(currentUser);
  }

  public parseLatestTopics(text: string): RepositoryResult<Array<Topic>> {
    const envelope: LatestTopicsDto | null = parseLatestEnvelope(text);
    if (envelope === null || envelope.topics === null) {
      return RepositoryResult.failure<Array<Topic>>('服务器响应缺少 Topic 列表');
    }
    const topics: Array<Topic> = [];
    const seenTopicIds: Set<number> = new Set<number>();
    for (const dto of envelope.topics) {
      if (dto === null) {
        continue;
      }
      const topic: Topic | null = topicFromDto(dto, envelope.users);
      if (topic !== null && !seenTopicIds.has(topic.id)) {
        seenTopicIds.add(topic.id);
        topics.push(topic);
      }
    }
    return RepositoryResult.success(topics);
  }

  public parseCategories(siteText: string, directoryText: string): RepositoryResult<Array<Category>> {
    const siteEnvelope: JsonObjectReader | null = JsonObjectReader.parse(siteText);
    const directoryEnvelope: JsonObjectReader | null = JsonObjectReader.parse(directoryText);
    if (siteEnvelope === null || directoryEnvelope === null) {
      return RepositoryResult.failure<Array<Category>>('服务器响应缺少 Category 目录');
    }

    const categoriesById: Map<number, Category> = new Map<number, Category>();
    const siteDtos: Array<CategoryDto> | null = collectCategoryDtos(siteEnvelope);
    const directoryDtos: Array<CategoryDto> | null = collectCategoryDtos(directoryEnvelope);
    if (siteDtos === null || directoryDtos === null) {
      return RepositoryResult.failure<Array<Category>>('服务器响应缺少 Category 目录');
    }
    const dtos: Array<CategoryDto> = siteDtos.concat(directoryDtos);
    for (const dto of dtos) {
      const category: Category | null = categoryFromDto(dto);
      if (category !== null && category.id !== 1 && category.id !== 4) {
        categoriesById.set(category.id, category);
      }
    }
    return RepositoryResult.success(orderCategoryTree(Array.from(categoriesById.values())));
  }

  public parseTopicDetail(text: string): RepositoryResult<TopicDetail> {
    const envelope: JsonObjectReader | null = JsonObjectReader.parse(text);
    if (envelope === null) {
      return RepositoryResult.failure<TopicDetail>('服务器响应缺少 Topic 详情');
    }
    const id: number | null = envelope.number('id');
    const directTitle: string = textOrEmpty(envelope.string('title'));
    const title: string = directTitle.length > 0 ? directTitle : textOrEmpty(envelope.string('fancy_title'));
    const postStream: JsonObjectReader | null = envelope.object('post_stream');
    if (id === null || id <= 0 || title.length === 0 || postStream === null) {
      return RepositoryResult.failure<TopicDetail>('服务器响应缺少 Topic 详情');
    }
    const postIds: Array<number> | null = decodeNumberArray(postStream, 'stream');
    const posts: Array<ForumPost> | null = decodePosts(postStream);
    if (postIds === null || posts === null) {
      return RepositoryResult.failure<TopicDetail>('服务器响应缺少 Post 列表');
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
      numberOrZero(envelope.number('highest_post_number'))
    );
    return RepositoryResult.success<TopicDetail>(detail);
  }

  public parseTopicPosts(text: string): RepositoryResult<Array<ForumPost>> {
    const envelope: JsonObjectReader | null = JsonObjectReader.parse(text);
    const postStream: JsonObjectReader | null = envelope?.object('post_stream') ?? null;
    if (postStream === null) {
      return RepositoryResult.failure<Array<ForumPost>>('服务器响应缺少 Post 列表');
    }
    const posts: Array<ForumPost> | null = decodePosts(postStream);
    return posts === null
      ? RepositoryResult.failure<Array<ForumPost>>('服务器响应缺少 Post 列表')
      : RepositoryResult.success<Array<ForumPost>>(posts);
  }

  public parseCreatedReply(text: string): RepositoryResult<ForumPost> {
    const envelope: JsonObjectReader | null = JsonObjectReader.parse(text);
    if (envelope === null) {
      return RepositoryResult.failure<ForumPost>('服务器响应缺少已创建的 Reply');
    }
    const nestedPost: JsonObjectReader | null = envelope.object('post');
    const post: ForumPost | null = decodeCreatedPostReader(nestedPost ?? envelope);
    return post === null
      ? RepositoryResult.failure<ForumPost>('服务器响应缺少已创建的 Reply')
      : RepositoryResult.success<ForumPost>(post);
  }
}
