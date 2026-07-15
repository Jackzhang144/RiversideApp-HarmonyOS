import { describe, expect, it } from '@ohos/hypium';
import {
  RIVERSIDE_HOST,
  RIVERSIDE_ORIGIN,
  RiversideUrlResolver
} from '../../../main/ets/core/RiversideEnvironment';

export default function riversideEnvironmentTest(): void {
  describe('RiversideEnvironment', () => {
    it('keeps the canonical HTTPS origin in one environment definition', 0, () => {
      expect(RIVERSIDE_HOST).assertEqual('river-side.cc');
      expect(RIVERSIDE_ORIGIN).assertEqual('https://river-side.cc');
    });

    it('resolves forum and chat URL variants without changing external URLs', 0, () => {
      const resolver: RiversideUrlResolver = new RiversideUrlResolver('https://example.test/');

      expect(resolver.absolute('/u/alice')).assertEqual('https://example.test/u/alice');
      expect(resolver.absolute('user_avatar/alice.png')).assertEqual('https://example.test/user_avatar/alice.png');
      expect(resolver.absolute('http://cdn.example.test/a.png')).assertEqual('http://cdn.example.test/a.png');
      expect(resolver.chat('upload:// abc 123.png '))
        .assertEqual('https://example.test/uploads/short-url/abc123.png');
      expect(resolver.chat('//cdn.example.test/a.png')).assertEqual('https://cdn.example.test/a.png');
      expect(resolver.richContent('HTTPS://EXAMPLE.TEST/t/1')).assertEqual('https://EXAMPLE.TEST/t/1');
    });

    it('keeps avatar, topic, chat permalink and emoji rules explicit', 0, () => {
      const resolver: RiversideUrlResolver = new RiversideUrlResolver('https://example.test');

      expect(resolver.avatar('/avatar/{size}.png', 96)).assertEqual('https://example.test/avatar/96.png');
      expect(resolver.avatar('relative.png', 64, false, true)).assertEqual('');
      expect(resolver.avatar('http://cdn.example.test/a.png', 64, false, true)).assertEqual('');
      expect(resolver.topicPost(42, 3)).assertEqual('https://example.test/t/42/3');
      expect(resolver.topicPost(0, 3)).assertEqual('');
      expect(resolver.chatMessage(71, 'alumni-square', 18))
        .assertEqual('https://example.test/chat/c/alumni-square/71/18');
      expect(resolver.chatMessage(71, '', 18)).assertEqual('https://example.test/chat/c/71/71/18');
      expect(resolver.reactionEmoji('wave'))
        .assertEqual('https://example.test/images/emoji/twitter/wave.png?v=15');
    });
  });
}
