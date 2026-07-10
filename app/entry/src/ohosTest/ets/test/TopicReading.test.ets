import { describe, expect, it } from '@ohos/hypium';
import {
  AppShellModel,
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

  public async loadLatestTopics(): Promise<RepositoryResult<Array<Topic>>> {
    return RepositoryResult.success<Array<Topic>>([]);
  }

  public async loadCategories(): Promise<RepositoryResult<Array<Category>>> {
    return RepositoryResult.success<Array<Category>>([]);
  }

  public async loadCategoryTopics(_categoryId: number): Promise<RepositoryResult<Array<Topic>>> {
    return RepositoryResult.success<Array<Topic>>([]);
  }

  public async loadTopicDetail(_topicId: number): Promise<RepositoryResult<TopicDetail>> {
    const result: RepositoryResult<TopicDetail> | undefined = this.topicDetailResults.shift();
    return result ?? RepositoryResult.failure<TopicDetail>('missing Topic detail result');
  }

  public async loadTopicPosts(_topicId: number, _postIds: Array<number>): Promise<RepositoryResult<Array<ForumPost>>> {
    return RepositoryResult.success<Array<ForumPost>>([]);
  }
}

function topic(): Topic {
  return new Topic(2725, '站务管理区重要主题导航', 60, 1, 1959, 4, '', '', true, 'Co-admin');
}

function firstPost(): ForumPost {
  return new ForumPost(102728, 24, 'Co-admin', '<h1>站务公告</h1>', '站务公告', 1, null, '2026-01-27T14:46:08.722Z');
}

export default function topicReadingTest(): void {
  describe('AppShell Topic reading', () => {
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
  });
}
