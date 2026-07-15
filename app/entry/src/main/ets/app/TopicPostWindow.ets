import { ForumPost } from '../models/ForumModels';
import { orderPosts } from './TopicReadingModels';

export class TopicPostWindow {
  public readonly posts: Array<ForumPost>;
  public readonly previousPostIds: Array<number>;
  public readonly nextPostIds: Array<number>;

  private constructor(
    posts: Array<ForumPost>,
    previousPostIds: Array<number>,
    nextPostIds: Array<number>
  ) {
    this.posts = posts.slice();
    this.previousPostIds = previousPostIds.slice();
    this.nextPostIds = nextPostIds.slice();
  }

  public static from(postIds: Array<number>, visiblePosts: Array<ForumPost>): TopicPostWindow {
    const posts: Array<ForumPost> = orderPosts(postIds, visiblePosts);
    let firstVisibleIndex: number = postIds.length;
    let lastVisibleIndex: number = -1;
    for (const post of posts) {
      const index: number = postIds.indexOf(post.id);
      if (index >= 0) {
        firstVisibleIndex = Math.min(firstVisibleIndex, index);
        lastVisibleIndex = Math.max(lastVisibleIndex, index);
      }
    }
    if (lastVisibleIndex < 0) {
      return new TopicPostWindow(posts, [], postIds);
    }
    return new TopicPostWindow(
      posts,
      postIds.slice(0, firstVisibleIndex),
      postIds.slice(lastVisibleIndex + 1)
    );
  }

  public hasPreviousPosts(): boolean {
    return this.previousPostIds.length > 0;
  }

  public hasNextPosts(): boolean {
    return this.nextPostIds.length > 0;
  }
}
