import { describe, expect, it } from '@ohos/hypium';
import {
  AppShellModel,
  BrowseStateKind,
  RootDestination,
  SecondaryDestination,
  TopicReadStateKind
} from '../../../main/ets/app/AppShellModel';
import { CategoryCacheScope } from '../../../main/ets/cache/CategoryCache';
import { RepositoryResult } from '../../../main/ets/core/RepositoryResult';
import { Category, ForumPost, Topic, TopicDetail } from '../../../main/ets/models/ForumModels';
import { ForumRepository } from '../../../main/ets/repositories/ForumRepository';
import { MemoryCategoryCache } from './support/MemoryCategoryCache';

class TopicReadingRepository implements ForumRepository {
  public topicDetailResults: Array<RepositoryResult<TopicDetail>> = [];
  public topicPostResults: Array<RepositoryResult<Array<ForumPost>>> = [];
  public categoryTopicResults: Array<RepositoryResult<Array<Topic>>> = [];
  public requestedCategoryIds: Array<number> = [];
  public requestedPostIds: Array<Array<number>> = [];

  public async loadLatestTopics(): Promise<RepositoryResult<Array<Topic>>> {
    return RepositoryResult.success<Array<Topic>>([]);
  }

  public async loadCategories(): Promise<RepositoryResult<Array<Category>>> {
    return RepositoryResult.success<Array<Category>>([]);
  }

  public async loadCategoryTopics(categoryId: number): Promise<RepositoryResult<Array<Topic>>> {
    this.requestedCategoryIds.push(categoryId);
    const result: RepositoryResult<Array<Topic>> | undefined = this.categoryTopicResults.shift();
    return result ?? RepositoryResult.failure<Array<Topic>>('missing Category Topic result');
  }

  public async loadTopicDetail(_topicId: number): Promise<RepositoryResult<TopicDetail>> {
    const result: RepositoryResult<TopicDetail> | undefined = this.topicDetailResults.shift();
    return result ?? RepositoryResult.failure<TopicDetail>('missing Topic detail result');
  }

  public async loadTopicPosts(_topicId: number, postIds: Array<number>): Promise<RepositoryResult<Array<ForumPost>>> {
    this.requestedPostIds.push(postIds);
    const result: RepositoryResult<Array<ForumPost>> | undefined = this.topicPostResults.shift();
    return result ?? RepositoryResult.failure<Array<ForumPost>>('missing Post result');
  }
}

function topic(): Topic {
  return new Topic(2725, '站务管理区重要主题导航', 60, 1, 1959, 4, '', '', true, 'Co-admin');
}

function category(): Category {
  return new Category(60, '站务管理', '25AAE2', '站务与公告', 1, null, []);
}

function firstPost(): ForumPost {
  return new ForumPost(102728, 24, 'Co-admin', '<h1>站务公告</h1>', '站务公告', 1, null, '2026-01-27T14:46:08.722Z');
}

function secondPost(): ForumPost {
  return new ForumPost(102729, 1, 'admin', '<p>第一条 Reply</p>', '第一条 Reply', 2, null, '2026-01-28T00:00:00Z');
}

function thirdPost(): ForumPost {
  return new ForumPost(102730, 24, 'Co-admin', '<p>第二条 Reply</p>', '第二条 Reply', 3, 2, '2026-01-28T00:01:00Z');
}

export default function topicReadingTest(): void {
  describe('AppShell Topic reading', () => {
    it('opens a Category Topic list as a retryable secondary page', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.categoryTopicResults.push(RepositoryResult.failure<Array<Topic>>('网络连接失败'));
      repository.categoryTopicResults.push(RepositoryResult.success<Array<Topic>>([topic()]));
      const model: AppShellModel = new AppShellModel(
        repository,
        new MemoryCategoryCache(),
        CategoryCacheScope.anonymous()
      );

      const loading: Promise<void> = model.openCategory(category());
      expect(model.activeDestination).assertEqual(SecondaryDestination.CATEGORY_TOPICS);
      expect(model.categoryTopicsState.kind).assertEqual(BrowseStateKind.LOADING);
      await loading;
      expect(model.categoryTopicsState.kind).assertEqual(BrowseStateKind.ERROR);

      await model.retryCategoryTopics();
      expect(repository.requestedCategoryIds.join(',')).assertEqual('60,60');
      expect(model.categoryTopicsState.kind).assertEqual(BrowseStateKind.CONTENT);
      expect(model.categoryTopicsState.items[0].id).assertEqual(2725);

      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725,
        '站务管理区重要主题导航',
        1959,
        1,
        4,
        false,
        false,
        true,
        [102728],
        [firstPost()]
      )));
      await model.openTopic(topic());
      model.closeSecondary();
      expect(model.activeDestination).assertEqual(SecondaryDestination.CATEGORY_TOPICS);
      done();
    });

    it('opens a Topic as a secondary page and preserves the selected root when closed', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725,
        '站务管理区重要主题导航',
        1959,
        1,
        4,
        true,
        false,
        false,
        [102728],
        [firstPost()]
      )));
      const model: AppShellModel = new AppShellModel(
        repository,
        new MemoryCategoryCache(),
        CategoryCacheScope.anonymous()
      );
      model.selectRoot(RootDestination.CATEGORY);

      const loading: Promise<void> = model.openTopic(topic());
      expect(model.activeDestination).assertEqual(SecondaryDestination.TOPIC);
      expect(model.topicState.kind).assertEqual(TopicReadStateKind.LOADING);
      await loading;

      expect(model.topicState.kind).assertEqual(TopicReadStateKind.CONTENT);
      expect(model.topicState.posts.length).assertEqual(1);
      expect(model.topicState.posts[0].id).assertEqual(102728);
      expect(model.topicState.canReply).assertFalse();

      model.closeSecondary();
      expect(model.activeDestination).assertEqual(SecondaryDestination.NONE);
      expect(model.selectedRoot).assertEqual(RootDestination.CATEGORY);
      done();
    });

    it('preserves visible Posts when pagination fails and retries the same window', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725,
        '站务管理区重要主题导航',
        1959,
        3,
        4,
        false,
        false,
        true,
        [102728, 102729, 102730],
        [firstPost()]
      )));
      repository.topicPostResults.push(RepositoryResult.failure<Array<ForumPost>>('网络连接失败'));
      repository.topicPostResults.push(RepositoryResult.success<Array<ForumPost>>([
        firstPost(),
        secondPost(),
        thirdPost()
      ]));
      const model: AppShellModel = new AppShellModel(
        repository,
        new MemoryCategoryCache(),
        CategoryCacheScope.anonymous()
      );
      await model.openTopic(topic());

      const failingLoad: Promise<void> = model.loadMorePosts();
      expect(model.topicState.isLoadingMore).assertTrue();
      await failingLoad;

      expect(model.topicState.posts.length).assertEqual(1);
      expect(model.topicState.hasMorePosts).assertTrue();
      expect(model.topicState.paginationMessage).assertEqual('网络连接失败');
      expect(repository.requestedPostIds[0].join(',')).assertEqual('102729,102730');

      await model.retryTopicPosts();

      expect(repository.requestedPostIds[1].join(',')).assertEqual('102729,102730');
      expect(model.topicState.posts.length).assertEqual(3);
      expect(model.topicState.hasMorePosts).assertFalse();
      expect(model.topicState.paginationMessage).assertEqual('');
      done();
    });
  });
}
