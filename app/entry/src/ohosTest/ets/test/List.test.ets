import appShellModelTest from './AppShellModel.test';
import authBoundaryTest from './AuthBoundary.test';
import authRepositoryTest from './AuthRepository.test';
import discourseForumRepositoryTest from './DiscourseForumRepository.test';
import discourseHttpHeadersTest from './DiscourseHttpHeaders.test';
import jsonBoundaryTest from './JsonBoundary.test';
import replyBoundaryTest from './ReplyBoundary.test';
import replyTransportTest from './ReplyTransport.test';
import sessionStoreTest from './SessionStore.test';
import topicReadingTest from './TopicReading.test';

export default function tests(): void {
  appShellModelTest();
  authBoundaryTest();
  authRepositoryTest();
  discourseForumRepositoryTest();
  discourseHttpHeadersTest();
  jsonBoundaryTest();
  replyBoundaryTest();
  replyTransportTest();
  sessionStoreTest();
  topicReadingTest();
}
