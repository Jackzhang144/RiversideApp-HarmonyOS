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
  posters?: Array<TopicPosterDto>;
}

interface TopicListDto {
  topics?: Array<TopicDto>;
}

interface LatestTopicsDto {
  users?: Array<UserDto>;
  topic_list?: TopicListDto;
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
  subcategories?: Array<CategoryDto>;
}

interface CategoryListDto {
  categories?: Array<CategoryDto>;
  subcategories?: Array<CategoryDto>;
}

interface CategoryEnvelopeDto {
  categories?: Array<CategoryDto>;
  subcategories?: Array<CategoryDto>;
  category_list?: CategoryListDto;
  subcategory_list?: CategoryListDto;
}

function parseLatestEnvelope(text: string): LatestTopicsDto | null {
  try {
    const value: Object | null = JSON.parse(text);
    if (value === null || Array.isArray(value)) {
      return null;
    }
    // JSON.parse exposes Object in ArkTS. Keep the assertion at this boundary;
    // every consumed field is checked before it becomes a domain model.
    return value as LatestTopicsDto;
  } catch (_) {
    return null;
  }
}

function parseCategoryEnvelope(text: string): CategoryEnvelopeDto | null {
  try {
    const value: Object | null = JSON.parse(text);
    if (value === null || Array.isArray(value)) {
      return null;
    }
    // See parseLatestEnvelope: untrusted fields are validated during mapping.
    return value as CategoryEnvelopeDto;
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

function usernameForTopic(users: Array<UserDto>, posters: Array<TopicPosterDto> | undefined): string {
  if (!Array.isArray(posters) || posters.length === 0) {
    return '';
  }
  const userId: number | undefined = posters[posters.length - 1].user_id;
  if (typeof userId !== 'number') {
    return '';
  }
  for (const user of users) {
    if (user.id === userId && typeof user.username === 'string') {
      return user.username;
    }
  }
  return '';
}

function topicFromDto(dto: TopicDto, users: Array<UserDto>): Topic | null {
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
  if (envelope.category_list !== undefined) {
    appendCategoryDtos(collected, envelope.category_list.categories);
    appendCategoryDtos(collected, envelope.category_list.subcategories);
  }
  if (envelope.subcategory_list !== undefined) {
    appendCategoryDtos(collected, envelope.subcategory_list.categories);
    appendCategoryDtos(collected, envelope.subcategory_list.subcategories);
  }
  return collected;
}

function appendCategoryDtos(target: Array<CategoryDto>, source: Array<CategoryDto> | undefined): void {
  if (!Array.isArray(source)) {
    return;
  }
  for (const dto of source) {
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

export class ForumResponseParser {
  public parseLatestTopics(text: string): RepositoryResult<Array<Topic>> {
    const envelope: LatestTopicsDto | null = parseLatestEnvelope(text);
    if (envelope === null || envelope.topic_list === undefined || !Array.isArray(envelope.topic_list.topics)) {
      return RepositoryResult.failure<Array<Topic>>('服务器响应缺少 Topic 列表');
    }
    const users: Array<UserDto> = Array.isArray(envelope.users) ? envelope.users : [];
    const topics: Array<Topic> = [];
    for (const dto of envelope.topic_list.topics) {
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
    const categories: Array<Category> = Array.from(categoriesById.values());
    categories.sort((left: Category, right: Category): number => {
      if (left.position !== right.position) {
        return left.position - right.position;
      }
      return left.id - right.id;
    });
    return RepositoryResult.success(categories);
  }
}
