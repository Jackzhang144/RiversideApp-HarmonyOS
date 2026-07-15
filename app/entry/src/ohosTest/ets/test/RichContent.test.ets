import { describe, expect, it } from '@ohos/hypium';
import {
  RichContentBlock,
  RichContentBlockKind,
  RichContentInlineFragmentKind
} from '../../../main/ets/models/RichContentBlocks';
import { parseRichPostContent } from '../../../main/ets/models/RichContentParser';
import {
  BILIBILI_URL_TRUST_LIST,
  classifyRichNavigation,
  isAllowedEmbedNavigation,
  RichEmbedProvider,
  RichNavigationKind,
  YOUTUBE_URL_TRUST_LIST
} from '../../../main/ets/models/RichNavigationPolicy';

function blocksOfKind(blocks: Array<RichContentBlock>, kind: RichContentBlockKind): Array<RichContentBlock> {
  return blocks.filter((block: RichContentBlock): boolean => block.kind === kind);
}

export default function richContentTest(): void {
  describe('RichContent', () => {
    it('parses supported cooked HTML into native rich-content blocks', 0, () => {
      const blocks: Array<RichContentBlock> = parseRichPostContent(
        '<h2>标题</h2>' +
        '<p>正文 <a href="/t/topic/42/3">站内链接</a></p>' +
        '<aside class="quote" data-username="alice"><blockquote>引用正文</blockquote></aside>' +
        '<pre><code>const value = 1 &lt; 2;</code></pre>' +
        '<div class="math">E=mc^2</div>' +
        '<p>答案 <span class="spoiler">隐藏内容</span></p>' +
        '<ul><li>第一项</li><li>第二项</li></ul>' +
        '<table><tr><th>列</th></tr><tr><td>值</td></tr></table>' +
        '<p><img src="/uploads/default/original/1X/example.png" alt="示例图片"></p>' +
        '<aside class="onebox"><a href="https://river-side.cc/t/topic/9"><h3>Topic 卡片</h3></a></aside>',
        ''
      );

      expect(blocksOfKind(blocks, RichContentBlockKind.HEADING).length).assertEqual(1);
      expect(blocksOfKind(blocks, RichContentBlockKind.TEXT).length).assertEqual(2);
      expect(blocksOfKind(blocks, RichContentBlockKind.TEXT)[0].links[0].url)
        .assertEqual('https://river-side.cc/t/topic/42/3');
      expect(blocksOfKind(blocks, RichContentBlockKind.QUOTE)[0].title).assertEqual('alice');
      expect(blocksOfKind(blocks, RichContentBlockKind.CODE)[0].text).assertEqual('const value = 1 < 2;');
      expect(blocksOfKind(blocks, RichContentBlockKind.FORMULA)[0].text).assertEqual('E=mc^2');
      expect(blocksOfKind(blocks, RichContentBlockKind.SPOILER)[0].text).assertEqual('隐藏内容');
      expect(blocksOfKind(blocks, RichContentBlockKind.LIST)[0].listItems.length).assertEqual(2);
      expect(blocksOfKind(blocks, RichContentBlockKind.TABLE)[0].rows.length).assertEqual(2);
      expect(blocksOfKind(blocks, RichContentBlockKind.IMAGE)[0].url)
        .assertEqual('https://river-side.cc/uploads/default/original/1X/example.png');
      expect(blocksOfKind(blocks, RichContentBlockKind.ONEBOX)[0].title).assertEqual('Topic 卡片');
    });

    it('falls back to safe Markdown blocks when cooked HTML is absent', 0, () => {
      const blocks: Array<RichContentBlock> = parseRichPostContent(
        '',
        '# 标题\n\n> 引用\n\n```arkts\nconst ok = true;\n```\n\n- A\n- B\n\n' +
        '![图](/uploads/example.png)\n\n[Topic](/t/42)'
      );

      expect(blocksOfKind(blocks, RichContentBlockKind.HEADING)[0].text).assertEqual('标题');
      expect(blocksOfKind(blocks, RichContentBlockKind.QUOTE)[0].text).assertEqual('引用');
      expect(blocksOfKind(blocks, RichContentBlockKind.CODE)[0].text).assertEqual('const ok = true;');
      expect(blocksOfKind(blocks, RichContentBlockKind.LIST)[0].listItems.length).assertEqual(2);
      expect(blocksOfKind(blocks, RichContentBlockKind.IMAGE)[0].url)
        .assertEqual('https://river-side.cc/uploads/example.png');
      expect(blocksOfKind(blocks, RichContentBlockKind.TEXT)[0].links[0].url)
        .assertEqual('https://river-side.cc/t/42');
    });

    it('keeps cooked Discourse Emoji images inline with surrounding text', 0, () => {
      const blocks: Array<RichContentBlock> = parseRichPostContent(
        '<p>第一次免费吧，1RSC都没有了' +
        '<img class="emoji" src="/images/emoji/twitter/melting_face.png" alt=":melting_face:" title=":melting_face:">继续努力</p>' +
        '<p><img src="/uploads/default/original/1X/example.png" alt="普通图片"></p>',
        ''
      );
      const text: RichContentBlock = blocksOfKind(blocks, RichContentBlockKind.TEXT)[0];

      expect(text.text).assertEqual('第一次免费吧，1RSC都没有了:melting_face:继续努力');
      expect(text.inlineFragments.length).assertEqual(3);
      expect(text.inlineFragments[1].kind).assertEqual(RichContentInlineFragmentKind.EMOJI);
      expect(text.inlineFragments[1].text).assertEqual(':melting_face:');
      expect(text.inlineFragments[1].imageUrl)
        .assertEqual('https://river-side.cc/images/emoji/twitter/melting_face.png');
      expect(blocksOfKind(blocks, RichContentBlockKind.IMAGE).length).assertEqual(1);
    });

    it('recognizes Bilibili and YouTube links without exposing arbitrary iframes', 0, () => {
      const blocks: Array<RichContentBlock> = parseRichPostContent(
        '<p><iframe src="https://player.bilibili.com/player.html?bvid=BV1MKVF6jEVh"></iframe></p>' +
        '<p>https://youtu.be/UAZAbtTVwZA?t=90</p>' +
        '<iframe src="https://evil.example/embed/1"></iframe>',
        ''
      );
      const videos: Array<RichContentBlock> = blocksOfKind(blocks, RichContentBlockKind.VIDEO);

      expect(videos.length).assertEqual(2);
      expect(videos[0].embedProvider).assertEqual(RichEmbedProvider.BILIBILI);
      expect(videos[0].url.startsWith('https://player.bilibili.com/player.html?')).assertTrue();
      expect(videos[1].embedProvider).assertEqual(RichEmbedProvider.YOUTUBE);
      expect(videos[1].url).assertEqual(
        'https://www.youtube.com/embed/UAZAbtTVwZA?autoplay=0&playsinline=1&rel=0&iv_load_policy=3&origin=https%3A%2F%2Friver-side.cc&start=90'
      );
      expect(blocks.some((block: RichContentBlock): boolean => block.url.includes('evil.example'))).assertFalse();
    });

    it('routes exact RiverSide Topic and Profile links natively', 0, () => {
      const topic = classifyRichNavigation('/t/topic-title/42/3');
      const profile = classifyRichNavigation('https://river-side.cc/u/%E7%94%A8%E6%88%B7');
      const featureSubdomain = classifyRichNavigation('https://map.river-side.cc/u/alice');

      expect(topic.kind).assertEqual(RichNavigationKind.TOPIC);
      expect(topic.topicId).assertEqual(42);
      expect(topic.postNumber).assertEqual(3);
      expect(profile.kind).assertEqual(RichNavigationKind.PROFILE);
      expect(profile.username).assertEqual('用户');
      expect(featureSubdomain.kind).assertEqual(RichNavigationKind.EXTERNAL);
    });

    it('blocks unsafe schemes and does not accept lookalike RiverSide hosts', 0, () => {
      expect(classifyRichNavigation('http://river-side.cc/t/42').kind)
        .assertEqual(RichNavigationKind.BLOCKED);
      expect(classifyRichNavigation('javascript:alert(1)').kind)
        .assertEqual(RichNavigationKind.BLOCKED);
      expect(classifyRichNavigation('https://river-side.cc.evil.example/t/42').kind)
        .assertEqual(RichNavigationKind.EXTERNAL);
      expect(classifyRichNavigation('mailto:test@example.com').kind)
        .assertEqual(RichNavigationKind.EXTERNAL);
    });

    it('keeps ArkWeb navigation on exact provider allowlists', 0, () => {
      expect(isAllowedEmbedNavigation(
        RichEmbedProvider.BILIBILI,
        'https://player.bilibili.com/player.html?bvid=BV1MKVF6jEVh'
      )).assertTrue();
      expect(isAllowedEmbedNavigation(
        RichEmbedProvider.BILIBILI,
        'https://www.bilibili.com/blackboard/webplayer/mbplayer.html?bvid=BV1MKVF6jEVh'
      )).assertTrue();
      expect(isAllowedEmbedNavigation(
        RichEmbedProvider.BILIBILI,
        'https://www.bilibili.com/blackboard/webplayer.evil/mbplayer.html'
      )).assertFalse();
      expect(isAllowedEmbedNavigation(
        RichEmbedProvider.YOUTUBE,
        'https://www.youtube.com/embed/UAZAbtTVwZA'
      )).assertTrue();
      expect(isAllowedEmbedNavigation(
        RichEmbedProvider.YOUTUBE,
        'https://www.youtube.com/watch?v=UAZAbtTVwZA'
      )).assertFalse();
      expect(isAllowedEmbedNavigation(RichEmbedProvider.YOUTUBE, 'http://www.youtube.com/embed/1'))
        .assertFalse();
      expect(isAllowedEmbedNavigation(
        RichEmbedProvider.WHISPER,
        'https://whisper.river-side.cc/auth/start?mode=interactive'
      )).assertTrue();
      expect(isAllowedEmbedNavigation(
        RichEmbedProvider.WHISPER,
        'https://review.river-side.cc/'
      )).assertFalse();
      expect(BILIBILI_URL_TRUST_LIST.includes('*')).assertFalse();
      expect(YOUTUBE_URL_TRUST_LIST.includes('*')).assertFalse();
    });

    it('preserves clickable links inside list items', 0, () => {
      const blocks: Array<RichContentBlock> = parseRichPostContent(
        '<ul><li><strong>Download</strong>: ' +
        '<a href="https://river-side.cc/mobile-app/android/app.apk">Click APK</a></li></ul>',
        ''
      );
      const list: RichContentBlock = blocksOfKind(blocks, RichContentBlockKind.LIST)[0];

      expect(list.listItems.length).assertEqual(1);
      expect(list.listItems[0].text).assertEqual('Download: Click APK');
      expect(list.listItems[0].links[0].url)
        .assertEqual('https://river-side.cc/mobile-app/android/app.apk');
    });

    it('keeps direct items and nested content in nested lists', 0, () => {
      const blocks: Array<RichContentBlock> = parseRichPostContent(
        '<ol><li><p><strong>Rewards:</strong></p>' +
        '<ul><li>RSC reward is paid after the match.</li></ul></li>' +
        '<li>Next rule</li></ol>',
        ''
      );
      const list: RichContentBlock = blocksOfKind(blocks, RichContentBlockKind.LIST)[0];

      expect(list.listItems.length).assertEqual(2);
      expect(list.listItems[0].text.includes('Rewards:')).assertTrue();
      expect(list.listItems[0].text.includes('RSC reward is paid after the match.')).assertTrue();
      expect(list.listItems[1].text).assertEqual('Next rule');
    });
  });
}
