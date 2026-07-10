import appShellModelTest from './AppShellModel.test';
import authBoundaryTest from './AuthBoundary.test';
import discourseForumRepositoryTest from './DiscourseForumRepository.test';
import jsonBoundaryTest from './JsonBoundary.test';
import sessionStoreTest from './SessionStore.test';
import topicReadingTest from './TopicReading.test';

export default function tests(): void {
  appShellModelTest();
  authBoundaryTest();
  discourseForumRepositoryTest();
  jsonBoundaryTest();
  sessionStoreTest();
  topicReadingTest();
}
