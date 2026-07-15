import { describe, expect, it } from '@ohos/hypium';
import {
  ProfileContentKind,
  ProfileContentModel,
  profileContentDestinationTitle,
  profileContentKindsForProfile
} from '../../../main/ets/app/ProfileContentModel';
import { ProfileSessionLifecycle } from '../../../main/ets/app/ProfileManagementModel';
import { HttpTextResult } from '../../../main/ets/network/DiscourseHttpClient';
import { DiscourseForumRepository } from '../../../main/ets/repositories/DiscourseForumRepository';
import { StubForumHttpClient } from './DiscourseForumRepository.test';

class StubContentSessionLifecycle implements ProfileSessionLifecycle {
  public unauthorizedCount: number = 0;

  public async handleUnauthorized(): Promise<void> {
    this.unauthorizedCount += 1;
  }
}

function topicListJson(id: number, title: string): string {
  return '{"users":[{"id":24,"username":"member"}],"topic_list":{"topics":[' +
    '{"id":' + id + ',"title":"' + title + '","category_id":111,"posts_count":1,' +
    '"views":1,"like_count":0,"excerpt":"摘要","bumped_at":"2026-07-14T01:00:00Z",' +
    '"pinned":false,"posters":[{"user_id":24}]}' +
    ']}}';
}

export default function profileContentModelTest(): void {
  describe('Profile content pagination state', () => {
    it('projects the content destinations available to own and other profiles', 0, (): void => {
      expect(profileContentKindsForProfile(true).length).assertEqual(4);
      const otherKinds: Array<ProfileContentKind> = profileContentKindsForProfile(false);
      expect(otherKinds.length).assertEqual(2);
      expect(otherKinds[0]).assertEqual(ProfileContentKind.TOPICS);
      expect(otherKinds[1]).assertEqual(ProfileContentKind.REPLIES);
      expect(profileContentDestinationTitle(ProfileContentKind.TOPICS, false, 'member'))
        .assertEqual('member 的 Topic');
      expect(profileContentDestinationTitle(ProfileContentKind.REPLIES, true, 'member'))
        .assertEqual('我的 Reply');
    });

    it('loads and deduplicates Topic pages using the native page contract', 0,
      async (done: Function) => {
        const client: StubForumHttpClient = new StubForumHttpClient();
        client.results.push(HttpTextResult.success(200, topicListJson(301, '第一页')));
        client.results.push(HttpTextResult.success(200, topicListJson(302, '第二页')));
        client.results.push(HttpTextResult.success(200, '{"topic_list":{"topics":[]}}'));
        const model: ProfileContentModel = new ProfileContentModel(
          new DiscourseForumRepository(client),
          new StubContentSessionLifecycle()
        );

        await model.load('member', ProfileContentKind.TOPICS);
        await model.loadMore();
        await model.loadMore();

        expect(client.paths[0]).assertEqual('/topics/created-by/member.json');
        expect(client.paths[1]).assertEqual('/topics/created-by/member.json?page=1');
        expect(client.paths[2]).assertEqual('/topics/created-by/member.json?page=2');
        expect(model.state.topics.length).assertEqual(2);
        expect(model.state.topics[1].id).assertEqual(302);
        expect(model.state.hasMore).assertFalse();
        done();
      });

    it('invalidates the session and clears protected content after 401', 0,
      async (done: Function) => {
        const client: StubForumHttpClient = new StubForumHttpClient();
        client.results.push(HttpTextResult.unauthorized());
        const lifecycle: StubContentSessionLifecycle = new StubContentSessionLifecycle();
        const model: ProfileContentModel = new ProfileContentModel(
          new DiscourseForumRepository(client),
          lifecycle
        );

        await model.load('member', ProfileContentKind.BOOKMARKS);

        expect(lifecycle.unauthorizedCount).assertEqual(1);
        expect(model.state.bookmarks.length).assertEqual(0);
        expect(model.state.loading).assertFalse();
        done();
      });

    it('keeps loaded content and exposes a retryable pagination failure', 0,
      async (done: Function) => {
        const client: StubForumHttpClient = new StubForumHttpClient();
        client.results.push(HttpTextResult.success(200, topicListJson(301, '已加载')));
        client.results.push(HttpTextResult.failure(503, '下一页暂时不可用'));
        const model: ProfileContentModel = new ProfileContentModel(
          new DiscourseForumRepository(client),
          new StubContentSessionLifecycle()
        );

        await model.load('member', ProfileContentKind.TOPICS);
        await model.loadMore();

        expect(model.state.topics.length).assertEqual(1);
        expect(model.state.message).assertEqual('下一页暂时不可用');
        expect(model.state.hasMore).assertTrue();
        done();
      });
  });
}
