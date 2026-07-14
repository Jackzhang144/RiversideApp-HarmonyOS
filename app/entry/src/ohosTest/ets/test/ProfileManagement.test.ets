import { describe, expect, it } from '@ohos/hypium';
import { RepositoryResult, RepositoryResultKind } from '../../../main/ets/core/RepositoryResult';
import {
  UserBookmarkItem,
  ProfileNotificationLevel,
  ProfileUpdateRequest,
  UserReplyItem,
  UserEmailInfo,
  UserProfile,
  UserProfileSummary
} from '../../../main/ets/models/ProfileModels';
import { Topic } from '../../../main/ets/models/ForumModels';
import { ServerDraft } from '../../../main/ets/models/AuthoringModels';
import { HttpTextResult } from '../../../main/ets/network/DiscourseHttpClient';
import { DiscourseForumRepository } from '../../../main/ets/repositories/DiscourseForumRepository';
import { StubForumHttpClient } from './DiscourseForumRepository.test';

export default function profileManagementTest(): void {
  describe('Profile management contract', () => {
    it('uses the full Profile as the authority for identity groups and relationship state', 0,
      async (done: Function) => {
        const client: StubForumHttpClient = new StubForumHttpClient();
        client.results.push(HttpTextResult.success(200,
          '{"user":{"id":24,"username":"member","name":"河畔成员","title":"校友",' +
          '"avatar_template":"/user_avatar/river-side.cc/member/{size}/1_2.png",' +
          '"primary_group_id":45,"flair_group_id":50,"trust_level":3,' +
          '"groups":[{"id":45,"name":"scuer"},{"id":50,"name":"rs_developer"}],' +
          '"can_follow":true,"is_followed":true,"can_mute_user":true,"can_ignore_user":true,' +
          '"muted":false,"ignored":true,"can_upload_profile_header":true,' +
          '"profile_background_upload_url":"/uploads/default/original/profile.png",' +
          '"bio_raw":"简介","location":"成都","website":"https://river-side.cc",' +
          '"user_option":{"timezone":"Asia/Shanghai","hide_profile":false,"hide_presence":true}}}'
        ));
        const repository: DiscourseForumRepository = new DiscourseForumRepository(client);

        const result: RepositoryResult<UserProfile> = await repository.loadFullUserProfile(' member ');

        expect(client.paths[0]).assertEqual('/u/member.json');
        expect(result.kind).assertEqual(RepositoryResultKind.SUCCESS);
        expect(result.data?.displayName).assertEqual('河畔成员');
        expect(result.data?.isVerified).assertTrue();
        expect(result.data?.groups.length).assertEqual(2);
        expect(result.data?.following).assertTrue();
        expect(result.data?.notificationLevel).assertEqual(ProfileNotificationLevel.IGNORED);
        expect(result.data?.profileBackgroundUrl).assertEqual(
          'https://river-side.cc/uploads/default/original/profile.png'
        );
        done();
      });

    it('treats a missing low-activity summary as unavailable Profile activity, not failed identity', 0,
      async (done: Function) => {
        const client: StubForumHttpClient = new StubForumHttpClient();
        client.results.push(HttpTextResult.success(200, '{}'));
        const repository: DiscourseForumRepository = new DiscourseForumRepository(client);

        const result: RepositoryResult<UserProfileSummary> = await repository.loadUserSummary('quiet-user');

        expect(result.kind).assertEqual(RepositoryResultKind.SUCCESS);
        expect(result.data?.available).assertFalse();
        expect(result.data?.topicCount).assertEqual(0);
        expect(result.data?.postCount).assertEqual(0);
        done();
      });

    it('keeps Profile biography markup out of visible summary text', 0, async (done: Function) => {
      const client: StubForumHttpClient = new StubForumHttpClient();
      client.results.push(HttpTextResult.success(200,
        '{"user":{"id":24,"username":"member","bio_excerpt":' +
        '"河畔 ID：<a class=\\"mention\\" href=\\"/u/member\\">@成员</a> &amp; 校友"}}'
      ));
      const repository: DiscourseForumRepository = new DiscourseForumRepository(client);

      const result: RepositoryResult<UserProfile> = await repository.loadFullUserProfile('member');

      expect(result.data?.bioExcerpt).assertEqual('河畔 ID：@成员 & 校友');
      done();
    });

    it('loads emails through the read-only preferences contract', 0, async (done: Function) => {
      const client: StubForumHttpClient = new StubForumHttpClient();
      client.results.push(HttpTextResult.success(200,
        '{"email":"primary@example.com","secondary_emails":["second@example.com",""],' +
        '"unconfirmed_emails":["pending@example.com"]}'
      ));
      const repository: DiscourseForumRepository = new DiscourseForumRepository(client);

      const result: RepositoryResult<UserEmailInfo> = await repository.loadUserEmails('member');

      expect(client.paths[0]).assertEqual(
        '/u/member/emails.json?context=%2Fu%2Fmember%2Fpreferences%2Faccount'
      );
      expect(result.data?.allEmails().join(',')).assertEqual(
        'primary@example.com,second@example.com,pending@example.com'
      );
      done();
    });

    it('writes only explicitly changed Profile fields and exposes no email mutation methods', 0,
      async (done: Function) => {
        const client: StubForumHttpClient = new StubForumHttpClient();
        client.formPutResults.push(HttpTextResult.success(200, '{}'));
        const repository: DiscourseForumRepository = new DiscourseForumRepository(client);
        const request: ProfileUpdateRequest | null = ProfileUpdateRequest.create(
          'member',
          '新名字',
          null,
          '新简介',
          null,
          null
        );
        if (request === null) {
          expect(false).assertTrue();
          done();
          return;
        }

        const result: RepositoryResult<boolean> = await repository.updateUserProfile(request);

        expect(result.data).assertTrue();
        expect(client.formPutRequests[0]).assertEqual(
          '/u/member.json|name=%E6%96%B0%E5%90%8D%E5%AD%97&bio_raw=%E6%96%B0%E7%AE%80%E4%BB%8B'
        );
        done();
      });

    it('loads the authenticated users topics replies bookmarks and drafts from their native contracts', 0,
      async (done: Function) => {
        const client: StubForumHttpClient = new StubForumHttpClient();
        client.results.push(HttpTextResult.success(200,
          '{"users":[{"id":24,"username":"member"}],"topic_list":{"topics":[' +
          '{"id":301,"title":"我的主题","category_id":111,"posts_count":3,"views":20,' +
          '"like_count":2,"excerpt":"主题摘要","bumped_at":"2026-07-14T01:00:00Z",' +
          '"pinned":false,"posters":[{"user_id":24}]}' +
          ']}}'
        ));
        client.results.push(HttpTextResult.success(200,
          '{"user_actions":[{"id":902,"topic_id":302,"topic_title":"回复所在主题",' +
          '"category_id":111,"post_number":4,"created_at":"2026-07-14T02:00:00Z",' +
          '"username":"member","excerpt":"我的回复摘要"}]}'
        ));
        client.results.push(HttpTextResult.success(200,
          '{"user_bookmark_list":{"bookmarks":[{"id":701,"title":"收藏主题",' +
          '"excerpt":"收藏摘要","topic_id":303,"linked_post_number":6,"category_id":111,' +
          '"highest_post_number":8,"bumped_at":"2026-07-14T03:00:00Z",' +
          '"user":{"username":"author"}}]}}'
        ));
        client.results.push(HttpTextResult.success(200,
          '{"drafts":[{"draft_key":"new_topic","sequence":3,' +
          '"data":"{\\"title\\":\\"待发布主题\\",\\"reply\\":\\"草稿正文\\"}"}]}'
        ));
        const repository: DiscourseForumRepository = new DiscourseForumRepository(client);

        const topics: RepositoryResult<Array<Topic>> = await repository.loadUserTopics('member', 2);
        const replies: RepositoryResult<Array<UserReplyItem>> = await repository.loadUserReplies('member', 20);
        const bookmarks: RepositoryResult<Array<UserBookmarkItem>> = await repository.loadUserBookmarks('member', 1);
        const drafts: RepositoryResult<Array<ServerDraft>> = await repository.loadDrafts();

        expect(client.paths[0]).assertEqual('/topics/created-by/member.json?page=2');
        expect(client.paths[1]).assertEqual('/user_actions.json?offset=20&username=member&filter=5');
        expect(client.paths[2]).assertEqual('/u/member/bookmarks.json?page=1');
        expect(client.paths[3]).assertEqual('/drafts.json');
        expect(topics.data?.[0].id).assertEqual(301);
        expect(replies.data?.[0].topicId).assertEqual(302);
        expect(replies.data?.[0].postNumber).assertEqual(4);
        expect(bookmarks.data?.[0].bookmarkId).assertEqual(701);
        expect(bookmarks.data?.[0].postNumber).assertEqual(6);
        expect(drafts.data?.[0].title).assertEqual('待发布主题');
        done();
      });
  });
}
