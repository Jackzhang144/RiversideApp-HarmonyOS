import appShellModelTest from './AppShellModel.test';
import jsonBoundaryTest from './JsonBoundary.test';
import topicReadingTest from './TopicReading.test';

export default function tests(): void {
  appShellModelTest();
  jsonBoundaryTest();
  topicReadingTest();
}
