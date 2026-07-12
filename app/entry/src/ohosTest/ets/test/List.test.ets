import appShellModelTest from './AppShellModel.test';
import accountPresentationTest from './AccountPresentation.test';
import authBoundaryTest from './AuthBoundary.test';
import authRepositoryTest from './AuthRepository.test';
import discourseForumRepositoryTest from './DiscourseForumRepository.test';
import discourseHttpHeadersTest from './DiscourseHttpHeaders.test';
import forumCardPresentationTest from './ForumCardPresentation.test';
import forumComposerPresentationTest from './ForumComposerPresentation.test';
import homePresentationTest from './HomePresentation.test';
import jsonBoundaryTest from './JsonBoundary.test';
import replyBoundaryTest from './ReplyBoundary.test';
import replyTransportTest from './ReplyTransport.test';
import sessionStoreTest from './SessionStore.test';
import topicReadingTest from './TopicReading.test';

export default function tests(): void {
  accountPresentationTest();
  appShellModelTest();
  authBoundaryTest();
  authRepositoryTest();
  discourseForumRepositoryTest();
  discourseHttpHeadersTest();
  forumCardPresentationTest();
  forumComposerPresentationTest();
  homePresentationTest();
  jsonBoundaryTest();
  replyBoundaryTest();
  replyTransportTest();
  sessionStoreTest();
  topicReadingTest();
}
