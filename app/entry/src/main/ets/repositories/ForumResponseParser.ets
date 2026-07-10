import { RepositoryResult } from '../core/RepositoryResult';
import { Category, Topic } from '../models/ForumModels';

interface UserDto {
  id?: number;
  username?: string;
}

interface TopicPosterDto {
  user_id?: number;
}

interface TopicDto {
  id?: number;
  title?: string;
  fancy_title?: string;
  category_id?: number;
  posts_count?: number;
  views?: number;
  like_count?: number;
  excerpt?: string | null;
  last_posted_at?: string | null;
  bumped_at?: string | null;
  pinned?: boolean;
  posters?: Array<TopicPosterDto | null> | null;
}

interface TopicListDto {
  topics?: Array<TopicDto | null> | null;
}

interface LatestTopicsDto {
  users?: Array<UserDto | null> | null;
  topic_list?: TopicListDto | null;
}

interface CategoryDto {
  id?: number;
  name?: string;
  color?: string;
  description_text?: string | null;
  description_excerpt?: string | null;
  description?: string | null;
  position?: number;
  parent_category_id?: number | null;
  subcategory_ids?: Array<number> | null;
  subcategories?: Array<CategoryDto | null> | null;
}

interface CategoryListDto {
  categories?: Array<CategoryDto | null> | null;
  subcategories?: Array<CategoryDto | null> | null;
}

interface CategoryEnvelopeDto {
  categories?: Array<CategoryDto | null> | null;
  subcategories?: Array<CategoryDto | null> | null;
  category_list?: CategoryListDto | null;
  subcategory_list?: CategoryListDto | null;
}

function parseLatestEnvelope(text: string): LatestTopicsDto | null {
  try {
    const value: LatestTopicsDto | null = JSON.parse(text);
    if (value === null || Array.isArray(value)) {
      return null;
    }
    return value;
  } catch (_) {
    return null;
  }
}

function parseCategoryEnvelope(text: string): CategoryEnvelopeDto | null {
  try {
    const value: CategoryEnvelopeDto | null = JSON.parse(text);
    if (value === null || Array.isArray(value)) {
      return null;
    }
    return value;
  } catch (_) {
    return null;
  }
}

function textOrEmpty(value: string | null | undefined): string {
  return typeof value === 'string' ? value : '';
}

function numberOrZero(value: number | undefined): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : 0;
}

function usernameForTopic(
  users: Array<UserDto | null>,
  posters: Array<TopicPosterDto | null> | null | undefined
): string {
  if (!Array.isArray(posters) || posters.length === 0) {
    return '';
  }
  const poster: TopicPosterDto | null = posters[posters.length - 1];
  if (poster === null) {
    return '';
  }
  const userId: number | undefined = poster.user_id;
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

function collectCategoryDtos(envelope: CategoryEnvelopeDto): Array<CategoryDto> {
  const collected: Array<CategoryDto> = [];
  appendCategoryDtos(collected, envelope.categories);
  appendCategoryDtos(collected, envelope.subcategories);
  if (envelope.category_list !== undefined && envelope.category_list !== null) {
    appendCategoryDtos(collected, envelope.category_list.categories);
    appendCategoryDtos(collected, envelope.category_list.subcategories);
  }
  if (envelope.subcategory_list !== undefined && envelope.subcategory_list !== null) {
    appendCategoryDtos(collected, envelope.subcategory_list.categories);
    appendCategoryDtos(collected, envelope.subcategory_list.subcategories);
  }
  return collected;
}

function appendCategoryDtos(
  target: Array<CategoryDto>,
  source: Array<CategoryDto | null> | null | undefined
): void {
  if (!Array.isArray(source)) {
    return;
  }
  for (const dto of source) {
    if (dto === null) {
      continue;
    }
    target.push(dto);
    appendCategoryDtos(target, dto.subcategories);
  }
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
  if (Array.isArray(dto.subcategory_ids)) {
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

export class ForumResponseParser {
  public parseLatestTopics(text: string): RepositoryResult<Array<Topic>> {
    const envelope: LatestTopicsDto | null = parseLatestEnvelope(text);
    if (envelope === null || envelope.topic_list === undefined || envelope.topic_list === null) {
      return RepositoryResult.failure<Array<Topic>>('服务器响应缺少 Topic 列表');
    }
    const topicList: TopicListDto = envelope.topic_list;
    if (!Array.isArray(topicList.topics)) {
      return RepositoryResult.failure<Array<Topic>>('服务器响应缺少 Topic 列表');
    }
    const users: Array<UserDto | null> = Array.isArray(envelope.users) ? envelope.users : [];
    const topics: Array<Topic> = [];
    for (const dto of topicList.topics) {
      if (dto === null) {
        continue;
      }
      const topic: Topic | null = topicFromDto(dto, users);
      if (topic !== null) {
        topics.push(topic);
      }
    }
    return RepositoryResult.success(topics);
  }

  public parseCategories(siteText: string, directoryText: string): RepositoryResult<Array<Category>> {
    const siteEnvelope: CategoryEnvelopeDto | null = parseCategoryEnvelope(siteText);
    const directoryEnvelope: CategoryEnvelopeDto | null = parseCategoryEnvelope(directoryText);
    if (siteEnvelope === null || directoryEnvelope === null) {
      return RepositoryResult.failure<Array<Category>>('服务器响应缺少 Category 目录');
    }

    const categoriesById: Map<number, Category> = new Map<number, Category>();
    const dtos: Array<CategoryDto> = collectCategoryDtos(siteEnvelope).concat(collectCategoryDtos(directoryEnvelope));
    for (const dto of dtos) {
      const category: Category | null = categoryFromDto(dto);
      if (category !== null && category.id !== 1 && category.id !== 4) {
        categoriesById.set(category.id, category);
      }
    }
    return RepositoryResult.success(orderCategoryTree(Array.from(categoriesById.values())));
  }
}
