export class Topic {
  public readonly id: number;
  public readonly title: string;
  public readonly categoryId: number;
  public readonly postCount: number;
  public readonly viewCount: number;
  public readonly likeCount: number;
  public readonly excerpt: string;
  public readonly lastPostedAt: string;
  public readonly pinned: boolean;
  public readonly username: string;

  public constructor(
    id: number,
    title: string,
    categoryId: number,
    postCount: number,
    viewCount: number,
    likeCount: number,
    excerpt: string,
    lastPostedAt: string,
    pinned: boolean,
    username: string
  ) {
    this.id = id;
    this.title = title;
    this.categoryId = categoryId;
    this.postCount = postCount;
    this.viewCount = viewCount;
    this.likeCount = likeCount;
    this.excerpt = excerpt;
    this.lastPostedAt = lastPostedAt;
    this.pinned = pinned;
    this.username = username;
  }
}

export class Category {
  public readonly id: number;
  public readonly name: string;
  public readonly color: string;
  public readonly description: string;
  public readonly position: number;
  public readonly parentCategoryId: number | null;
  public readonly subcategoryIds: Array<number>;

  public constructor(
    id: number,
    name: string,
    color: string,
    description: string,
    position: number,
    parentCategoryId: number | null,
    subcategoryIds: Array<number>
  ) {
    this.id = id;
    this.name = name;
    this.color = color;
    this.description = description;
    this.position = position;
    this.parentCategoryId = parentCategoryId;
    this.subcategoryIds = subcategoryIds;
  }
}
