import { describe, expect, it } from '@ohos/hypium';
import { RepositoryResult, RepositoryResultKind } from '../../../main/ets/core/RepositoryResult';
import {
  UserBookmarkItem,
  ProfileNotificationLevel,
  ProfileUpdateRequest,
  profileIgnoreExpiry,
  UserReplyItem,
  UserEmailInfo,
  UserProfile,
  UserProfileSummary
} from '../../../main/ets/models/ProfileModels';
import { Topic } from '../../../main/ets/models/ForumModels';
import { ServerDraft } from '../../../main/ets/models/AuthoringModels';
import { HttpTextResult } from '../../../main/ets/network/DiscourseHttpClient';
import { DiscourseProfileRepository } from '../../../main/ets/repositories/DiscourseProfileRepository';
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
        const repository: DiscourseProfileRepository = new DiscourseProfileRepository(client);

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
        const repository: DiscourseProfileRepository = new DiscourseProfileRepository(client);

        const result: RepositoryResult<UserProfileSummary> = await repository.loadUserSummary('quiet-user');

        expect(result.kind).assertEqual(RepositoryResultKind.SUCCESS);
        expect(result.data?.available).assertFalse();
        expect(result.data?.topicCount).assertEqual(0);
        expect(result.data?.postCount).assertEqual(0);
        done();
      });

    it('keeps badge names and images from the Profile summary', 0, async (done: Function) => {
      const client: StubForumHttpClient = new StubForumHttpClient();
      client.results.push(HttpTextResult.success(200,
        '{"user_summary":{"topic_count":6,"post_count":41},' +
        '"badges":[{"name":"热心成员","image_url":"/images/badges/enthusiast.svg"},' +
        '{"display_name":"解决达人","name":"solver"}]}'
      ));
      const repository: DiscourseProfileRepository = new DiscourseProfileRepository(client);

      const result: RepositoryResult<UserProfileSummary> =
        await repository.loadUserSummary('member');

      expect(result.data?.badges.length).assertEqual(2);
      expect(result.data?.badges[0].name).assertEqual('热心成员');
      expect(result.data?.badges[0].imageUrl)
        .assertEqual('https://river-side.cc/images/badges/enthusiast.svg');
      expect(result.data?.badges[1].name).assertEqual('解决达人');
      done();
    });

    it('keeps Profile biography markup out of visible summary text', 0, async (done: Function) => {
      const client: StubForumHttpClient = new StubForumHttpClient();
      client.results.push(HttpTextResult.success(200,
        '{"user":{"id":24,"username":"member","bio_excerpt":' +
        '"河畔 ID：<a class=\\"mention\\" href=\\"/u/member\\">@成员</a> &amp; 校友"}}'
      ));
      const repository: DiscourseProfileRepository = new DiscourseProfileRepository(client);

      const result: RepositoryResult<UserProfile> = await repository.loadFullUserProfile('member');

      expect(result.data?.bioExcerpt).assertEqual('河畔 ID：@成员 & 校友');
      done();
    });

    it('accepts verified primary or flair group names when the compact Profile omits groups', 0,
      async (done: Function) => {
        const client: StubForumHttpClient = new StubForumHttpClient();
        client.results.push(HttpTextResult.success(200,
          '{"user":{"id":24,"username":"member","flair_name":"scuer"}}'
        ));
        const repository: DiscourseProfileRepository = new DiscourseProfileRepository(client);

        const result: RepositoryResult<UserProfile> = await repository.loadFullUserProfile('member');

        expect(result.data?.isVerified).assertTrue();
        done();
      });

    it('loads emails through the read-only preferences contract', 0, async (done: Function) => {
      const client: StubForumHttpClient = new StubForumHttpClient();
      client.results.push(HttpTextResult.success(200,
        '{"email":"primary@example.com","secondary_emails":["second@example.com",""],' +
        '"unconfirmed_emails":["pending@example.com"]}'
      ));
      const repository: DiscourseProfileRepository = new DiscourseProfileRepository(client);

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
        const repository: DiscourseProfileRepository = new DiscourseProfileRepository(client);
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

    it('encodes the hide-presence preference as an explicit profile field', 0,
      async (done: Function) => {
        const client: StubForumHttpClient = new StubForumHttpClient();
        client.formPutResults.push(HttpTextResult.success(200, '{}'));
        const repository: DiscourseProfileRepository = new DiscourseProfileRepository(client);
        const request: ProfileUpdateRequest | null = ProfileUpdateRequest.create(
          'member',
          null,
          null,
          null,
          null,
          null,
          true
        );
        if (request === null) {
          expect(false).assertTrue();
          done();
          return;
        }

        const result: RepositoryResult<boolean> = await repository.updateUserProfile(request);

        expect(result.data).assertTrue();
        expect(client.formPutRequests[0]).assertEqual('/u/member.json|hide_presence=true');
        done();
      });

    it('builds the four ignore expiry choices and sends the selected value', 0,
      async (done: Function) => {
        const client: StubForumHttpClient = new StubForumHttpClient();
        client.formPutResults.push(HttpTextResult.success(200, '{}'));
        const repository: DiscourseProfileRepository = new DiscourseProfileRepository(client);
        const now: Date = new Date('2026-07-14T08:00:00+08:00');
        const oneDay: string = profileIgnoreExpiry(1, now);
        const oneWeek: string = profileIgnoreExpiry(7, now);
        const oneMonth: string = profileIgnoreExpiry(30, now);
        const forever: string = profileIgnoreExpiry(null, now);

        await repository.setUserNotificationLevel(
          'member',
          ProfileNotificationLevel.IGNORED,
          24,
          oneMonth
        );

        expect(oneDay).assertEqual('2026-07-15 08:00+08:00');
        expect(oneWeek).assertEqual('2026-07-21 08:00+08:00');
        expect(oneMonth).assertEqual('2026-08-13 08:00+08:00');
        expect(forever).assertEqual('3026-05-01 08:00-05:00');
        expect(client.formPutRequests[0]).assertEqual(
          '/u/member/notification_level.json|' +
          'notification_level=ignore&expiring_at=2026-08-13%2008%3A00%2B08%3A00&acting_user_id=24'
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
          '{"user_actions":[{"id":902,"topic_id":302,"title":"回复所在主题",' +
          '"category_id":111,"post_number":4,"created_at":"2026-07-14T02:00:00Z",' +
          '"acting_username":"member","action_excerpt":"<p>我的回复摘要</p>"}]}'
        ));
        client.results.push(HttpTextResult.success(200,
          '{"user_bookmark_list":{"bookmarks":[{"id":701,"title":"收藏主题",' +
          '"excerpt":"收藏摘要","topic_id":303,"linked_post_number":6,"category_id":111,' +
          '"highest_post_number":8,"bumped_at":"2026-07-14T03:00:00Z",' +
          '"user":{"username":"author"}}]}}'
        ));
        client.results.push(HttpTextResult.success(200,
          '{"drafts":[{"draft_key":"new_topic","sequence":3,' +
          '"data":"{\\"title\\":\\"待发布主题\\",\\"reply\\":\\"草稿正文\\"}"},' +
          '{"draft_key":"topic_302","sequence":4,"topic_id":302,' +
          '"data":"{\\"reply\\":\\"回复草稿\\",\\"reply_to_post_number\\":3}"}]}'
        ));
        const repository: DiscourseProfileRepository = new DiscourseProfileRepository(client);

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
        expect(replies.data?.[0].excerpt).assertEqual('我的回复摘要');
        expect(bookmarks.data?.[0].bookmarkId).assertEqual(701);
        expect(bookmarks.data?.[0].postNumber).assertEqual(6);
        expect(drafts.data?.[0].title).assertEqual('待发布主题');
        expect(drafts.data?.[1].topicId).assertEqual(302);
        done();
      });
  });
}
