import { describe, expect, it } from '@ohos/hypium';
import {
  ProfileManagementModel,
  ProfileSessionLifecycle,
  ProfileViewStateKind
} from '../../../main/ets/app/ProfileManagementModel';
import { ProfileUpdateRequest } from '../../../main/ets/models/ProfileModels';
import { MediaUploadStateKind } from '../../../main/ets/models/MediaModels';
import { HttpTextResult } from '../../../main/ets/network/DiscourseHttpClient';
import { DiscourseProfileRepository } from '../../../main/ets/repositories/DiscourseProfileRepository';
import { DiscourseMediaRepository } from '../../../main/ets/repositories/MediaRepository';
import { StubForumHttpClient } from './DiscourseForumRepository.test';
import { cachedPng, StubMediaTransport } from './MediaRepository.test';

class StubProfileSessionLifecycle implements ProfileSessionLifecycle {
  public unauthorizedCount: number = 0;

  public async handleUnauthorized(): Promise<void> {
    this.unauthorizedCount += 1;
  }
}

function profileJson(name: string, following: boolean = false, hidePresence: boolean = false): string {
  return '{"user":{"id":24,"username":"member","name":"' + name + '",' +
    '"avatar_template":"/user_avatar/member/{size}/1.png","can_follow":true,' +
    '"is_followed":' + following + ',"can_mute_user":true,"can_ignore_user":true,' +
    '"can_upload_profile_header":true,"hide_presence":' + hidePresence + '}}';
}

