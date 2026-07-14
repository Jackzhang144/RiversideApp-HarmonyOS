import { describe, expect, it } from '@ohos/hypium';
import {
  ProfileManagementModel,
  ProfileSessionLifecycle,
  ProfileViewStateKind
} from '../../../main/ets/app/ProfileManagementModel';
import { ProfileUpdateRequest } from '../../../main/ets/models/ProfileModels';
import { HttpTextResult } from '../../../main/ets/network/DiscourseHttpClient';
import { DiscourseForumRepository } from '../../../main/ets/repositories/DiscourseForumRepository';
import { StubForumHttpClient } from './DiscourseForumRepository.test';

class StubProfileSessionLifecycle implements ProfileSessionLifecycle {
  public unauthorizedCount: number = 0;

  public async handleUnauthorized(): Promise<void> {
    this.unauthorizedCount += 1;
  }
}

function profileJson(name: string, following: boolean = false): string {
  return '{"user":{"id":24,"username":"member","name":"' + name + '",' +
    '"avatar_template":"/user_avatar/member/{size}/1.png","can_follow":true,' +
    '"is_followed":' + following + ',"can_mute_user":true,"can_ignore_user":true}}';
}

export default function profileManagementModelTest(): void {
  describe('Profile management state', () => {
    it('keeps a valid full Profile visible when low-activity summary data is absent', 0,
      async (done: Function) => {
        const client: StubForumHttpClient = new StubForumHttpClient();
        client.results.push(HttpTextResult.success(200, profileJson('安静成员')));
        client.results.push(HttpTextResult.success(200, '{}'));
        const lifecycle: StubProfileSessionLifecycle = new StubProfileSessionLifecycle();
        const model: ProfileManagementModel = new ProfileManagementModel(
          new DiscourseForumRepository(client),
          lifecycle
        );

        await model.loadProfile('member');

        expect(model.state.kind).assertEqual(ProfileViewStateKind.CONTENT);
        expect(model.state.profile?.displayName).assertEqual('安静成员');
        expect(model.state.summary.available).assertFalse();
        expect(lifecycle.unauthorizedCount).assertEqual(0);
        done();
      });

    it('does not overwrite the current Profile when a profile write fails', 0,
      async (done: Function) => {
        const client: StubForumHttpClient = new StubForumHttpClient();
        client.results.push(HttpTextResult.success(200, profileJson('原名字')));
        client.results.push(HttpTextResult.success(200, '{"user_summary":{"topic_count":1}}'));
        client.formPutResults.push(HttpTextResult.failure(500, '保存失败'));
        const model: ProfileManagementModel = new ProfileManagementModel(
          new DiscourseForumRepository(client),
          new StubProfileSessionLifecycle()
        );
        await model.loadProfile('member');
        const request: ProfileUpdateRequest | null = ProfileUpdateRequest.create(
          'member',
          '新名字',
          null,
          null,
          null,
          null
        );
        if (request === null) {
          expect(false).assertTrue();
          done();
          return;
        }

        const saved: boolean = await model.saveProfile(request);

        expect(saved).assertFalse();
        expect(model.state.profile?.displayName).assertEqual('原名字');
        expect(model.state.message).assertEqual('保存失败');
        done();
      });

    it('refreshes relationship state only after the server accepts the write', 0,
      async (done: Function) => {
        const client: StubForumHttpClient = new StubForumHttpClient();
        client.results.push(HttpTextResult.success(200, profileJson('成员')));
        client.results.push(HttpTextResult.success(200, '{}'));
        client.putResults.push(HttpTextResult.failure(500, '关注失败'));
        client.putResults.push(HttpTextResult.success(200, '{}'));
        client.results.push(HttpTextResult.success(200, profileJson('成员', true)));
        const model: ProfileManagementModel = new ProfileManagementModel(
          new DiscourseForumRepository(client),
          new StubProfileSessionLifecycle()
        );
        await model.loadProfile('member');

        const failed: boolean = await model.setFollowing(true);
        const followingAfterFailure: boolean = model.state.profile?.following ?? true;
        const succeeded: boolean = await model.setFollowing(true);

        expect(failed).assertFalse();
        expect(followingAfterFailure).assertFalse();
        expect(succeeded).assertTrue();
        expect(model.state.profile?.following).assertTrue();
        done();
      });
  });
}
