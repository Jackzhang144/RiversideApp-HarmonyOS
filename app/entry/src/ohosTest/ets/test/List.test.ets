import appShellModelTest from './AppShellModel.test';
import accountPresentationTest from './AccountPresentation.test';
import authBoundaryTest from './AuthBoundary.test';
import authRepositoryTest from './AuthRepository.test';
import discourseForumRepositoryTest from './DiscourseForumRepository.test';
import discourseHttpHeadersTest from './DiscourseHttpHeaders.test';
import forumComposerPresentationTest from './ForumComposerPresentation.test';
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
  forumComposerPresentationTest();
  jsonBoundaryTest();
  replyBoundaryTest();
  replyTransportTest();
  sessionStoreTest();
  topicReadingTest();
}