function profileBackgroundJson(canUpload: boolean, url: string): string {
  return '{"user":{"id":24,"username":"member","name":"成员",' +
    '"can_upload_profile_header":' + canUpload + ',' +
    '"profile_background_upload_url":"' + url + '"}}';
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
          new DiscourseProfileRepository(client),
          lifecycle
        );

        await model.loadProfile('member');

        expect(model.state.kind).assertEqual(ProfileViewStateKind.CONTENT);
        expect(model.state.profile?.displayName).assertEqual('安静成员');
        expect(model.state.summary.available).assertFalse();
        expect(lifecycle.unauthorizedCount).assertEqual(0);
        done();
      });

    it('does not restore Profile or email content after an auxiliary request returns 401', 0,
      async (done: Function) => {
        const client: StubForumHttpClient = new StubForumHttpClient();
        client.results.push(HttpTextResult.success(200, profileJson('成员')));
        client.results.push(HttpTextResult.unauthorized());
        const lifecycle: StubProfileSessionLifecycle = new StubProfileSessionLifecycle();
        const model: ProfileManagementModel = new ProfileManagementModel(
          new DiscourseProfileRepository(client),
          lifecycle
        );

        await model.loadProfile('member', true);

        expect(model.state.kind).assertEqual(ProfileViewStateKind.ERROR);
        expect(model.state.profile === null).assertTrue();
        expect(model.state.emails === null).assertTrue();
        expect(lifecycle.unauthorizedCount).assertEqual(1);
        done();
      });

    it('does not restore an in-flight Profile after external session reset', 0,
      async (done: Function) => {
        const client: StubForumHttpClient = new StubForumHttpClient();
        client.results.push(HttpTextResult.success(200, profileJson('旧会话成员')));
        const model: ProfileManagementModel = new ProfileManagementModel(
          new DiscourseProfileRepository(client),
          new StubProfileSessionLifecycle()
        );

        const loading: Promise<void> = model.loadProfile('member', true);
        model.reset();
        await loading;

        expect(model.state.kind).assertEqual(ProfileViewStateKind.INITIAL);
        expect(model.state.profile === null).assertTrue();
        expect(model.state.emails === null).assertTrue();
        done();
      });

    it('does not overwrite the current Profile when a profile write fails', 0,
      async (done: Function) => {
        const client: StubForumHttpClient = new StubForumHttpClient();
        client.results.push(HttpTextResult.success(200, profileJson('原名字')));
        client.results.push(HttpTextResult.success(200, '{"user_summary":{"topic_count":1}}'));
        client.formPutResults.push(HttpTextResult.failure(500, '保存失败'));
        const model: ProfileManagementModel = new ProfileManagementModel(
          new DiscourseProfileRepository(client),
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
          new DiscourseProfileRepository(client),
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

    it('updates hide presence and reloads the authoritative Profile', 0,
      async (done: Function) => {
        const client: StubForumHttpClient = new StubForumHttpClient();
        client.results.push(HttpTextResult.success(200, profileJson('成员')));
        client.results.push(HttpTextResult.success(200, '{}'));
        client.formPutResults.push(HttpTextResult.success(200, '{}'));
        client.results.push(HttpTextResult.success(200, profileJson('成员', false, true)));
        const model: ProfileManagementModel = new ProfileManagementModel(
          new DiscourseProfileRepository(client),
          new StubProfileSessionLifecycle()
        );
        await model.loadProfile('member');

        const saved: boolean = await model.setHidePresence(true);

        expect(saved).assertTrue();
        expect(client.formPutRequests[0]).assertEqual('/u/member.json|hide_presence=true');
        expect(model.state.profile?.hidePresence).assertTrue();
        done();
      });

    it('keeps the current avatar when upload succeeds but avatar selection fails', 0,
      async (done: Function) => {
        const client: StubForumHttpClient = new StubForumHttpClient();
        client.results.push(HttpTextResult.success(200, profileJson('成员')));
        client.results.push(HttpTextResult.success(200, '{}'));
        client.formPutResults.push(HttpTextResult.failure(500, '头像保存失败'));
        const mediaTransport: StubMediaTransport = new StubMediaTransport();
        mediaTransport.results.push(HttpTextResult.success(200,
          '{"id":813,"url":"/uploads/default/original/avatar.png","original_filename":"avatar.png"}'
        ));
        const model: ProfileManagementModel = new ProfileManagementModel(
          new DiscourseProfileRepository(client),
          new StubProfileSessionLifecycle(),
          new DiscourseMediaRepository(mediaTransport)
        );
        await model.loadProfile('member');
        const originalAvatar: string = model.state.profile?.avatarUrl ?? '';

        const saved: boolean = await model.uploadAvatar(cachedPng());

        expect(saved).assertFalse();
        expect(model.state.profile?.avatarUrl).assertEqual(originalAvatar);
        expect(model.mediaState?.kind).assertEqual(MediaUploadStateKind.FAILED);
        expect(model.state.message).assertEqual('头像保存失败');
        done();
      });

    it('applies a background upload URL only after profile write and authoritative refresh succeed', 0,
      async (done: Function) => {
        const client: StubForumHttpClient = new StubForumHttpClient();
        client.results.push(HttpTextResult.success(200, profileJson('成员')));
        client.results.push(HttpTextResult.success(200, '{}'));
        client.formPutResults.push(HttpTextResult.success(200, '{}'));
        client.results.push(HttpTextResult.success(200,
          '{"user":{"id":24,"username":"member","name":"成员",' +
          '"profile_background_upload_url":"/uploads/default/original/background.png"}}'
        ));
        const mediaTransport: StubMediaTransport = new StubMediaTransport();
        mediaTransport.results.push(HttpTextResult.success(200,
          '{"id":814,"url":"/uploads/default/original/background.png",' +
          '"original_filename":"background.png"}'
        ));
        const model: ProfileManagementModel = new ProfileManagementModel(
          new DiscourseProfileRepository(client),
          new StubProfileSessionLifecycle(),
          new DiscourseMediaRepository(mediaTransport)
        );
        await model.loadProfile('member');

        const saved: boolean = await model.uploadProfileBackground(cachedPng());

        expect(saved).assertTrue();
        expect(client.formPutRequests[0]).assertEqual(
          '/u/member.json|profile_background_upload_url=%2Fuploads%2Fdefault%2Foriginal%2Fbackground.png'
        );
        expect(model.state.profile?.profileBackgroundUrl).assertEqual(
          'https://river-side.cc/uploads/default/original/background.png'
        );
        expect(model.mediaState?.kind).assertEqual(MediaUploadStateKind.SUCCEEDED);
        done();
      });

    it('rejects a background upload without a URL before any profile write', 0,
      async (done: Function) => {
        const client: StubForumHttpClient = new StubForumHttpClient();
        client.results.push(HttpTextResult.success(200, profileJson('成员')));
        client.results.push(HttpTextResult.success(200, '{}'));
        const mediaTransport: StubMediaTransport = new StubMediaTransport();
        mediaTransport.results.push(HttpTextResult.success(200,
          '{"id":815,"markdown":"![background](upload://background)"}'
        ));
        const model: ProfileManagementModel = new ProfileManagementModel(
          new DiscourseProfileRepository(client),
          new StubProfileSessionLifecycle(),
          new DiscourseMediaRepository(mediaTransport)
        );
        await model.loadProfile('member');

        const saved: boolean = await model.uploadProfileBackground(cachedPng());

        expect(saved).assertFalse();
        expect(client.formPutRequests.length).assertEqual(0);
        expect(model.state.message).assertEqual('背景图上传响应缺少地址');
        done();
      });

    it('clears an existing profile background and reloads the authoritative Profile', 0,
      async (done: Function) => {
        const client: StubForumHttpClient = new StubForumHttpClient();
        client.results.push(HttpTextResult.success(200,
          profileBackgroundJson(true, '/uploads/default/original/background.png')));
        client.results.push(HttpTextResult.success(200, '{}'));
        client.formPutResults.push(HttpTextResult.success(200, '{}'));
        client.results.push(HttpTextResult.success(200, profileBackgroundJson(true, '')));
        const model: ProfileManagementModel = new ProfileManagementModel(
          new DiscourseProfileRepository(client),
          new StubProfileSessionLifecycle()
        );
        await model.loadProfile('member');

        const cleared: boolean = await model.clearProfileBackground();

        expect(cleared).assertTrue();
        expect(client.formPutRequests[0]).assertEqual('/u/member.json|profile_background_upload_url=');
        expect(model.state.profile?.profileBackgroundUrl).assertEqual('');
        done();
      });
  });
}
