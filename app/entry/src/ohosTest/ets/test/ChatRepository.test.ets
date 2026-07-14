import { describe, expect, it } from '@ohos/hypium';
import { RepositoryResult, RepositoryResultKind } from '../../../main/ets/core/RepositoryResult';
import {
  ChatChannel,
  ChatEmoji,
  ChatMessage,
  ChatMessagePage,
  ChatMessageQuery,
  ChatReactionAction,
  ChatSearchResult,
  ChatSendRequest
} from '../../../main/ets/models/ChatModels';
import { DiscourseForumRepository } from '../../../main/ets/repositories/DiscourseForumRepository';
import { HttpTextResult } from '../../../main/ets/network/DiscourseHttpClient';
import { StubForumHttpClient } from './DiscourseForumRepository.test';

export default function chatRepositoryTest(): void {
  describe('Discourse ChatRepository contract', () => {
    it('loads channels and a paged message window through server-owned ordering', 0, async (done: Function) => {
      const client: StubForumHttpClient = new StubForumHttpClient();
      client.results.push(
        HttpTextResult.success(200, '{"channels":[{"id":55,"title":"测试频道"}]}'),
        HttpTextResult.success(200,
          '{"messages":[{"id":9,"created_at":"2026-07-12T09:00:00Z",' +
          '"user":{"username":"member"},"message":"你好"}],' +
          '"meta":{"can_load_more_past":true,"can_load_more_future":false}}'
        )
      );
      const repository: DiscourseForumRepository = new DiscourseForumRepository(client);

      const channels: RepositoryResult<Array<ChatChannel>> = await repository.loadChatChannels();
      const query: ChatMessageQuery | null = ChatMessageQuery.around(9, 'past');
      if (query === null) {
        expect(false).assertTrue();
        done();
        return;
      }
      const page: RepositoryResult<ChatMessagePage> = await repository.loadChatMessages(55, query);

      expect(client.paths[0]).assertEqual('/chat/api/me/channels');
      expect(client.paths[1]).assertEqual(
        '/chat/api/channels/55/messages.json?page_size=30&target_message_id=9&direction=past'
      );
      expect(channels.data?.[0].id).assertEqual(55);
      expect(page.data?.messages[0].id).assertEqual(9);
      expect(page.data?.canLoadMorePast).assertTrue();
      done();
    });

    it('opens a direct chat and marks only the server message id as read', 0, async (done: Function) => {
      const client: StubForumHttpClient = new StubForumHttpClient();
      client.jsonPostResults.push(HttpTextResult.success(200,
        '{"channel":{"id":71,"title":"member","chatable_type":"DirectMessage"}}'
      ));
      client.putResults.push(HttpTextResult.success(200, '{}'));
      const repository: DiscourseForumRepository = new DiscourseForumRepository(client);

      const opened: RepositoryResult<ChatChannel> = await repository.openDirectChat(' member ');
      const marked: RepositoryResult<boolean> = await repository.markChatRead(71, 18);

      expect(client.jsonPostRequests[0]).assertEqual(
        '/chat/api/direct-message-channels.json|{"target_usernames":["member"],"name":""}'
      );
      expect(opened.data?.id).assertEqual(71);
      expect(client.putPaths[0]).assertEqual('/chat/api/channels/71/read?message_id=18');
      expect(marked.data).assertTrue();
      done();
    });

    it('returns only the server-confirmed message after a text image reply send', 0, async (done: Function) => {
      const client: StubForumHttpClient = new StubForumHttpClient();
      client.jsonPostResults.push(HttpTextResult.success(200,
        '{"message":{"id":20,"created_at":"2026-07-12T10:00:00Z",' +
        '"user":{"username":"member"},"message":"图片说明",' +
        '"uploads":[{"url":"/uploads/default/original/photo.png"}]}}'
      ));
      const repository: DiscourseForumRepository = new DiscourseForumRepository(client);
      const request: ChatSendRequest | null = ChatSendRequest.create(
        71,
        ' 图片说明 ',
        [801],
        18,
        'hm-stage-1',
        '2026-07-12T10:00:00.000Z'
      );
      if (request === null) {
        expect(false).assertTrue();
        done();
        return;
      }

      const result: RepositoryResult<ChatMessage> = await repository.sendChatMessage(request);

      expect(client.jsonPostRequests[0]).assertEqual(
        '/chat/71.json|{"message":"图片说明","staged_id":"hm-stage-1",' +
        '"client_created_at":"2026-07-12T10:00:00.000Z","in_reply_to_id":18,"upload_ids":[801]}'
      );
      expect(result.kind).assertEqual(RepositoryResultKind.SUCCESS);
      expect(result.data?.id).assertEqual(20);
      expect(result.data?.uploadUrls.length).assertEqual(1);
      done();
    });

    it('rejects a successful response without a server message instead of inventing one', 0,
      async (done: Function) => {
        const client: StubForumHttpClient = new StubForumHttpClient();
        client.jsonPostResults.push(HttpTextResult.success(200, '{}'));
        const repository: DiscourseForumRepository = new DiscourseForumRepository(client);
        const request: ChatSendRequest | null = ChatSendRequest.create(
          71,
          '消息',
          [],
          null,
          'hm-stage-2',
          '2026-07-12T10:01:00.000Z'
        );
        if (request === null) {
          expect(false).assertTrue();
          done();
          return;
        }

        const result: RepositoryResult<ChatMessage> = await repository.sendChatMessage(request);

        expect(result.kind).assertEqual(RepositoryResultKind.FAILURE);
        expect(result.message).assertEqual('服务器未返回已发送消息');
        done();
      });

    it('reacts, deletes and restores only after each server operation succeeds', 0, async (done: Function) => {
      const client: StubForumHttpClient = new StubForumHttpClient();
      client.formPutResults.push(HttpTextResult.success(200, '{}'));
      client.deleteResults.push(HttpTextResult.success(200, '{}'));
      client.putResults.push(HttpTextResult.success(200, '{}'));
      const repository: DiscourseForumRepository = new DiscourseForumRepository(client);

      const reacted: RepositoryResult<boolean> = await repository.reactToChatMessage(
        71,
        20,
        'heart',
        ChatReactionAction.ADD
      );
      const deleted: RepositoryResult<boolean> = await repository.deleteChatMessage(71, 20);
      const restored: RepositoryResult<boolean> = await repository.restoreChatMessage(71, 20);

      expect(client.formPutRequests[0]).assertEqual(
        '/chat/71/react/20|react_action=add&emoji=heart'
      );
      expect(client.deletePaths[0]).assertEqual('/chat/api/channels/71/messages/20');
      expect(client.putPaths[0]).assertEqual('/chat/api/channels/71/messages/20/restore');
      expect(reacted.data).assertTrue();
      expect(deleted.data).assertTrue();
      expect(restored.data).assertTrue();
      done();
    });

    it('loads Emoji and paged Chat search then leaves a Category channel', 0, async (done: Function) => {
      const client: StubForumHttpClient = new StubForumHttpClient();
      client.results.push(
        HttpTextResult.success(200,
          '{"emoji":[{"name":"heart","url":""}],' +
          '"custom":[{"name":"riverside","url":"/uploads/default/original/custom.png"}]}'
        ),
        HttpTextResult.success(200,
          '{"messages":[{"id":30,"created_at":"2026-07-12T11:00:00Z",' +
          '"user":{"username":"member"},"excerpt":"<p>搜索结果</p>",' +
          '"channel":{"id":55,"title":"测试频道"}}]}'
        )
      );
      client.deleteResults.push(HttpTextResult.success(200, '{}'));
      const repository: DiscourseForumRepository = new DiscourseForumRepository(client);

      const emojis: RepositoryResult<Array<ChatEmoji>> = await repository.loadChatEmojis();
      const search: RepositoryResult<Array<ChatSearchResult>> = await repository.searchChat(' 结果 ', 20, 20);
      const left: RepositoryResult<boolean> = await repository.leaveChatChannel(55);

      expect(client.paths[0]).assertEqual('/emojis.json');
      expect(emojis.data?.length).assertEqual(2);
      expect(emojis.data?.[1].imageUrl()).assertEqual(
        'https://river-side.cc/uploads/default/original/custom.png'
      );
      expect(client.paths[1]).assertEqual(
        '/chat/api/search?query=%E7%BB%93%E6%9E%9C&sort=relevance&offset=20&limit=20'
      );
      expect(search.data?.[0].message.id).assertEqual(30);
      expect(search.data?.[0].channel.id).assertEqual(55);
      expect(client.deletePaths[0]).assertEqual('/chat/api/channels/55/memberships/me/follows');
      expect(left.data).assertTrue();
      done();
    });
  });
}
