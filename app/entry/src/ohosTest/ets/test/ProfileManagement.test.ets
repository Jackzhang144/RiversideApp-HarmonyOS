import { describe, expect, it } from '@ohos/hypium';
import { RepositoryResult, RepositoryResultKind } from '../../../main/ets/core/RepositoryResult';
import {
  ProfileNotificationLevel,
  ProfileUpdateRequest,
  UserEmailInfo,
  UserProfile,
  UserProfileSummary
} from '../../../main/ets/models/ProfileModels';
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
  });
}
