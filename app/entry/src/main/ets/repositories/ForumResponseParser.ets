import { RepositoryResult } from '../core/RepositoryResult';
import { JsonObjectReader } from '../core/JsonObjectReader';
import { Category, ForumPost, Topic, TopicDetail } from '../models/ForumModels';
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

function usernameForTopic(
  users: Array<UserDto | null>,
  posters: Array<TopicPosterDto | null> | null
): string {
  if (!Array.isArray(posters) || posters.length === 0) {
    return '';
  }
  const poster: TopicPosterDto | null = posters[posters.length - 1];
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

function decodePostReader(post: JsonObjectReader): ForumPost | null {
  const id: number | null = post.number('id') ?? post.number('post_id');
  const postNumber: number | null = post.number('post_number') ?? post.number('target_post_number');
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
  public parseCurrentUser(text: string): RepositoryResult<CurrentUser> {
    const envelope: JsonObjectReader | null = JsonObjectReader.parse(text);
    const user: JsonObjectReader | null = envelope?.object('current_user') ?? null;
    if (user === null) {
      return RepositoryResult.failure<CurrentUser>('服务器响应缺少当前用户');
    }
    const id: number | null = user.number('id');
    const username: string | null = user.string('username');
    const currentUser: CurrentUser | null = id === null || username === null
      ? null
      : CurrentUser.create(id, username);
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
      posts
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
    const post: ForumPost | null = decodePostReader(nestedPost ?? envelope);
    return post === null
      ? RepositoryResult.failure<ForumPost>('服务器响应缺少已创建的 Reply')
      : RepositoryResult.success<ForumPost>(post);
  }
}
