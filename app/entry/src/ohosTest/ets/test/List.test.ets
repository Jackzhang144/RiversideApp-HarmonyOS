import appShellModelTest from './AppShellModel.test';
import discourseForumRepositoryTest from './DiscourseForumRepository.test';
import jsonBoundaryTest from './JsonBoundary.test';
import topicReadingTest from './TopicReading.test';

export default function tests(): void {
  appShellModelTest();
  discourseForumRepositoryTest();
  jsonBoundaryTest();
  topicReadingTest();
}
